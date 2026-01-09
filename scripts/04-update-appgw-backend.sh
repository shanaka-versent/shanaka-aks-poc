#!/bin/bash
# Update Application Gateway backend pool with Gateway Internal LB IP
# @author Shanaka Jayasundera - shanakaj@gmail.com

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "=============================================="
echo "  MTKC POC - Step 4: Update App Gateway     "
echo "=============================================="
echo ""

# Get Terraform outputs
cd "$TERRAFORM_DIR"
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
APPGW_NAME=$(terraform output -raw appgw_name)
APPGW_PUBLIC_IP=$(terraform output -raw appgw_public_ip)
HTTPS_ENABLED=$(terraform output -raw https_enabled 2>/dev/null || echo "false")

if [ "$HTTPS_ENABLED" == "true" ]; then
    echo "  TLS Mode: End-to-End TLS"
else
    echo "  TLS Mode: HTTP only"
fi
echo ""

# Get Gateway Internal LB IP (Istio creates service as <gateway-name>-istio)
echo "[1/4] Getting Gateway Internal LB IP..."
INTERNAL_LB_IP=$(kubectl get svc -n istio-ingress mtkc-gateway-istio -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INTERNAL_LB_IP" ]; then
    echo "ERROR: Could not get Gateway Internal LB IP"
    echo "Check: kubectl get svc -n istio-ingress"
    exit 1
fi

echo "    Internal LB IP: $INTERNAL_LB_IP"

# Verify externalTrafficPolicy is Local (required for Azure ILB with App Gateway)
echo "[2/4] Verifying externalTrafficPolicy..."
TRAFFIC_POLICY=$(kubectl get svc mtkc-gateway-istio -n istio-ingress -o jsonpath='{.spec.externalTrafficPolicy}')
if [ "$TRAFFIC_POLICY" != "Local" ]; then
    echo "    Current: '$TRAFFIC_POLICY', required: 'Local'"
    echo "    Patching service..."
    kubectl patch svc mtkc-gateway-istio -n istio-ingress -p '{"spec":{"externalTrafficPolicy":"Local"}}'
    echo "    Done."
else
    echo "    Already set to 'Local' (correct)"
fi

# Update App Gateway backend pool
echo "[3/4] Updating App Gateway backend pool..."
az network application-gateway address-pool update \
    --resource-group "$RESOURCE_GROUP" \
    --gateway-name "$APPGW_NAME" \
    --name "aks-gateway-pool" \
    --servers "$INTERNAL_LB_IP" \
    --output none

echo "    Backend pool updated with IP: $INTERNAL_LB_IP"

# Wait for health probes
echo "[4/4] Waiting for backend health probes (60 seconds)..."
sleep 60

# Check backend health
echo ""
echo "Checking backend health..."
if [ "$HTTPS_ENABLED" == "true" ]; then
    HEALTH=$(az network application-gateway show-backend-health \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APPGW_NAME" \
        --query 'backendAddressPools[0].backendHttpSettingsCollection[?contains(backendHttpSettings.id, `https-settings`)].servers[0].health' \
        -o tsv 2>/dev/null || echo "Unknown")
else
    HEALTH=$(az network application-gateway show-backend-health \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APPGW_NAME" \
        --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[0].health' \
        -o tsv 2>/dev/null || echo "Unknown")
fi

echo ""
echo "=============================================="
echo "  App Gateway backend updated!               "
echo "=============================================="
echo ""
echo "Configuration:"
echo "  App Gateway Public IP: $APPGW_PUBLIC_IP"
echo "  Backend Pool IP:       $INTERNAL_LB_IP (Internal LB)"
echo "  Backend Health:        $HEALTH"
echo ""

if [ "$HEALTH" == "Healthy" ]; then
    echo "Access URLs:"
    if [ "$HTTPS_ENABLED" == "true" ]; then
        echo "  https://$APPGW_PUBLIC_IP/healthz/ready"
        echo "  https://$APPGW_PUBLIC_IP/app1"
        echo "  https://$APPGW_PUBLIC_IP/app2"
        echo ""
        echo "Note: Using self-signed certs. Use 'curl -k' or add browser exception."
    else
        echo "  http://$APPGW_PUBLIC_IP/healthz/ready"
        echo "  http://$APPGW_PUBLIC_IP/app1"
        echo "  http://$APPGW_PUBLIC_IP/app2"
    fi
    echo ""
    echo "Next step: Run tests/validate-poc.sh"
else
    echo "WARNING: Backend health is '$HEALTH'"
    echo ""
    echo "Troubleshooting:"
    echo "  az network application-gateway show-backend-health \\"
    echo "    --resource-group $RESOURCE_GROUP \\"
    echo "    --name $APPGW_NAME"
    echo ""
    echo "Common issues:"
    echo "  - Certificate hostname mismatch (for HTTPS)"
    echo "  - NSG rules blocking traffic"
    echo "  - Gateway not listening on expected port"
fi
echo ""
