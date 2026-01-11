# Application Gateway Module - Variables
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

variable "subnet_id" {
  description = "Subnet ID for App Gateway"
  type        = string
}

# SKU Configuration
variable "sku_name" {
  description = "App Gateway SKU name"
  type        = string
  default     = "Standard_v2"
}

variable "sku_tier" {
  description = "App Gateway SKU tier"
  type        = string
  default     = "Standard_v2"
}

variable "capacity" {
  description = "App Gateway capacity (number of instances, used when autoscaling disabled)"
  type        = number
  default     = 1
}

# Autoscaling
variable "enable_autoscaling" {
  description = "Enable autoscaling for App Gateway"
  type        = bool
  default     = false
}

variable "min_capacity" {
  description = "Minimum capacity when autoscaling enabled"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum capacity when autoscaling enabled"
  type        = number
  default     = 3
}

# HTTPS/TLS Configuration
variable "enable_https" {
  description = "Enable HTTPS on App Gateway"
  type        = bool
  default     = true
}

variable "ssl_cert_path" {
  description = "Path to SSL certificate (PFX format)"
  type        = string
  default     = ""
}

variable "ssl_cert_password" {
  description = "Password for SSL certificate"
  type        = string
  sensitive   = true
  default     = ""
}

variable "backend_https_enabled" {
  description = "Enable HTTPS for backend (end-to-end TLS)"
  type        = bool
  default     = true
}

variable "backend_ca_cert_path" {
  description = "Path to backend CA certificate"
  type        = string
  default     = ""
}

variable "backend_host_name" {
  description = "Backend host name for HTTPS settings"
  type        = string
  default     = "mtkc-gateway.istio-ingress.svc.cluster.local"
}

# Backend Configuration
variable "backend_pool_name" {
  description = "Name for the backend address pool"
  type        = string
  default     = "aks-gateway-pool"
}

variable "request_timeout" {
  description = "Request timeout in seconds"
  type        = number
  default     = 60
}

variable "enable_connection_draining" {
  description = "Enable connection draining"
  type        = bool
  default     = true
}

variable "drain_timeout_sec" {
  description = "Connection drain timeout in seconds"
  type        = number
  default     = 60
}

# Health Probe Configuration
variable "health_probe_path" {
  description = "Path for health probe"
  type        = string
  default     = "/healthz/ready"
}

variable "health_probe_interval" {
  description = "Health probe interval in seconds"
  type        = number
  default     = 30
}

variable "health_probe_timeout" {
  description = "Health probe timeout in seconds"
  type        = number
  default     = 60
}

variable "health_probe_unhealthy_threshold" {
  description = "Number of failed probes before marking unhealthy"
  type        = number
  default     = 3
}

# Rewrite Rules
variable "enable_rewrite_rules" {
  description = "Enable rewrite rules for client headers (X-Forwarded-For, X-Real-IP, etc.)"
  type        = bool
  default     = false
}

# Path Rules
variable "path_rules" {
  description = "List of path rules for URL path map"
  type = list(object({
    name  = string
    paths = list(string)
  }))
  default = [
    {
      name  = "healthz-rule"
      paths = ["/healthz", "/healthz/*"]
    },
    {
      name  = "app1-rule"
      paths = ["/app1", "/app1/*"]
    },
    {
      name  = "app2-rule"
      paths = ["/app2", "/app2/*"]
    }
  ]
}

# Tags
variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
