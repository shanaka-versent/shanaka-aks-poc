#!/bin/bash
# Clean up all POC resources

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
K8S_DIR="$PROJECT_ROOT/kubernetes"

echo "=============================================="
echo "  KUDOS POC - Cleanup                        "
echo "=============================================="
echo ""
echo "This will destroy ALL resources created by this POC."
echo ""
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Delete Kubernetes resources
echo "[1/3] Deleting Kubernetes resources..."
kubectl delete -f "$K8S_DIR/" --ignore-not-found=true 2>/dev/null || true

# Uninstall Istio
echo "[2/3] Uninstalling Istio..."
istioctl uninstall --purge -y 2>/dev/null || true
kubectl delete namespace istio-system --ignore-not-found=true 2>/dev/null || true

# Destroy Terraform resources
echo "[3/3] Destroying Azure infrastructure..."
cd "$TERRAFORM_DIR"
terraform destroy -auto-approve

echo ""
echo "=============================================="
echo "  Cleanup complete!                          "
echo "=============================================="
