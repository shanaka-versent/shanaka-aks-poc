# Application Gateway Module - Outputs
# @author Shanaka Jayasundera - shanakaj@gmail.com

output "id" {
  description = "Application Gateway ID"
  value       = azurerm_application_gateway.main.id
}

output "name" {
  description = "Application Gateway name"
  value       = azurerm_application_gateway.main.name
}

output "public_ip_id" {
  description = "Public IP ID"
  value       = azurerm_public_ip.main.id
}

output "public_ip_address" {
  description = "Public IP address"
  value       = azurerm_public_ip.main.ip_address
}

output "backend_pool_name" {
  description = "Backend pool name"
  value       = var.backend_pool_name
}
