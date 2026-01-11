# ArgoCD Module
# @author Shanaka Jayasundera - shanakaj@gmail.com
# Deploys ArgoCD using Helm provider with Internal LoadBalancer

# Create ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "argocd"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Deploy ArgoCD via Helm
resource "helm_release" "argocd" {
  name       = var.release_name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # Wait for deployment to complete
  wait    = true
  timeout = 600

  # Server configuration
  set {
    name  = "server.service.type"
    value = var.service_type
  }

  # Internal LoadBalancer annotation for Azure
  dynamic "set" {
    for_each = var.service_type == "LoadBalancer" && var.internal_lb ? [1] : []
    content {
      name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
      value = "true"
    }
  }

  # Disable TLS on server (handle TLS at LB level or use port-forward)
  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  # HA mode (optional)
  dynamic "set" {
    for_each = var.enable_ha ? [1] : []
    content {
      name  = "controller.replicas"
      value = "2"
    }
  }

  dynamic "set" {
    for_each = var.enable_ha ? [1] : []
    content {
      name  = "server.replicas"
      value = "2"
    }
  }

  dynamic "set" {
    for_each = var.enable_ha ? [1] : []
    content {
      name  = "repoServer.replicas"
      value = "2"
    }
  }

  # Resource limits (optional)
  dynamic "set" {
    for_each = var.server_resources != null ? [1] : []
    content {
      name  = "server.resources.requests.cpu"
      value = var.server_resources.requests.cpu
    }
  }

  dynamic "set" {
    for_each = var.server_resources != null ? [1] : []
    content {
      name  = "server.resources.requests.memory"
      value = var.server_resources.requests.memory
    }
  }

  depends_on = [kubernetes_namespace.argocd]
}

# Data source to get the ArgoCD initial admin password
data "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  depends_on = [helm_release.argocd]
}

# Data source to get the ArgoCD server service
data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "${var.release_name}-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  depends_on = [helm_release.argocd]
}
