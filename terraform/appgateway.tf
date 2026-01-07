# KUDOS POC - Application Gateway Configuration
# @author Shanaka Jayasundera - shanakaj@gmail.com

# Public IP for App Gateway
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Application Gateway with End-to-End TLS
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

  # HTTP Port (for redirect to HTTPS)
  frontend_port {
    name = "http-port"
    port = 80
  }

  # HTTPS Port
  dynamic "frontend_port" {
    for_each = var.enable_https ? [1] : []
    content {
      name = "https-port"
      port = 443
    }
  }

  # SSL Certificate for frontend (from PFX file)
  dynamic "ssl_certificate" {
    for_each = var.enable_https ? [1] : []
    content {
      name     = "appgw-ssl-cert"
      data     = filebase64(var.appgw_ssl_cert_path)
      password = var.appgw_ssl_cert_password
    }
  }

  # Trusted Root CA for backend (Istio Gateway) - End-to-End TLS
  dynamic "trusted_root_certificate" {
    for_each = var.backend_https_enabled ? [1] : []
    content {
      name = "istio-backend-ca"
      data = filebase64("${path.module}/../certs/ca.crt")
    }
  }

  # Backend Pool - Initially empty, updated by 04-update-appgw-backend.sh after Gateway API deployment
  # Using lifecycle ignore_changes to prevent Terraform from resetting the pool on subsequent applies
  backend_address_pool {
    name = "aks-gateway-pool"
  }

  lifecycle {
    ignore_changes = [
      # Don't reset backend pool - managed by 04-update-appgw-backend.sh
      backend_address_pool,
    ]
  }

  # Backend HTTP Settings (fallback for HTTP)
  backend_http_settings {
    name                                = "http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 60
    probe_name                          = "health-probe-http"
    pick_host_name_from_backend_address = true
  }

  # Backend HTTPS Settings (End-to-End TLS)
  dynamic "backend_http_settings" {
    for_each = var.backend_https_enabled ? [1] : []
    content {
      name                                = "https-settings"
      cookie_based_affinity               = "Disabled"
      port                                = 443
      protocol                            = "Https"
      request_timeout                     = 60
      probe_name                          = "health-probe-https"
      # Use specific hostname matching the backend certificate CN
      host_name                           = "kudos-gateway.istio-ingress.svc.cluster.local"
      trusted_root_certificate_names      = ["istio-backend-ca"]
    }
  }

  # Health Probe for HTTP backend
  probe {
    name                                      = "health-probe-http"
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

  # Health Probe for HTTPS backend (End-to-End TLS)
  dynamic "probe" {
    for_each = var.backend_https_enabled ? [1] : []
    content {
      name                = "health-probe-https"
      protocol            = "Https"
      path                = "/healthz/ready"
      interval            = 30
      timeout             = 60
      unhealthy_threshold = 3
      # Use specific hostname matching the backend certificate CN
      host                = "kudos-gateway.istio-ingress.svc.cluster.local"

      match {
        status_code = ["200-399"]
      }
    }
  }

  # HTTP Listener (for redirect to HTTPS when enabled)
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-public"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  # HTTPS Listener
  dynamic "http_listener" {
    for_each = var.enable_https ? [1] : []
    content {
      name                           = "https-listener"
      frontend_ip_configuration_name = "frontend-ip-public"
      frontend_port_name             = "https-port"
      protocol                       = "Https"
      ssl_certificate_name           = "appgw-ssl-cert"
    }
  }

  # HTTP to HTTPS Redirect Configuration
  dynamic "redirect_configuration" {
    for_each = var.enable_https ? [1] : []
    content {
      name                 = "http-to-https-redirect"
      redirect_type        = "Permanent"
      target_listener_name = "https-listener"
      include_path         = true
      include_query_string = true
    }
  }

  # URL Path Map for HTTPS (when enabled)
  dynamic "url_path_map" {
    for_each = var.enable_https && var.backend_https_enabled ? [1] : []
    content {
      name                               = "https-path-map"
      default_backend_address_pool_name  = "aks-gateway-pool"
      default_backend_http_settings_name = "https-settings"

      path_rule {
        name                       = "healthz-rule"
        paths                      = ["/healthz", "/healthz/*"]
        backend_address_pool_name  = "aks-gateway-pool"
        backend_http_settings_name = "https-settings"
      }

      path_rule {
        name                       = "app1-rule"
        paths                      = ["/app1", "/app1/*"]
        backend_address_pool_name  = "aks-gateway-pool"
        backend_http_settings_name = "https-settings"
      }

      path_rule {
        name                       = "app2-rule"
        paths                      = ["/app2", "/app2/*"]
        backend_address_pool_name  = "aks-gateway-pool"
        backend_http_settings_name = "https-settings"
      }
    }
  }

  # URL Path Map for HTTP (fallback or when HTTPS disabled)
  url_path_map {
    name                               = "http-path-map"
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

  # Request Routing Rule - HTTP (redirect when HTTPS enabled)
  request_routing_rule {
    name                        = "http-rule"
    priority                    = 200
    rule_type                   = var.enable_https ? "Basic" : "PathBasedRouting"
    http_listener_name          = "http-listener"
    redirect_configuration_name = var.enable_https ? "http-to-https-redirect" : null
    url_path_map_name           = var.enable_https ? null : "http-path-map"
  }

  # Request Routing Rule - HTTPS (End-to-End TLS)
  dynamic "request_routing_rule" {
    for_each = var.enable_https ? [1] : []
    content {
      name                       = "https-rule"
      priority                   = 100
      rule_type                  = "PathBasedRouting"
      http_listener_name         = "https-listener"
      url_path_map_name          = var.backend_https_enabled ? "https-path-map" : "http-path-map"
    }
  }
}
