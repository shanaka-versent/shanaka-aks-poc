# KUDOS POC - Gateway API + Azure Application Gateway

This POC validates Azure Application Gateway integration with Kubernetes Gateway API on AKS with Istio Ambient Mesh.

## Key Technologies

- **Kubernetes Gateway API** (NOT classic Ingress)
- **Istio Ambient Mesh** (NOT sidecar mode)
- **Azure Application Gateway v2**
- **Terraform** for all Azure infrastructure

## Architecture

```
Internet -> Azure App Gateway (Public IP)
                    |
                    v
         Azure Internal Load Balancer (10.0.1.x)
                    |
                    v
         Kubernetes Gateway API (Istio)
                    |
         +----------+----------+
         |          |          |
         v          v          v
    /healthz     /app1      /app2
```

## Quick Start

### Prerequisites

- Azure CLI (`az`) logged in
- Terraform >= 1.5.0
- kubectl
- istioctl (will be installed if missing)

### Deploy

```bash
# 1. Deploy Azure infrastructure
./scripts/01-deploy-terraform.sh

# 2. Install Istio Ambient Mesh
./scripts/02-install-istio-ambient.sh

# 3. Deploy Kubernetes resources
./scripts/03-deploy-kubernetes.sh

# 4. Update App Gateway backend
./scripts/04-update-appgw-backend.sh

# 5. Run validation tests
./scripts/05-run-tests.sh
```

### Cleanup

```bash
./scripts/99-cleanup.sh
```

## Success Criteria

| ID | Criteria | Validation |
|----|----------|------------|
| SC-1 | App Gateway health probes succeed | Backend Health = "Healthy" |
| SC-2 | `/healthz/ready` returns HTTP 200 | `curl http://<IP>/healthz/ready` |
| SC-3 | `/app1` routes to Sample App 1 | Returns "Hello from App 1" |
| SC-4 | `/app2` routes to Sample App 2 | Returns "Hello from App 2" |
| SC-5 | Istio Ambient Mesh active | Pods have 1 container (no sidecars) |
| SC-6 | ztunnel running | `kubectl get pods -n istio-system -l app=ztunnel` |
| SC-7 | Using Gateway API | `kubectl get gateway,httproute -A` |

## Project Structure

```
kudos-poc/
├── terraform/           # Azure infrastructure
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── network.tf
│   ├── aks.tf
│   ├── appgateway.tf
│   └── outputs.tf
├── kubernetes/          # K8s manifests
│   ├── 00-namespaces.yaml
│   ├── 01-gateway.yaml
│   ├── 02-health-responder.yaml
│   ├── 03-sample-app-1.yaml
│   ├── 04-sample-app-2.yaml
│   ├── 05-httproutes.yaml
│   └── 06-reference-grants.yaml
├── scripts/             # Deployment scripts
│   ├── 01-deploy-terraform.sh
│   ├── 02-install-istio-ambient.sh
│   ├── 03-deploy-kubernetes.sh
│   ├── 04-update-appgw-backend.sh
│   ├── 05-run-tests.sh
│   └── 99-cleanup.sh
└── tests/
    └── validate-poc.sh
```

## Quick Reference Commands

```bash
# Get AKS credentials
az aks get-credentials --resource-group rg-kudos-poc --name aks-kudos-poc

# Check Gateway API resources
kubectl get gateway,httproute -A

# Get Gateway Internal LB IP
kubectl get svc -n istio-ingress kudos-gateway

# Check pods (should have 1 container - no sidecars)
kubectl get pods -n sample-apps -o wide

# Check ztunnel (Ambient mesh)
kubectl get pods -n istio-system -l app=ztunnel

# Test endpoints (replace <IP> with App Gateway public IP)
curl http://<IP>/healthz/ready
curl http://<IP>/app1
curl http://<IP>/app2

# Check App Gateway backend health
az network application-gateway show-backend-health \
  --resource-group rg-kudos-poc \
  --name appgw-kudos-poc
```

## Troubleshooting

| Issue | Check | Fix |
|-------|-------|-----|
| Gateway no IP | `kubectl describe gateway kudos-gateway -n istio-ingress` | Wait, check service annotations |
| Backend unhealthy | Check HTTPRoute for /healthz | Verify health-responder running |
| 502 errors | Check Gateway logs | Verify HTTPRoutes attached |
| Sidecars present | Namespace labels | Add `istio.io/dataplane-mode: ambient` |
| ztunnel not running | Istio install | Reinstall with `--set profile=ambient` |
