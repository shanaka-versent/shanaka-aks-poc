locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = var.tags
}
