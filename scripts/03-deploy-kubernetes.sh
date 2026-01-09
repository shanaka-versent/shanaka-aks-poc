#!/bin/bash
# Deploy Kubernetes resources (Gateway, Apps, HTTPRoutes)
# @author Shanaka Jayasundera - shanakaj@gmail.com

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_ROOT/kubernetes"
CERTS_DIR="$PROJECT_ROOT/certs"

# Check if TLS is enabled (certificates exist)
TLS_ENABLED=false
if [ -f "$CERTS_DIR/istio-gw.crt" ] && [ -f "$CERTS_DIR/istio-gw.key" ]; then
    TLS_ENABLED=true
fi

echo "=============================================="
echo "  MTKC POC - Step 3: Deploy K8s Resources  "
echo "=============================================="
echo ""
if [ "$TLS_ENABLED" = true ]; then
    echo "  TLS Mode: End-to-End TLS enabled"
else
    echo "  TLS Mode: HTTP only (run generate-tls-certs.sh for HTTPS)"
fi
echo ""

# Deploy namespaces first
echo "[1/10] Creating namespaces with Ambient mesh labels..."
kubectl apply -f "$K8S_DIR/00-namespaces.yaml"

# Wait for namespaces
sleep 2

# Create TLS secrets if certificates exist
if [ "$TLS_ENABLED" = true ]; then
    echo "[2/10] Creating TLS secrets for End-to-End TLS..."
    # Use pushd/popd to handle paths with spaces
    pushd "$CERTS_DIR" > /dev/null
    kubectl create secret tls istio-gateway-tls \
        --cert=istio-gw.crt \
        --key=istio-gw.key \
        --namespace=istio-ingress \
        --dry-run=client -o yaml | kubectl apply -f -
    popd > /dev/null
    echo "    TLS secret created: istio-gateway-tls"
else
    echo "[2/10] Skipping TLS secrets (no certificates found)..."
fi

# Deploy Gateway
echo "[3/10] Deploying Gateway API Gateway..."
kubectl apply -f "$K8S_DIR/01-gateway.yaml"

# Wait for Gateway to get an IP
echo "[4/10] Waiting for Gateway to get Internal LB IP..."
echo "    This may take 1-2 minutes..."

for i in {1..60}; do
    # Istio creates service as <gateway-name>-istio
    IP=$(kubectl get svc -n istio-ingress mtkc-gateway-istio -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$IP" ]; then
        echo "    Gateway IP: $IP"
        break
    fi
    echo "    Waiting... ($i/60)"
    sleep 5
done

if [ -z "$IP" ]; then
    echo "ERROR: Gateway did not get an IP. Check:"
    echo "  kubectl get svc -n istio-ingress"
    echo "  kubectl describe gateway mtkc-gateway -n istio-ingress"
    exit 1
fi

# Verify it's an INTERNAL Load Balancer (IP should be in AKS subnet range 10.0.1.x)
echo "[5/10] Verifying Load Balancer is INTERNAL..."
if [[ "$IP" == 10.0.1.* ]]; then
    echo "    Confirmed: Internal LB IP ($IP is in AKS subnet 10.0.1.0/24)"
else
    echo "    WARNING: IP $IP may not be internal. Expected 10.0.1.x range."
    echo "    Checking service annotations..."
    kubectl get svc mtkc-gateway-istio -n istio-ingress -o jsonpath='{.metadata.annotations}' | grep -i internal || echo "    No internal annotation found"
fi

# CRITICAL: Set externalTrafficPolicy to Local for Azure ILB to work with App Gateway
echo "[6/10] Configuring externalTrafficPolicy: Local..."
echo "    (Required for Azure ILB with DSR/Floating IP to work with App Gateway)"
kubectl patch svc mtkc-gateway-istio -n istio-ingress -p '{"spec":{"externalTrafficPolicy":"Local"}}'
echo "    Done."

# Deploy health responder
echo "[7/10] Deploying health-responder..."
kubectl apply -f "$K8S_DIR/02-health-responder.yaml"

# Deploy sample apps
echo "[8/10] Deploying sample applications..."
kubectl apply -f "$K8S_DIR/03-sample-app-1.yaml"
kubectl apply -f "$K8S_DIR/04-sample-app-2.yaml"

# Deploy reference grants (for cross-namespace references)
echo "[9/10] Deploying ReferenceGrants..."
kubectl apply -f "$K8S_DIR/06-reference-grants.yaml"

# Deploy HTTPRoutes
echo "[10/10] Deploying HTTPRoutes..."
kubectl apply -f "$K8S_DIR/05-httproutes.yaml"

# Wait for pods to be ready
echo ""
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=health-responder -n gateway-health --timeout=120s
kubectl wait --for=condition=ready pod -l app=sample-app-1 -n sample-apps --timeout=120s
kubectl wait --for=condition=ready pod -l app=sample-app-2 -n sample-apps --timeout=120s

# Verify no sidecars (Ambient mesh check)
echo ""
echo "Verifying Ambient mesh (no sidecars)..."
CONTAINER_COUNT=$(kubectl get pods -n sample-apps -o jsonpath='{range .items[*]}{.metadata.name}: {range .spec.containers[*]}{.name} {end}{"\n"}{end}')
echo "$CONTAINER_COUNT"
echo ""
if echo "$CONTAINER_COUNT" | grep -q "istio-proxy"; then
    echo "WARNING: Found istio-proxy sidecar. Ambient mesh may not be configured correctly."
else
    echo "Confirmed: No sidecars found (Ambient mesh active)"
fi

echo ""
echo "=============================================="
echo "  Kubernetes resources deployed!             "
echo "=============================================="
echo ""
echo "Gateway Internal LB IP: $IP"
echo ""
echo "Architecture:"
echo "  Internet -> App Gateway (Public) -> Internal LB ($IP) -> Gateway API -> Apps"
echo ""
echo "Verify with:"
echo "  kubectl get gateway -A"
echo "  kubectl get httproute -A"
echo "  kubectl get pods -A -l 'app in (health-responder,sample-app-1,sample-app-2)'"
echo ""
echo "Next step: Run 04-update-appgw-backend.sh"
