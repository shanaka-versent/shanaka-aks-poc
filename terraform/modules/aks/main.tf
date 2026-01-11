# AKS Module
# @author Shanaka Jayasundera - shanakaj@gmail.com

# Log Analytics Workspace for monitoring (optional)
resource "azurerm_log_analytics_workspace" "main" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "law-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-${var.name_prefix}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  tags                = var.tags

  default_node_pool {
    name                         = "system"
    node_count                   = var.enable_autoscaling ? null : var.system_node_count
    min_count                    = var.enable_autoscaling ? var.system_node_min_count : null
    max_count                    = var.enable_autoscaling ? var.system_node_max_count : null
    vm_size                      = var.system_node_vm_size
    vnet_subnet_id               = var.subnet_id
    type                         = "VirtualMachineScaleSets"
    only_critical_addons_enabled = var.enable_user_node_pool
    enable_auto_scaling          = var.enable_autoscaling

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = var.network_policy
    load_balancer_sku = "standard"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
  }

  # Azure Policy addon (optional)
  azure_policy_enabled = var.enable_azure_policy

  # Log Analytics monitoring (optional)
  dynamic "oms_agent" {
    for_each = var.enable_monitoring ? [1] : []
    content {
      log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id
    }
  }

  oidc_issuer_enabled       = var.oidc_issuer_enabled
  workload_identity_enabled = var.workload_identity_enabled
}

# User Node Pool (optional)
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count                 = var.enable_user_node_pool ? 1 : 0
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.user_node_vm_size
  node_count            = var.enable_autoscaling ? null : var.user_node_count
  min_count             = var.enable_autoscaling ? var.user_node_min_count : null
  max_count             = var.enable_autoscaling ? var.user_node_max_count : null
  vnet_subnet_id        = var.user_subnet_id != null ? var.user_subnet_id : var.subnet_id
  enable_auto_scaling   = var.enable_autoscaling
  mode                  = "User"
  tags                  = var.tags
}

# Grant AKS Network Contributor role on VNet (required for internal load balancers)
resource "azurerm_role_assignment" "aks_network_contributor_vnet" {
  scope                = var.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

# Grant AKS Network Contributor role on Resource Group (for kubelet identity)
resource "azurerm_role_assignment" "aks_network_contributor_rg" {
  count                = var.enable_rg_role_assignment ? 1 : 0
  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

data "azurerm_subscription" "current" {}
