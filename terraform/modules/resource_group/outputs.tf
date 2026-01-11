# Resource Group Module - Outputs
# @author Shanaka Jayasundera - shanakaj@gmail.com

output "name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Resource Group location"
  value       = azurerm_resource_group.main.location
}

output "id" {
  description = "Resource Group ID"
  value       = azurerm_resource_group.main.id
}
