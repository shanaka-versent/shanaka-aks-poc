#!/bin/bash
# Create Kubernetes TLS secrets for End-to-End TLS
# This script creates the TLS secret for the Istio Gateway

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="$PROJECT_ROOT/certs"

echo "=============================================="
echo "  KUDOS POC - Create TLS Secrets             "
echo "=============================================="
echo ""

# Check if certificates exist
if [ ! -f "$CERTS_DIR/istio-gw.crt" ] || [ ! -f "$CERTS_DIR/istio-gw.key" ]; then
    echo "ERROR: TLS certificates not found!"
    echo "Please run ./scripts/generate-tls-certs.sh first"
    exit 1
fi

# Ensure istio-ingress namespace exists
echo "[1/2] Ensuring istio-ingress namespace exists..."
kubectl get namespace istio-ingress &>/dev/null || kubectl create namespace istio-ingress

# Create TLS secret for Istio Gateway
echo "[2/2] Creating TLS secret for Istio Gateway..."
kubectl create secret tls istio-gateway-tls \
    --cert="$CERTS_DIR/istio-gw.crt" \
    --key="$CERTS_DIR/istio-gw.key" \
    --namespace=istio-ingress \
    --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "=============================================="
echo "  TLS Secrets Created Successfully           "
echo "=============================================="
echo ""
echo "Secrets created:"
echo "  - istio-gateway-tls (in istio-ingress namespace)"
echo ""
echo "Verify with:"
echo "  kubectl get secrets -n istio-ingress"
echo ""
