# MTKC POC - Main Terraform Configuration
# @author Shanaka Jayasundera - shanakaj@gmail.com

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# Resource Group Module
module "resource_group" {
  source = "./modules/resource_group"

  name_prefix = local.name_prefix
  location    = var.location
  tags        = var.tags
}

# Network Module
module "network" {
  source = "./modules/network"

  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = module.resource_group.name
  vnet_address_space  = var.vnet_address_space
  aks_subnet_cidr     = var.aks_subnet_cidr
  appgw_subnet_cidr   = var.appgw_subnet_cidr
  tags                = var.tags
}

# AKS Module
module "aks" {
  source = "./modules/aks"

  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = module.resource_group.name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.aks_sku_tier

  # System Node Pool
  system_node_count   = var.aks_node_count
  system_node_vm_size = var.aks_node_vm_size

  # User Node Pool (optional)
  enable_user_node_pool = var.enable_user_node_pool
  user_node_count       = var.user_node_count
  user_node_vm_size     = var.user_node_vm_size

  # Autoscaling (optional)
  enable_autoscaling    = var.enable_aks_autoscaling
  system_node_min_count = var.system_node_min_count
  system_node_max_count = var.system_node_max_count
  user_node_min_count   = var.user_node_min_count
  user_node_max_count   = var.user_node_max_count

  # Networking
  subnet_id      = module.network.aks_subnet_id
  vnet_id        = module.network.vnet_id
  network_policy = var.network_policy

  # Monitoring (optional)
  enable_monitoring  = var.enable_monitoring
  log_retention_days = var.log_retention_days

  # Identity & Security
  enable_azure_policy      = var.enable_azure_policy
  enable_rg_role_assignment = var.enable_rg_role_assignment

  tags = var.tags
}

# Application Gateway Module
module "app_gateway" {
  source = "./modules/app_gateway"

  name_prefix           = local.name_prefix
  location              = var.location
  resource_group_name   = module.resource_group.name
  subnet_id             = module.network.appgw_subnet_id

  # HTTPS/TLS
  enable_https          = var.enable_https
  ssl_cert_path         = var.appgw_ssl_cert_path
  ssl_cert_password     = var.appgw_ssl_cert_password
  backend_https_enabled = var.backend_https_enabled
  backend_ca_cert_path  = "${path.module}/../certs/ca.crt"

  # Autoscaling (optional)
  enable_autoscaling = var.enable_appgw_autoscaling
  min_capacity       = var.appgw_min_capacity
  max_capacity       = var.appgw_max_capacity

  # Rewrite Rules
  enable_rewrite_rules = var.enable_rewrite_rules

  tags = var.tags
}
