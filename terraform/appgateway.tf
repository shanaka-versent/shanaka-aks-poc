# Public IP for App Gateway
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = "appgw-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  # SSL Policy - Use TLS 1.2 minimum (required by Azure)
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-public"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  # Backend Pool - Initially empty, updated after Gateway API deployment
  backend_address_pool {
    name = "aks-gateway-pool"
  }

  # Backend HTTP Settings
  backend_http_settings {
    name                                = "http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 60
    probe_name                          = "health-probe"
    pick_host_name_from_backend_address = true
  }

  # Health Probe for Gateway API
  probe {
    name                                      = "health-probe"
    protocol                                  = "Http"
    path                                      = "/healthz/ready"
    interval                                  = 30
    timeout                                   = 60
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true

    match {
      status_code = ["200-399"]
    }
  }

  # HTTP Listener
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-public"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  # URL Path Map for path-based routing
  url_path_map {
    name                               = "path-map"
    default_backend_address_pool_name  = "aks-gateway-pool"
    default_backend_http_settings_name = "http-settings"

    path_rule {
      name                       = "healthz-rule"
      paths                      = ["/healthz", "/healthz/*"]
      backend_address_pool_name  = "aks-gateway-pool"
      backend_http_settings_name = "http-settings"
    }

    path_rule {
      name                       = "app1-rule"
      paths                      = ["/app1", "/app1/*"]
      backend_address_pool_name  = "aks-gateway-pool"
      backend_http_settings_name = "http-settings"
    }

    path_rule {
      name                       = "app2-rule"
      paths                      = ["/app2", "/app2/*"]
      backend_address_pool_name  = "aks-gateway-pool"
      backend_http_settings_name = "http-settings"
    }
  }

  # Request Routing Rule
  request_routing_rule {
    name                       = "path-based-rule"
    priority                   = 100
    rule_type                  = "PathBasedRouting"
    http_listener_name         = "http-listener"
    url_path_map_name          = "path-map"
  }
}
