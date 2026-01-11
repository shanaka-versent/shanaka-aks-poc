# Network Module - Outputs
# @author Shanaka Jayasundera - shanakaj@gmail.com

output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = azurerm_virtual_network.main.name
}

output "aks_subnet_id" {
  description = "AKS Subnet ID"
  value       = azurerm_subnet.aks.id
}

output "appgw_subnet_id" {
  description = "App Gateway Subnet ID"
  value       = azurerm_subnet.appgw.id
}

output "aks_nsg_id" {
  description = "AKS NSG ID"
  value       = azurerm_network_security_group.aks.id
}

output "appgw_nsg_id" {
  description = "App Gateway NSG ID"
  value       = azurerm_network_security_group.appgw.id
}
