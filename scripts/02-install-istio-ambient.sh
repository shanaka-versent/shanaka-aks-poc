#!/bin/bash
# Install Istio with Ambient Mesh profile (NO SIDECARS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "=============================================="
echo "  KUDOS POC - Step 2: Install Istio Ambient  "
echo "=============================================="
echo ""

# Get AKS credentials
echo "[1/6] Getting AKS credentials..."
cd "$TERRAFORM_DIR"
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
AKS_NAME=$(terraform output -raw aks_cluster_name)

az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --overwrite-existing

# Verify cluster access
echo "[2/6] Verifying cluster access..."
kubectl cluster-info

# Check if istioctl is installed
echo "[3/6] Checking istioctl..."
if ! command -v istioctl &> /dev/null; then
    echo "Installing istioctl..."
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.23.0 sh -
    export PATH=$PWD/istio-1.23.0/bin:$PATH
    echo "Add to your PATH: export PATH=\$PWD/istio-1.23.0/bin:\$PATH"
fi

istioctl version --remote=false

# Install Istio with Ambient profile
echo "[4/6] Installing Istio with Ambient profile..."
istioctl install --set profile=ambient -y

# Wait for Istio to be ready
echo "[5/6] Waiting for Istio components..."
kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout=300s

# Verify ztunnel is running (Ambient mesh component)
echo "[6/6] Verifying Ambient mesh (ztunnel)..."
kubectl get pods -n istio-system -l app=ztunnel

echo ""
echo "=============================================="
echo "  Istio Ambient Mesh installed successfully! "
echo "=============================================="
echo ""
echo "Verification:"
echo "  - ztunnel pods should be running (DaemonSet)"
echo "  - NO istio-proxy sidecars will be injected"
echo ""
echo "Next step: Run 03-deploy-kubernetes.sh"
