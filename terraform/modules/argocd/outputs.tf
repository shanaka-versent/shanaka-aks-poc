# ArgoCD Module Outputs
# @author Shanaka Jayasundera - shanakaj@gmail.com

output "namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "admin_password" {
  description = "ArgoCD admin password"
  value       = data.kubernetes_secret.argocd_admin.data["password"]
  sensitive   = true
}

output "server_service_name" {
  description = "ArgoCD server service name"
  value       = data.kubernetes_service.argocd_server.metadata[0].name
}

output "server_url" {
  description = "ArgoCD server URL"
  value       = var.service_type == "LoadBalancer" ? "http://${try(data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].ip, "pending")}" : "Use port-forward: kubectl port-forward svc/${var.release_name}-server -n ${var.namespace} 8080:80"
}

output "port_forward_command" {
  description = "Command to port-forward to ArgoCD server"
  value       = "kubectl port-forward svc/${var.release_name}-server -n ${var.namespace} 8080:80"
}

output "login_command" {
  description = "ArgoCD CLI login command (after port-forward)"
  value       = "argocd login localhost:8080 --username admin --password $(terraform output -raw argocd_admin_password) --insecure"
}
