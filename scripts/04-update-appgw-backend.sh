#!/bin/bash
# Update Application Gateway backend pool with Gateway Internal LB IP

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "=============================================="
echo "  KUDOS POC - Step 4: Update App Gateway     "
echo "=============================================="
echo ""

# Get Terraform outputs
cd "$TERRAFORM_DIR"
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
APPGW_NAME=$(terraform output -raw appgw_name)
APPGW_PUBLIC_IP=$(terraform output -raw appgw_public_ip)

# Get Gateway Internal LB IP
echo "[1/3] Getting Gateway Internal LB IP..."
INTERNAL_LB_IP=$(kubectl get svc -n istio-ingress kudos-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$INTERNAL_LB_IP" ]; then
    echo "ERROR: Could not get Gateway Internal LB IP"
    echo "Check: kubectl get svc -n istio-ingress"
    exit 1
fi

echo "    Internal LB IP: $INTERNAL_LB_IP"

# Update App Gateway backend pool
echo "[2/3] Updating App Gateway backend pool..."
az network application-gateway address-pool update \
    --resource-group "$RESOURCE_GROUP" \
    --gateway-name "$APPGW_NAME" \
    --name "aks-gateway-pool" \
    --servers "$INTERNAL_LB_IP"

echo "[3/3] Verifying backend pool..."
az network application-gateway address-pool show \
    --resource-group "$RESOURCE_GROUP" \
    --gateway-name "$APPGW_NAME" \
    --name "aks-gateway-pool" \
    --query "backendAddresses"

echo ""
echo "=============================================="
echo "  App Gateway backend updated!               "
echo "=============================================="
echo ""
echo "Configuration:"
echo "  App Gateway Public IP: $APPGW_PUBLIC_IP"
echo "  Backend Pool IP:       $INTERNAL_LB_IP"
echo ""
echo "Wait 30-60 seconds for health probes to succeed."
echo ""
echo "Check backend health:"
echo "  az network application-gateway show-backend-health \\"
echo "    --resource-group $RESOURCE_GROUP \\"
echo "    --name $APPGW_NAME"
echo ""
echo "Next step: Run 05-run-tests.sh"
