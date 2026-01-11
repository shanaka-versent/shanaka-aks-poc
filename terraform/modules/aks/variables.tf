# AKS Module - Variables
# @author Shanaka Jayasundera - shanakaj@gmail.com

variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}

variable "sku_tier" {
  description = "AKS SKU tier (Free, Standard, Premium)"
  type        = string
  default     = "Free"
}

# System Node Pool
variable "system_node_count" {
  description = "Number of system nodes (when autoscaling disabled)"
  type        = number
  default     = 2
}

variable "system_node_vm_size" {
  description = "VM size for system nodes"
  type        = string
  default     = "Standard_D2s_v3"
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

# User Node Pool
variable "enable_user_node_pool" {
  description = "Enable separate user node pool"
  type        = bool
  default     = false
}

variable "user_node_count" {
  description = "Number of user nodes (when autoscaling disabled)"
  type        = number
  default     = 2
}

variable "user_node_vm_size" {
  description = "VM size for user nodes"
  type        = string
  default     = "Standard_D2s_v3"
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

variable "user_subnet_id" {
  description = "Subnet ID for user node pool (optional, defaults to system subnet)"
  type        = string
  default     = null
}

# Autoscaling
variable "enable_autoscaling" {
  description = "Enable cluster autoscaler"
  type        = bool
  default     = false
}

# Network
variable "subnet_id" {
  description = "Subnet ID for AKS system nodes"
  type        = string
}

variable "vnet_id" {
  description = "VNet ID for role assignment"
  type        = string
}

variable "service_cidr" {
  description = "Service CIDR for Kubernetes services"
  type        = string
  default     = "10.1.0.0/16"
}

variable "dns_service_ip" {
  description = "DNS service IP"
  type        = string
  default     = "10.1.0.10"
}

variable "network_policy" {
  description = "Network policy provider (azure, calico, cilium)"
  type        = string
  default     = "azure"
}

# Identity & Security
variable "oidc_issuer_enabled" {
  description = "Enable OIDC issuer for workload identity"
  type        = bool
  default     = true
}

variable "workload_identity_enabled" {
  description = "Enable workload identity"
  type        = bool
  default     = true
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy addon"
  type        = bool
  default     = false
}

variable "enable_rg_role_assignment" {
  description = "Enable Network Contributor role on resource group for kubelet"
  type        = bool
  default     = false
}

# Monitoring
variable "enable_monitoring" {
  description = "Enable Log Analytics monitoring"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 30
}

# Tags
variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
