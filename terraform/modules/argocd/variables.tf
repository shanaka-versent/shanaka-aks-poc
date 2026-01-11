# ArgoCD Module Variables
# @author Shanaka Jayasundera - shanakaj@gmail.com

variable "namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.55.0"  # Latest stable version
}

variable "service_type" {
  description = "Service type for ArgoCD server (LoadBalancer or ClusterIP)"
  type        = string
  default     = "LoadBalancer"

  validation {
    condition     = contains(["LoadBalancer", "ClusterIP", "NodePort"], var.service_type)
    error_message = "Service type must be LoadBalancer, ClusterIP, or NodePort."
  }
}

variable "internal_lb" {
  description = "Use internal LoadBalancer (Azure Internal LB)"
  type        = bool
  default     = true
}

variable "enable_ha" {
  description = "Enable High Availability mode"
  type        = bool
  default     = false
}

variable "server_resources" {
  description = "Resource requests/limits for ArgoCD server"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = null
}
