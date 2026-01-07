# KUDOS POC - Terraform Providers
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
