# MTKC POC - Terraform Outputs
# @author Shanaka Jayasundera - shanakaj@gmail.com

output "resource_group_name" {
  description = "Resource Group name"
  value       = module.resource_group.name
}

output "aks_cluster_name" {
  description = "AKS Cluster name"
  value       = module.aks.cluster_name
}

output "aks_get_credentials_command" {
  description = "Command to get AKS credentials"
  value       = "az aks get-credentials --resource-group ${module.resource_group.name} --name ${module.aks.cluster_name}"
}

output "appgw_name" {
  description = "Application Gateway name"
  value       = module.app_gateway.name
}

output "appgw_public_ip" {
  description = "Application Gateway Public IP"
  value       = module.app_gateway.public_ip_address
}

output "app_urls_https" {
  description = "HTTPS URLs for applications"
  value = var.enable_https ? {
    health = "https://${module.app_gateway.public_ip_address}/healthz/ready"
    app1   = "https://${module.app_gateway.public_ip_address}/app1"
    app2   = "https://${module.app_gateway.public_ip_address}/app2"
  } : null
}

output "app_urls_http" {
  description = "HTTP URLs for applications (redirects to HTTPS when enabled)"
  value = {
    health = "http://${module.app_gateway.public_ip_address}/healthz/ready"
    app1   = "http://${module.app_gateway.public_ip_address}/app1"
    app2   = "http://${module.app_gateway.public_ip_address}/app2"
  }
}

output "https_enabled" {
  description = "Whether HTTPS is enabled"
  value       = var.enable_https
}

output "appgw_backend_pool_name" {
  description = "Backend pool name to update with Internal LB IP"
  value       = module.app_gateway.backend_pool_name
}

output "update_backend_pool_command" {
  description = "Command to update backend pool (replace <INTERNAL_LB_IP>)"
  value       = "az network application-gateway address-pool update --resource-group ${module.resource_group.name} --gateway-name ${module.app_gateway.name} --name ${module.app_gateway.backend_pool_name} --servers <INTERNAL_LB_IP>"
}

# Module-specific outputs
output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.network.vnet_id
}

output "aks_subnet_id" {
  description = "AKS Subnet ID"
  value       = module.network.aks_subnet_id
}

output "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL for workload identity"
  value       = module.aks.oidc_issuer_url
}

# ArgoCD Outputs
output "argocd_enabled" {
  description = "Whether ArgoCD is enabled"
  value       = var.enable_argocd
}

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = var.enable_argocd ? module.argocd[0].namespace : null
}

output "argocd_admin_password" {
  description = "ArgoCD admin password"
  value       = var.enable_argocd ? module.argocd[0].admin_password : null
  sensitive   = true
}

output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = var.enable_argocd ? module.argocd[0].server_url : null
}

output "argocd_port_forward_command" {
  description = "Command to port-forward to ArgoCD server"
  value       = var.enable_argocd ? module.argocd[0].port_forward_command : "ArgoCD not enabled. Set enable_argocd = true"
}
