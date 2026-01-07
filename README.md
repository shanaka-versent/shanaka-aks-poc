# KUDOS POC - Gateway API + Azure Application Gateway

This POC validates Azure Application Gateway integration with Kubernetes Gateway API on AKS with Istio Ambient Mesh.

## Key Technologies

- **Kubernetes Gateway API** (NOT classic Ingress)
- **Istio Ambient Mesh** (NOT sidecar mode)
- **Azure Application Gateway v2**
- **Terraform** for all Azure infrastructure
- **End-to-End TLS** (optional, self-signed certificates for POC)

## Architecture

### HTTP Mode
```
Internet (HTTP:80)
       |
       v
Azure App Gateway (Public IP)
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

### HTTPS Mode (End-to-End TLS)
```
Internet (HTTPS:443)
       |
       v
Azure App Gateway (TLS termination + re-encrypt)
       | HTTPS:443
       v
Azure Internal Load Balancer (10.0.1.x)
       |
       v
Kubernetes Gateway API (TLS termination)
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
- openssl (for TLS certificate generation)

### Deploy

```bash
# 1. Deploy Azure infrastructure (prompts for HTTPS)
./scripts/01-deploy-terraform.sh

# 2. Install Istio Ambient Mesh
./scripts/02-install-istio-ambient.sh

# 3. Deploy Kubernetes resources
./scripts/03-deploy-kubernetes.sh

# 4. Update App Gateway backend
./scripts/04-update-appgw-backend.sh

# 5. Run validation tests
./tests/validate-poc.sh
```

### Cleanup

```bash
./scripts/99-cleanup.sh
```

## Success Criteria

| ID | Criteria | Validation |
|----|----------|------------|
| SC-1 | App Gateway health probes succeed | Backend Health = "Healthy" |
| SC-2 | `/healthz/ready` returns HTTP 200 | `curl http(s)://<IP>/healthz/ready` |
| SC-3 | `/app1` routes to Sample App 1 | Returns "Hello from App 1" |
| SC-4 | `/app2` routes to Sample App 2 | Returns "Hello from App 2" |
| SC-5 | Istio Ambient Mesh active | Pods have 1 container (no sidecars) |
| SC-6 | ztunnel running | `kubectl get pods -n istio-system -l app=ztunnel` |
| SC-7 | Using Gateway API | `kubectl get gateway,httproute -A` |
| SC-8 | HTTPS working (if enabled) | `curl -k https://<IP>/app1` |

## Project Structure

```
kudos-poc/
├── terraform/              # Azure infrastructure
│   ├── providers.tf
│   ├── variables.tf        # Includes TLS configuration
│   ├── main.tf
│   ├── network.tf          # NSG rules for HTTP/HTTPS
│   ├── aks.tf
│   ├── appgateway.tf       # HTTPS listeners, SSL certs
│   └── outputs.tf
├── kubernetes/             # K8s manifests
│   ├── 00-namespaces.yaml
│   ├── 01-gateway.yaml     # HTTP + HTTPS listeners
│   ├── 02-health-responder.yaml
│   ├── 03-sample-app-1.yaml
│   ├── 04-sample-app-2.yaml
│   ├── 05-httproutes.yaml
│   └── 06-reference-grants.yaml
├── scripts/                # Deployment scripts
│   ├── 00-setup-subscription.sh   # Multi-subscription setup
│   ├── 01-deploy-terraform.sh
│   ├── 02-install-istio-ambient.sh
│   ├── 03-deploy-kubernetes.sh
│   ├── 04-update-appgw-backend.sh
│   ├── generate-tls-certs.sh      # TLS certificate generation
│   ├── create-tls-secrets.sh      # K8s TLS secrets
│   └── 99-cleanup.sh
├── tests/
│   └── validate-poc.sh
├── certs/                  # Generated TLS certificates (gitignored)
│   ├── ca.crt              # Root CA
│   ├── appgw.pfx           # App Gateway certificate
│   ├── istio-gw.crt        # Istio Gateway certificate
│   └── istio-gw.key
└── .gitignore
```

## HTTPS / TLS Configuration

### Enabling HTTPS

When running `01-deploy-terraform.sh`, you'll be prompted to enable HTTPS. If you choose "yes":

1. Self-signed certificates are automatically generated
2. App Gateway is configured with HTTPS listener (port 443)
3. HTTP traffic is redirected to HTTPS (301)
4. Backend communication uses HTTPS (End-to-End TLS)

### Manual Certificate Generation

```bash
# Generate certificates manually
./scripts/generate-tls-certs.sh

# Create K8s TLS secret
./scripts/create-tls-secrets.sh
```

### Certificate Details

| Certificate | Purpose | CN |
|------------|---------|-----|
| `ca.crt` | Root CA for signing | KUDOS-POC-CA |
| `appgw.pfx` | App Gateway frontend | kudos-poc.local |
| `istio-gw.crt` | Istio Gateway backend | kudos-gateway.istio-ingress.svc.cluster.local |

## Critical Configuration Notes

### externalTrafficPolicy: Local

This is **REQUIRED** for Azure Internal Load Balancer to work with App Gateway:

```bash
kubectl patch svc kudos-gateway-istio -n istio-ingress \
  -p '{"spec":{"externalTrafficPolicy":"Local"}}'
```

**Why?** Azure Standard ILB uses DSR (Direct Server Return) with Floating IP. Without `externalTrafficPolicy: Local`, kube-proxy performs SNAT which breaks the DSR traffic path.

### Network Contributor Role

AKS needs Network Contributor role on the VNet to create Internal Load Balancers:

```hcl
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_virtual_network.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}
```

### Gateway Service Naming

Istio creates the service with suffix `-istio`:
- Gateway name: `kudos-gateway`
- Service name: `kudos-gateway-istio`

## Quick Reference Commands

```bash
# Get AKS credentials
az aks get-credentials --resource-group rg-kudos-poc --name aks-kudos-poc

# Check Gateway API resources
kubectl get gateway,httproute -A

# Get Gateway Internal LB IP
kubectl get svc -n istio-ingress kudos-gateway-istio

# Check pods (should have 1 container - no sidecars)
kubectl get pods -n sample-apps -o wide

# Check ztunnel (Ambient mesh)
kubectl get pods -n istio-system -l app=ztunnel

# Check externalTrafficPolicy
kubectl get svc kudos-gateway-istio -n istio-ingress -o jsonpath='{.spec.externalTrafficPolicy}'

# Test endpoints (replace <IP> with App Gateway public IP)
# HTTP mode:
curl http://<IP>/healthz/ready
curl http://<IP>/app1
curl http://<IP>/app2

# HTTPS mode (use -k for self-signed certs):
curl -k https://<IP>/healthz/ready
curl -k https://<IP>/app1
curl -k https://<IP>/app2

# Check App Gateway backend health
az network application-gateway show-backend-health \
  --resource-group rg-kudos-poc \
  --name appgw-kudos-poc

# Check TLS secret
kubectl get secret istio-gateway-tls -n istio-ingress
```

## Troubleshooting

| Issue | Check | Fix |
|-------|-------|-----|
| Gateway no IP | `kubectl describe gateway kudos-gateway -n istio-ingress` | Check AKS Network Contributor role |
| Backend unhealthy | Check HTTPRoute for /healthz | Verify health-responder running |
| 502 errors | Check Gateway logs | Verify HTTPRoutes attached |
| Sidecars present | Namespace labels | Add `istio.io/dataplane-mode: ambient` |
| ztunnel not running | Istio install | Reinstall with `--set profile=ambient` |
| HTTPS 502 | Certificate hostname mismatch | Check backend settings hostname |
| Backend timeout | externalTrafficPolicy | Patch service to `Local` |
| LoadBalancer pending | Network Contributor role | Add role to AKS identity |

### Common HTTPS Issues

1. **Certificate hostname mismatch**: Backend settings must use `host_name = "kudos-gateway.istio-ingress.svc.cluster.local"`

2. **Trusted root certificate**: App Gateway needs the CA certificate that signed the backend cert

3. **TLS secret not found**: Run `./scripts/create-tls-secrets.sh` or check namespace

## Multi-Subscription Support

To deploy to a different Azure subscription:

```bash
# Option 1: Set subscription before deploying
az account set --subscription <SUBSCRIPTION_ID>
./scripts/01-deploy-terraform.sh

# Option 2: Use the setup script
./scripts/00-setup-subscription.sh
```

The setup script handles Terraform state management for multiple subscriptions using workspaces.

## Access URLs

After successful deployment:

| Mode | Health | App 1 | App 2 |
|------|--------|-------|-------|
| HTTP | `http://<IP>/healthz/ready` | `http://<IP>/app1` | `http://<IP>/app2` |
| HTTPS | `https://<IP>/healthz/ready` | `https://<IP>/app1` | `https://<IP>/app2` |

Get the IP from Terraform output:
```bash
cd terraform && terraform output appgw_public_ip
```
