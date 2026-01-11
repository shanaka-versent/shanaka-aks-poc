# MTKC POC - Terraform Variables
# @author Shanaka Jayasundera - shanakaj@gmail.com

# Azure Subscription
variable "subscription_id" {
  description = "Azure Subscription ID (optional - uses az CLI default if not set)"
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "australiaeast"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "poc"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "mtkc"
}

# Network
variable "vnet_address_space" {
  description = "VNet address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_cidr" {
  description = "AKS subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "appgw_subnet_cidr" {
  description = "App Gateway subnet CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "network_policy" {
  description = "Network policy provider (azure, calico, cilium)"
  type        = string
  default     = "azure"
}

# AKS Configuration
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32.5"
}

variable "aks_sku_tier" {
  description = "AKS SKU tier (Free, Standard, Premium)"
  type        = string
  default     = "Free"
}

variable "aks_node_count" {
  description = "Number of AKS system nodes"
  type        = number
  default     = 2
}

variable "aks_node_vm_size" {
  description = "VM size for AKS system nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

# User Node Pool (optional)
variable "enable_user_node_pool" {
  description = "Enable separate user node pool"
  type        = bool
  default     = false
}

variable "user_node_count" {
  description = "Number of user nodes"
  type        = number
  default     = 2
}

variable "user_node_vm_size" {
  description = "VM size for user nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

# AKS Autoscaling
variable "enable_aks_autoscaling" {
  description = "Enable AKS cluster autoscaler"
  type        = bool
  default     = false
}

variable "system_node_min_count" {
  description = "Minimum number of system nodes (when autoscaling enabled)"
  type        = number
  default     = 1
}

variable "system_node_max_count" {
  description = "Maximum number of system nodes (when autoscaling enabled)"
  type        = number
  default     = 3
}

variable "user_node_min_count" {
  description = "Minimum number of user nodes (when autoscaling enabled)"
  type        = number
  default     = 1
}

variable "user_node_max_count" {
  description = "Maximum number of user nodes (when autoscaling enabled)"
  type        = number
  default     = 5
}

# AKS Monitoring
variable "enable_monitoring" {
  description = "Enable Log Analytics monitoring for AKS"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 30
}

# AKS Security
variable "enable_azure_policy" {
  description = "Enable Azure Policy addon for AKS"
  type        = bool
  default     = false
}

variable "enable_rg_role_assignment" {
  description = "Enable Network Contributor role on resource group for kubelet"
  type        = bool
  default     = false
}

# TLS Configuration
variable "enable_https" {
  description = "Enable HTTPS on App Gateway"
  type        = bool
  default     = true
}

variable "appgw_ssl_cert_path" {
  description = "Path to App Gateway SSL certificate (PFX format)"
  type        = string
  default     = "../certs/appgw.pfx"
}

variable "appgw_ssl_cert_password" {
  description = "Password for App Gateway SSL certificate"
  type        = string
  sensitive   = true
  default     = "MTKCPoc2024!"
}

variable "backend_https_enabled" {
  description = "Enable HTTPS for backend (Istio Gateway)"
  type        = bool
  default     = true
}

# App Gateway Autoscaling
variable "enable_appgw_autoscaling" {
  description = "Enable autoscaling for App Gateway"
  type        = bool
  default     = false
}

variable "appgw_min_capacity" {
  description = "Minimum App Gateway capacity (when autoscaling enabled)"
  type        = number
  default     = 1
}

variable "appgw_max_capacity" {
  description = "Maximum App Gateway capacity (when autoscaling enabled)"
  type        = number
  default     = 3
}

# App Gateway Features
variable "enable_rewrite_rules" {
  description = "Enable rewrite rules for client headers (X-Forwarded-For, X-Real-IP, etc.)"
  type        = bool
  default     = false
}

# Tags
variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default = {
    Project   = "MTKC-POC"
    Purpose   = "Gateway-API-AppGW-Integration"
    ManagedBy = "Terraform"
  }
}
