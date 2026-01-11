# MTKC POC - Terraform Providers
# @author Shanaka Jayasundera - shanakaj@gmail.com

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  # Uses az CLI authentication by default
  # Optionally specify subscription_id in terraform.tfvars
  subscription_id = var.subscription_id
}

# Kubernetes provider - uses kubeconfig file for Azure AD authentication
# Prerequisites before using (required for ArgoCD deployment):
#   1. Install kubelogin: brew install azure/kubelogin/kubelogin
#   2. Get AKS credentials: az aks get-credentials --resource-group rg-mtkc-poc --name aks-mtkc-poc
#   3. Convert kubeconfig: kubelogin convert-kubeconfig -l azurecli
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Helm provider - uses same kubeconfig file
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
