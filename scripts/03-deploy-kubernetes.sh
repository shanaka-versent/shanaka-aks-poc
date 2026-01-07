#!/bin/bash
# Deploy Kubernetes resources (Gateway, Apps, HTTPRoutes)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_ROOT/kubernetes"

echo "=============================================="
echo "  KUDOS POC - Step 3: Deploy K8s Resources  "
echo "=============================================="
echo ""

# Deploy namespaces first
echo "[1/8] Creating namespaces with Ambient mesh labels..."
kubectl apply -f "$K8S_DIR/00-namespaces.yaml"

# Wait for namespaces
sleep 2

# Deploy Gateway
echo "[2/8] Deploying Gateway API Gateway..."
kubectl apply -f "$K8S_DIR/01-gateway.yaml"

# Wait for Gateway to get an IP
echo "[3/8] Waiting for Gateway to get Internal LB IP..."
echo "    This may take 1-2 minutes..."

for i in {1..60}; do
    IP=$(kubectl get svc -n istio-ingress kudos-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
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
    echo "  kubectl describe gateway kudos-gateway -n istio-ingress"
    exit 1
fi

# Verify it's an INTERNAL Load Balancer (IP should be in AKS subnet range 10.0.1.x)
echo "[4/8] Verifying Load Balancer is INTERNAL..."
if [[ "$IP" == 10.0.1.* ]]; then
    echo "    Confirmed: Internal LB IP ($IP is in AKS subnet 10.0.1.0/24)"
else
    echo "    WARNING: IP $IP may not be internal. Expected 10.0.1.x range."
    echo "    Checking service annotations..."
    kubectl get svc kudos-gateway -n istio-ingress -o jsonpath='{.metadata.annotations}' | grep -i internal || echo "    No internal annotation found"
fi

# Deploy health responder
echo "[5/8] Deploying health-responder..."
kubectl apply -f "$K8S_DIR/02-health-responder.yaml"

# Deploy sample apps
echo "[6/8] Deploying sample applications..."
kubectl apply -f "$K8S_DIR/03-sample-app-1.yaml"
kubectl apply -f "$K8S_DIR/04-sample-app-2.yaml"

# Deploy reference grants (for cross-namespace references)
echo "[7/8] Deploying ReferenceGrants..."
kubectl apply -f "$K8S_DIR/06-reference-grants.yaml"

# Deploy HTTPRoutes
echo "[8/8] Deploying HTTPRoutes..."
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
