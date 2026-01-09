#!/bin/bash
# Install Istio with Ambient Mesh profile (NO SIDECARS)
# @author Shanaka Jayasundera - shanakaj@gmail.com

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "=============================================="
echo "  MTKC POC - Step 2: Install Istio Ambient  "
echo "=============================================="
echo ""

# Get AKS credentials
echo "[1/7] Getting AKS credentials..."
cd "$TERRAFORM_DIR"
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
AKS_NAME=$(terraform output -raw aks_cluster_name)

az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --overwrite-existing

# Verify cluster access
echo "[2/7] Verifying cluster access..."
kubectl cluster-info

# Install Gateway API CRDs (required before Istio)
echo "[3/7] Installing Kubernetes Gateway API CRDs..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

# Verify Gateway API CRDs are installed
echo "    Verifying Gateway API CRDs..."
kubectl wait --for=condition=Established crd/gateways.gateway.networking.k8s.io --timeout=60s
kubectl wait --for=condition=Established crd/httproutes.gateway.networking.k8s.io --timeout=60s

# Check if istioctl is installed
echo "[4/7] Checking istioctl..."
if ! command -v istioctl &> /dev/null; then
    echo "Installing istioctl..."
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.24.0 sh -
    export PATH=$PWD/istio-1.24.0/bin:$PATH
    echo "Add to your PATH: export PATH=\$PWD/istio-1.24.0/bin:\$PATH"
fi

istioctl version --remote=false

# Install Istio with Ambient profile
echo "[5/7] Installing Istio with Ambient profile..."
istioctl install --set profile=ambient -y

# Wait for Istio to be ready
echo "[6/7] Waiting for Istio components..."
kubectl wait --for=condition=available deployment/istiod -n istio-system --timeout=300s

# Verify ztunnel is running (Ambient mesh component)
echo "[7/7] Verifying Ambient mesh (ztunnel)..."
kubectl get pods -n istio-system -l app=ztunnel

echo ""
echo "=============================================="
echo "  Istio Ambient Mesh installed successfully! "
echo "=============================================="
echo ""
echo "Installed components:"
echo "  - Kubernetes Gateway API CRDs (v1.2.0)"
echo "  - Istio Ambient Mesh (ztunnel running)"
echo "  - NO istio-proxy sidecars will be injected"
echo ""
echo "Next step: Run 03-deploy-kubernetes.sh"
