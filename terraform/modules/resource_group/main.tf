# Resource Group Module
# @author Shanaka Jayasundera - shanakaj@gmail.com

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = var.tags
}
