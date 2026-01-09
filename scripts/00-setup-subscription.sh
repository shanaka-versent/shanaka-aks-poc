#!/bin/bash
# Setup script for deploying to a new Azure subscription
# This script helps manage Terraform state across multiple subscriptions
# @author Shanaka Jayasundera - shanakaj@gmail.com

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "=============================================="
echo "  MTKC POC - Subscription Setup             "
echo "=============================================="
echo ""

# Check if already logged in
echo "[1/4] Checking Azure CLI authentication..."
if az account show &> /dev/null; then
    CURRENT_SUB=$(az account show --query "{name:name, id:id}" -o tsv)
    echo "  Currently logged in to: $CURRENT_SUB"
    echo ""
    read -p "Do you want to use a different subscription? (yes/no): " CHANGE_SUB
    if [ "$CHANGE_SUB" == "yes" ]; then
        echo ""
        echo "Available subscriptions:"
        az account list --query "[].{Name:name, ID:id, IsDefault:isDefault}" -o table
        echo ""
        read -p "Enter Subscription ID to use: " NEW_SUB_ID
        az account set --subscription "$NEW_SUB_ID"
        echo "  Switched to: $(az account show --query name -o tsv)"
    fi
else
    echo "  Not logged in. Running az login..."
    az login
    echo ""
    echo "Available subscriptions:"
    az account list --query "[].{Name:name, ID:id, IsDefault:isDefault}" -o table
    echo ""
    read -p "Enter Subscription ID to use (or press Enter for default): " NEW_SUB_ID
    if [ -n "$NEW_SUB_ID" ]; then
        az account set --subscription "$NEW_SUB_ID"
    fi
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo ""
echo "  Using subscription: $SUBSCRIPTION_NAME"
echo "  Subscription ID:    $SUBSCRIPTION_ID"

# Check for existing Terraform state
echo ""
echo "[2/4] Checking Terraform state..."
cd "$TERRAFORM_DIR"

if [ -f "terraform.tfstate" ]; then
    # Check if state has resources
    RESOURCE_COUNT=$(cat terraform.tfstate | grep -c '"type":' 2>/dev/null || echo "0")
    if [ "$RESOURCE_COUNT" -gt 0 ]; then
        # Get subscription from state
        STATE_SUB=$(cat terraform.tfstate | grep -o '"subscription_id":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || echo "unknown")
        echo "  Found existing state with $RESOURCE_COUNT resources"
        echo "  State subscription: $STATE_SUB"
        echo ""

        if [ "$STATE_SUB" != "$SUBSCRIPTION_ID" ] && [ "$STATE_SUB" != "unknown" ]; then
            echo "  WARNING: State file is for a DIFFERENT subscription!"
            echo ""
            echo "  Options:"
            echo "    1) Use Terraform workspace (keeps both states)"
            echo "    2) Backup state and start fresh"
            echo "    3) Cancel"
            echo ""
            read -p "  Choose option (1/2/3): " OPTION

            case $OPTION in
                1)
                    WORKSPACE_NAME="sub-${SUBSCRIPTION_ID:0:8}"
                    echo "  Creating workspace: $WORKSPACE_NAME"
                    terraform workspace new "$WORKSPACE_NAME" 2>/dev/null || terraform workspace select "$WORKSPACE_NAME"
                    echo "  Now using workspace: $(terraform workspace show)"
                    ;;
                2)
                    BACKUP_DIR="$TERRAFORM_DIR/state-backups"
                    mkdir -p "$BACKUP_DIR"
                    BACKUP_NAME="terraform.tfstate.${STATE_SUB:0:8}.$(date +%Y%m%d%H%M%S)"
                    echo "  Backing up state to: $BACKUP_DIR/$BACKUP_NAME"
                    mv terraform.tfstate "$BACKUP_DIR/$BACKUP_NAME"
                    rm -f terraform.tfstate.backup
                    echo "  State backed up. Ready for fresh deployment."
                    ;;
                3)
                    echo "  Cancelled."
                    exit 0
                    ;;
                *)
                    echo "  Invalid option. Exiting."
                    exit 1
                    ;;
            esac
        else
            echo "  State matches current subscription. Ready to continue."
        fi
    else
        echo "  State file exists but is empty. Ready for deployment."
    fi
else
    echo "  No existing state. Ready for fresh deployment."
fi

# Verify required permissions
echo ""
echo "[3/4] Verifying Azure permissions..."
echo "  Checking if you can create resource groups..."
# Just check if we can list resource groups as a basic permission check
if az group list --query "[0].name" -o tsv &>/dev/null; then
    echo "  Basic permissions verified."
else
    echo "  WARNING: May not have sufficient permissions in this subscription."
fi

# Summary
echo ""
echo "[4/4] Setup Summary"
echo "=============================================="
echo "  Subscription:     $SUBSCRIPTION_NAME"
echo "  Subscription ID:  $SUBSCRIPTION_ID"
echo "  Terraform State:  $(terraform workspace show)"
echo "  Working Dir:      $TERRAFORM_DIR"
echo "=============================================="
echo ""
echo "Ready to deploy! Run the following scripts in order:"
echo ""
echo "  1. ./scripts/01-deploy-terraform.sh"
echo "  2. ./scripts/02-install-istio-ambient.sh"
echo "  3. ./scripts/03-deploy-kubernetes.sh"
echo "  4. ./scripts/04-update-appgw-backend.sh"
echo "  5. ./tests/validate-poc.sh"
echo ""
