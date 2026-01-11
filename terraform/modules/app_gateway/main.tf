# Application Gateway Module
# @author Shanaka Jayasundera - shanakaj@gmail.com

# Public IP for App Gateway
resource "azurerm_public_ip" "main" {
  name                = "pip-appgw-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Application Gateway with End-to-End TLS
resource "azurerm_application_gateway" "main" {
  name                = "appgw-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  sku {
    name     = var.sku_name
    tier     = var.sku_tier
    capacity = var.enable_autoscaling ? null : var.capacity
  }

  # Autoscaling configuration (optional)
  dynamic "autoscale_configuration" {
    for_each = var.enable_autoscaling ? [1] : []
    content {
      min_capacity = var.min_capacity
      max_capacity = var.max_capacity
    }
  }

  # SSL Policy - Use TLS 1.2 minimum (required by Azure)
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-public"
    public_ip_address_id = azurerm_public_ip.main.id
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
      data     = filebase64(var.ssl_cert_path)
      password = var.ssl_cert_password
    }
  }

  # Trusted Root CA for backend (Istio Gateway) - End-to-End TLS
  dynamic "trusted_root_certificate" {
    for_each = var.backend_https_enabled ? [1] : []
    content {
      name = "istio-backend-ca"
      data = filebase64(var.backend_ca_cert_path)
    }
  }

  # Backend Pool - Initially empty, updated by script after Gateway API deployment
  backend_address_pool {
    name = var.backend_pool_name
  }

  lifecycle {
    ignore_changes = [
      backend_address_pool,
    ]
  }

  # Backend HTTP Settings (fallback for HTTP)
  backend_http_settings {
    name                                = "http-settings"
    cookie_based_affinity               = "Disabled"
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = var.request_timeout
    probe_name                          = "health-probe-http"
    pick_host_name_from_backend_address = true
    connection_draining {
      enabled           = var.enable_connection_draining
      drain_timeout_sec = var.drain_timeout_sec
    }
  }

  # Backend HTTPS Settings (End-to-End TLS)
  dynamic "backend_http_settings" {
    for_each = var.backend_https_enabled ? [1] : []
    content {
      name                           = "https-settings"
      cookie_based_affinity          = "Disabled"
      port                           = 443
      protocol                       = "Https"
      request_timeout                = var.request_timeout
      probe_name                     = "health-probe-https"
      host_name                      = var.backend_host_name
      trusted_root_certificate_names = ["istio-backend-ca"]
      connection_draining {
        enabled           = var.enable_connection_draining
        drain_timeout_sec = var.drain_timeout_sec
      }
    }
  }

  # Health Probe for HTTP backend
  probe {
    name                                      = "health-probe-http"
    protocol                                  = "Http"
    path                                      = var.health_probe_path
    interval                                  = var.health_probe_interval
    timeout                                   = var.health_probe_timeout
    unhealthy_threshold                       = var.health_probe_unhealthy_threshold
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
      path                = var.health_probe_path
      interval            = var.health_probe_interval
      timeout             = var.health_probe_timeout
      unhealthy_threshold = var.health_probe_unhealthy_threshold
      host                = var.backend_host_name

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

  # Rewrite Rule Set for preserving client information
  dynamic "rewrite_rule_set" {
    for_each = var.enable_rewrite_rules ? [1] : []
    content {
      name = "client-headers-rewrite"

      rewrite_rule {
        name          = "add-x-forwarded-for"
        rule_sequence = 100

        request_header_configuration {
          header_name  = "X-Forwarded-For"
          header_value = "{var_add_x_forwarded_for_proxy}"
        }
      }

      rewrite_rule {
        name          = "add-x-real-ip"
        rule_sequence = 101

        request_header_configuration {
          header_name  = "X-Real-IP"
          header_value = "{var_client_ip}"
        }
      }

      rewrite_rule {
        name          = "add-x-forwarded-proto"
        rule_sequence = 102

        request_header_configuration {
          header_name  = "X-Forwarded-Proto"
          header_value = "https"
        }
      }

      rewrite_rule {
        name          = "add-x-forwarded-host"
        rule_sequence = 103

        request_header_configuration {
          header_name  = "X-Forwarded-Host"
          header_value = "{var_host}"
        }
      }
    }
  }

  # URL Path Map for HTTPS (when enabled)
  dynamic "url_path_map" {
    for_each = var.enable_https && var.backend_https_enabled ? [1] : []
    content {
      name                               = "https-path-map"
      default_backend_address_pool_name  = var.backend_pool_name
      default_backend_http_settings_name = "https-settings"
      default_rewrite_rule_set_name      = var.enable_rewrite_rules ? "client-headers-rewrite" : null

      dynamic "path_rule" {
        for_each = var.path_rules
        content {
          name                       = path_rule.value.name
          paths                      = path_rule.value.paths
          backend_address_pool_name  = var.backend_pool_name
          backend_http_settings_name = "https-settings"
          rewrite_rule_set_name      = var.enable_rewrite_rules ? "client-headers-rewrite" : null
        }
      }
    }
  }

  # URL Path Map for HTTP (fallback or when HTTPS disabled)
  url_path_map {
    name                               = "http-path-map"
    default_backend_address_pool_name  = var.backend_pool_name
    default_backend_http_settings_name = "http-settings"
    default_rewrite_rule_set_name      = var.enable_rewrite_rules ? "client-headers-rewrite" : null

    dynamic "path_rule" {
      for_each = var.path_rules
      content {
        name                       = path_rule.value.name
        paths                      = path_rule.value.paths
        backend_address_pool_name  = var.backend_pool_name
        backend_http_settings_name = "http-settings"
        rewrite_rule_set_name      = var.enable_rewrite_rules ? "client-headers-rewrite" : null
      }
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
      name               = "https-rule"
      priority           = 100
      rule_type          = "PathBasedRouting"
      http_listener_name = "https-listener"
      url_path_map_name  = var.backend_https_enabled ? "https-path-map" : "http-path-map"
    }
  }
}
