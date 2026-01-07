#!/bin/bash
# Deploy Azure infrastructure with Terraform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
CERTS_DIR="$PROJECT_ROOT/certs"

echo "=============================================="
echo "  KUDOS POC - Step 1: Deploy Infrastructure  "
echo "=============================================="
echo ""

# Check for HTTPS configuration
if [ -f "$CERTS_DIR/appgw.pfx" ]; then
    echo "  TLS Mode: End-to-End TLS (certificates found)"
    TLS_ENABLED=true
else
    echo "  TLS Mode: HTTP only"
    echo ""
    read -p "Enable HTTPS? (yes/no): " ENABLE_HTTPS
    if [ "$ENABLE_HTTPS" == "yes" ]; then
        echo ""
        echo "Generating TLS certificates..."
        chmod +x "$SCRIPT_DIR/generate-tls-certs.sh"
        "$SCRIPT_DIR/generate-tls-certs.sh"
        TLS_ENABLED=true
    else
        TLS_ENABLED=false
        # Create tfvars to disable HTTPS
        echo 'enable_https = false' > "$TERRAFORM_DIR/tls.auto.tfvars"
        echo 'backend_https_enabled = false' >> "$TERRAFORM_DIR/tls.auto.tfvars"
    fi
fi
echo ""

# Check Azure CLI login
echo "[0/5] Checking Azure CLI authentication..."
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
echo "[1/5] Initializing Terraform..."
terraform init

# Validate configuration
echo "[2/5] Validating configuration..."
terraform validate

# Plan
echo "[3/5] Planning deployment..."
terraform plan -out=tfplan

# Apply
echo "[4/5] Applying configuration..."
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
