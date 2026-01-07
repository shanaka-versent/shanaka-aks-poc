# KUDOS POC - Terraform Variables
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
  default     = "kudos"
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

# AKS
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32.5"
}

variable "aks_node_count" {
  description = "Number of AKS nodes"
  type        = number
  default     = 2
}

variable "aks_node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D2s_v3"
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
  default     = "KudosPoc2024!"
}

variable "backend_https_enabled" {
  description = "Enable HTTPS for backend (Istio Gateway)"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default = {
    Project   = "KUDOS-POC"
    Purpose   = "Gateway-API-AppGW-Integration"
    ManagedBy = "Terraform"
  }
}
