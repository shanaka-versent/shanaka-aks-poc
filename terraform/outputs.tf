output "resource_group_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "AKS Cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_get_credentials_command" {
  description = "Command to get AKS credentials"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "appgw_name" {
  description = "Application Gateway name"
  value       = azurerm_application_gateway.main.name
}

output "appgw_public_ip" {
  description = "Application Gateway Public IP"
  value       = azurerm_public_ip.appgw.ip_address
}

output "appgw_backend_pool_name" {
  description = "Backend pool name to update with Internal LB IP"
  value       = "aks-gateway-pool"
}

output "update_backend_pool_command" {
  description = "Command to update backend pool (replace <INTERNAL_LB_IP>)"
  value       = "az network application-gateway address-pool update --resource-group ${azurerm_resource_group.main.name} --gateway-name ${azurerm_application_gateway.main.name} --name aks-gateway-pool --servers <INTERNAL_LB_IP>"
}
