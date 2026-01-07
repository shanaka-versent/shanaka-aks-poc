#!/bin/bash
# Deploy Azure infrastructure with Terraform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "=============================================="
echo "  KUDOS POC - Step 1: Deploy Infrastructure  "
echo "=============================================="
echo ""

# Check Azure CLI login
echo "[0/4] Checking Azure CLI authentication..."
if ! az account show &> /dev/null; then
    echo "ERROR: Not logged in to Azure CLI."
    echo ""
    echo "Please run: az login"
    echo ""
    echo "If you have multiple subscriptions, also run:"
    echo "  az account set --subscription <SUBSCRIPTION_ID>"
    echo ""
    exit 1
fi

# Show current subscription
CURRENT_SUB=$(az account show --query "{name:name, id:id}" -o tsv)
echo "  Using subscription: $CURRENT_SUB"
echo ""
echo "  To change subscription:"
echo "    az account set --subscription <SUBSCRIPTION_ID>"
echo "  Or set subscription_id in terraform.tfvars"
echo ""

cd "$TERRAFORM_DIR"

# Initialize Terraform
echo "[1/4] Initializing Terraform..."
terraform init

# Validate configuration
echo "[2/4] Validating configuration..."
terraform validate

# Plan
echo "[3/4] Planning deployment..."
terraform plan -out=tfplan

# Apply
echo "[4/4] Applying configuration..."
read -p "Apply this plan? (yes/no): " CONFIRM
if [ "$CONFIRM" == "yes" ]; then
    terraform apply tfplan
    
    echo ""
    echo "=============================================="
    echo "  Infrastructure deployed successfully!      "
    echo "=============================================="
    echo ""
    terraform output
    echo ""
    echo "Next step: Run 02-install-istio-ambient.sh"
else
    echo "Deployment cancelled."
    exit 1
fi
