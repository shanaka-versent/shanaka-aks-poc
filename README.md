# KUDOS POC - Gateway API + Azure Application Gateway

This POC validates Azure Application Gateway integration with Kubernetes Gateway API on AKS with Istio Ambient Mesh.

## Key Technologies

- **Kubernetes Gateway API** (NOT classic Ingress)
- **Istio Ambient Mesh** (NOT sidecar mode)
- **Azure Application Gateway v2**
- **Terraform** for all Azure infrastructure
- **End-to-End TLS** with self-signed certificates

## Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
│                         (Client Request)                                     │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ HTTPS:443
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     AZURE APPLICATION GATEWAY v2                             │
│  ┌─────────────────┐  ┌──────────────────┐  ┌─────────────────────────────┐ │
│  │ Frontend IP     │→ │ HTTPS Listener   │→ │ Request Routing Rule        │ │
│  │ (Public IP)     │  │ (TLS Termination)│  │ (Path-based → Backend Pool) │ │
│  └─────────────────┘  └──────────────────┘  └─────────────────────────────┘ │
│                                                         │                    │
│  ┌─────────────────────────────────────────────────────┐│                    │
│  │ Backend Pool: aks-gateway-pool                      ││                    │
│  │ Target: Internal LB IP (10.0.1.x)                   ││                    │
│  │ Backend Settings: HTTPS:443 (re-encrypt)            ││                    │
│  │ Health Probe: /healthz/ready                        ││                    │
│  └─────────────────────────────────────────────────────┘│                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ HTTPS:443 (to Internal LB)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AKS CLUSTER                                        │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │              AZURE INTERNAL LOAD BALANCER (10.0.1.x)                   │ │
│  │   Service: kudos-gateway-istio (type: LoadBalancer)                    │ │
│  │   externalTrafficPolicy: Local (required for DSR)                      │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                         │
│                                    │ Routes to Gateway Pod                   │
│                                    ▼                                         │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                    ISTIO GATEWAY POD (istio-ingress namespace)         │ │
│  │   ┌──────────────────────────────────────────────────────────────────┐ │ │
│  │   │ Gateway Resource: kudos-gateway                                   │ │ │
│  │   │ Listeners: HTTPS:443                                               │ │ │
│  │   │ TLS Secret: istio-gateway-tls (TLS termination)                   │ │ │
│  │   └──────────────────────────────────────────────────────────────────┘ │ │
│  │                                    │                                    │ │
│  │                                    │ HTTPRoute Matching                 │ │
│  │                                    ▼                                    │ │
│  │   ┌──────────────────────────────────────────────────────────────────┐ │ │
│  │   │                      HTTPRoutes                                   │ │ │
│  │   │  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────────┐ │ │ │
│  │   │  │ health-route    │ │ app1-route      │ │ app2-route          │ │ │ │
│  │   │  │ /healthz/*      │ │ /app1           │ │ /app2               │ │ │ │
│  │   │  │ → gateway-health│ │ → sample-apps   │ │ → sample-apps       │ │ │ │
│  │   │  └─────────────────┘ └─────────────────┘ └─────────────────────┘ │ │ │
│  │   └──────────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                         │
│              ┌─────────────────────┼─────────────────────┐                   │
│              ▼                     ▼                     ▼                   │
│  ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐    │
│  │ gateway-health NS   │ │   sample-apps NS    │ │   sample-apps NS    │    │
│  │ ┌─────────────────┐ │ │ ┌─────────────────┐ │ │ ┌─────────────────┐ │    │
│  │ │ health-responder│ │ │ │ sample-app-1    │ │ │ │ sample-app-2    │ │    │
│  │ │ Service:8080    │ │ │ │ Service:8080    │ │ │ │ Service:8080    │ │    │
│  │ │ Pod (1 container│ │ │ │ Pod (1 container│ │ │ │ Pod (1 container│ │    │
│  │ │  - no sidecar)  │ │ │ │  - no sidecar)  │ │ │ │  - no sidecar)  │ │    │
│  │ └─────────────────┘ │ │ └─────────────────┘ │ │ └─────────────────┘ │    │
│  └─────────────────────┘ └─────────────────────┘ └─────────────────────┘    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                    ISTIO AMBIENT MESH (istio-system namespace)         │ │
│  │   ┌──────────────────────────────────────────────────────────────────┐ │ │
│  │   │ ztunnel (DaemonSet) - Runs on each node                          │ │ │
│  │   │ • Intercepts pod traffic transparently (no sidecars needed)      │ │ │
│  │   │ • Provides mTLS between pods                                     │ │ │
│  │   │ • L4 authorization policies                                      │ │ │
│  │   └──────────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### End-to-End TLS Flow (Detailed)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           TLS TERMINATION POINTS                              │
└──────────────────────────────────────────────────────────────────────────────┘

  Client                App Gateway              Istio Gateway           Backend Pod
    │                       │                         │                      │
    │   HTTPS Request       │                         │                      │
    │   (TLS 1.2/1.3)       │                         │                      │
    │──────────────────────►│                         │                      │
    │                       │                         │                      │
    │                   ┌───┴───┐                     │                      │
    │                   │ TLS   │                     │                      │
    │                   │TERMIN.│                     │                      │
    │                   │ #1    │                     │                      │
    │                   └───┬───┘                     │                      │
    │                       │                         │                      │
    │                       │   HTTPS (re-encrypt)    │                      │
    │                       │   Cert: appgw.pfx       │                      │
    │                       │──────────────────────►  │                      │
    │                       │                         │                      │
    │                       │                     ┌───┴───┐                  │
    │                       │                     │ TLS   │                  │
    │                       │                     │TERMIN.│                  │
    │                       │                     │ #2    │                  │
    │                       │                     └───┬───┘                  │
    │                       │                         │                      │
    │                       │                         │   HTTP (plain)       │
    │                       │                         │   via ClusterIP      │
    │                       │                         │─────────────────────►│
    │                       │                         │                      │
    │                       │                         │◄─────────────────────│
    │                       │◄────────────────────────│   Response           │
    │◄──────────────────────│                         │                      │
    │                       │                         │                      │

Certificate Chain:
├── TLS Termination #1 (App Gateway)
│   ├── Certificate: appgw.pfx (CN=kudos-poc.local)
│   ├── Signed by: KUDOS-POC-CA
│   └── Purpose: Frontend HTTPS listener
│
└── TLS Termination #2 (Istio Gateway)
    ├── Certificate: istio-gw.crt (CN=kudos-gateway.istio-ingress.svc.cluster.local)
    ├── Signed by: KUDOS-POC-CA
    ├── K8s Secret: istio-gateway-tls (namespace: istio-ingress)
    └── Purpose: Backend TLS from App Gateway

App Gateway Backend Settings:
├── Protocol: HTTPS
├── Port: 443
├── Host Header: kudos-gateway.istio-ingress.svc.cluster.local
├── Trusted Root CA: ca.crt (KUDOS-POC-CA)
└── Health Probe: HTTPS GET /healthz/ready
```

### Kubernetes Gateway API Components

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        GATEWAY API RESOURCES                                  │
└──────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ Gateway: kudos-gateway (namespace: istio-ingress)                           │
│ GatewayClass: istio                                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│ Listener:                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ Name: https                                                          │   │
│   │ Port: 443                                                            │   │
│   │ Protocol: HTTPS                                                      │   │
│   │ TLS Mode: Terminate                                                  │   │
│   │ Certificate: istio-gateway-tls (Secret)                              │   │
│   │ AllowedRoutes: All namespaces                                        │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────────┤
│ Service Created by Istio:                                                   │
│   Name: kudos-gateway-istio                                                 │
│   Type: LoadBalancer                                                        │
│   Annotations: service.beta.kubernetes.io/azure-load-balancer-internal=true │
│   External IP: 10.0.1.x (Azure Internal LB)                                 │
│   Ports: 443/TCP                                                            │
│   externalTrafficPolicy: Local                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     │ parentRefs
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              HTTPRoutes                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  HTTPRoute: health-route (namespace: gateway-health)                         │
│  ├── parentRefs: kudos-gateway (istio-ingress)                              │
│  ├── matches:                                                                │
│  │   └── path: /healthz/* (PathPrefix)                                      │
│  └── backendRefs:                                                            │
│      └── Service: health-responder:8080                                      │
│                                                                              │
│  HTTPRoute: app1-route (namespace: sample-apps)                              │
│  ├── parentRefs: kudos-gateway (istio-ingress)                              │
│  ├── matches:                                                                │
│  │   └── path: /app1 (PathPrefix)                                           │
│  └── backendRefs:                                                            │
│      └── Service: sample-app-1:8080                                          │
│                                                                              │
│  HTTPRoute: app2-route (namespace: sample-apps)                              │
│  ├── parentRefs: kudos-gateway (istio-ingress)                              │
│  ├── matches:                                                                │
│  │   └── path: /app2 (PathPrefix)                                           │
│  └── backendRefs:                                                            │
│      └── Service: sample-app-2:8080                                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     │ ReferenceGrants allow cross-namespace
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ReferenceGrants                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ ReferenceGrant: allow-istio-ingress-to-gateway-health                        │
│ ├── From: HTTPRoute in istio-ingress namespace                              │
│ └── To: Service in gateway-health namespace                                  │
│                                                                              │
│ ReferenceGrant: allow-istio-ingress-to-sample-apps                           │
│ ├── From: HTTPRoute in istio-ingress namespace                              │
│ └── To: Service in sample-apps namespace                                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Istio Ambient Mesh Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          ISTIO AMBIENT MESH                                   │
│                      (Sidecar-less Service Mesh)                              │
└──────────────────────────────────────────────────────────────────────────────┘

Traditional Sidecar Mode:              Ambient Mode (This POC):
┌─────────────────────────┐           ┌─────────────────────────┐
│ Pod                     │           │ Pod                     │
│ ┌─────────┐ ┌─────────┐ │           │ ┌─────────────────────┐ │
│ │   App   │ │ Sidecar │ │           │ │        App          │ │
│ │Container│ │ (envoy) │ │           │ │    (1 container)    │ │
│ └─────────┘ └─────────┘ │           │ └─────────────────────┘ │
│     2 containers        │           │     1 container         │
└─────────────────────────┘           └─────────────────────────┘
                                                  │
                                      Traffic intercepted by ztunnel
                                                  ▼
                                      ┌─────────────────────────┐
                                      │      ztunnel Pod        │
                                      │   (DaemonSet - 1/node)  │
                                      │  • Transparent proxy    │
                                      │  • mTLS encryption      │
                                      │  • L4 policies          │
                                      └─────────────────────────┘

Namespace Configuration:
┌─────────────────────────────────────────────────────────────────┐
│ Namespaces with Ambient Mesh enabled:                           │
│                                                                  │
│  sample-apps:                                                    │
│    labels:                                                       │
│      istio.io/dataplane-mode: ambient   ← Enables ztunnel       │
│                                                                  │
│  gateway-health:                                                 │
│    labels:                                                       │
│      istio.io/dataplane-mode: ambient   ← Enables ztunnel       │
│                                                                  │
│  istio-ingress:                                                  │
│    (No ambient label - Gateway pod handles its own traffic)      │
└─────────────────────────────────────────────────────────────────┘

ztunnel Traffic Flow:
┌─────────────────────────────────────────────────────────────────┐
│                         Node 1                                   │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────────┐    │
│  │ sample-app-1│ ──► │   ztunnel   │ ──► │ sample-app-2    │    │
│  │    Pod      │     │  (DaemonSet)│     │    Pod          │    │
│  └─────────────┘     │             │     └─────────────────┘    │
│                      │   mTLS      │                             │
│                      │ encryption  │                             │
│                      └─────────────┘                             │
└─────────────────────────────────────────────────────────────────┘
```

### Request Flow Example: GET /app1

```
Step-by-step request flow for: curl -k https://68.218.110.49/app1

1. DNS Resolution
   └── 68.218.110.49 (Azure App Gateway Public IP)

2. App Gateway Frontend
   ├── Public IP: 68.218.110.49
   ├── Listener: https-listener (port 443)
   └── SSL Certificate: appgw.pfx
       └── TLS Termination #1 (decrypts client TLS)

3. App Gateway Routing
   ├── Request Routing Rule: https-rule
   ├── Path: /* (matches all)
   └── Backend Pool: aks-gateway-pool

4. App Gateway Backend
   ├── Backend Pool IP: 10.0.1.x (Internal LB)
   ├── Backend HTTP Settings: https-settings
   │   ├── Protocol: HTTPS (port 443)
   │   ├── Host Header: kudos-gateway.istio-ingress.svc.cluster.local
   │   └── Trusted Root CA: ca.crt
   └── Re-encrypts request → TLS to backend

5. Azure Internal Load Balancer
   ├── IP: 10.0.1.x
   ├── Frontend Port: 443
   └── Routes to: kudos-gateway-istio Service endpoints

6. Kubernetes Service
   ├── Service: kudos-gateway-istio
   ├── Type: LoadBalancer (Internal)
   ├── externalTrafficPolicy: Local
   └── Endpoints: Istio Gateway Pod IPs

7. Istio Gateway Pod
   ├── Receives HTTPS on port 443
   ├── TLS Termination #2 (using istio-gateway-tls secret)
   ├── Gateway: kudos-gateway
   └── Matches request to HTTPRoute

8. HTTPRoute Matching
   ├── Path: /app1
   ├── Matches: app1-route (PathPrefix /app1)
   └── Backend: sample-app-1.sample-apps.svc:8080

9. Service Routing
   ├── Service: sample-app-1 (ClusterIP)
   ├── Port: 8080
   └── Endpoints: sample-app-1 Pod IP

10. Backend Pod
    ├── Pod: sample-app-1-xxxxx
    ├── Container: sample-app-1 (nginx)
    ├── Port: 8080
    └── Returns: "Hello from App 1!"

Response follows reverse path back to client.
```

### Network Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AZURE NETWORKING                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  VNet: vnet-kudos-poc (10.0.0.0/16)                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                                                                      │    │
│  │  Subnet: appgw-subnet (10.0.0.0/24)                                 │    │
│  │  ┌───────────────────────────────────────────────────────────────┐  │    │
│  │  │  Application Gateway: appgw-kudos-poc                         │  │    │
│  │  │  ├── Public IP: 68.218.110.49                                 │  │    │
│  │  │  ├── Private IP: 10.0.0.x                                     │  │    │
│  │  │  └── NSG: Allows 80, 443 inbound from Internet                │  │    │
│  │  └───────────────────────────────────────────────────────────────┘  │    │
│  │                              │                                       │    │
│  │                              │ Backend traffic (HTTPS:443)           │    │
│  │                              ▼                                       │    │
│  │  Subnet: aks-subnet (10.0.1.0/24)                                   │    │
│  │  ┌───────────────────────────────────────────────────────────────┐  │    │
│  │  │  AKS Cluster: aks-kudos-poc                                   │  │    │
│  │  │  ├── Internal LB: 10.0.1.x (kudos-gateway-istio)             │  │    │
│  │  │  ├── Node Pool: System nodes                                  │  │    │
│  │  │  ├── CNI: Azure CNI                                           │  │    │
│  │  │  └── Pod CIDR: From AKS subnet (10.0.1.x)                     │  │    │
│  │  │                                                                │  │    │
│  │  │  Pods:                                                         │  │    │
│  │  │  ├── istio-ingress/kudos-gateway-istio-xxxxx (Gateway)        │  │    │
│  │  │  ├── gateway-health/health-responder-xxxxx                    │  │    │
│  │  │  ├── sample-apps/sample-app-1-xxxxx                           │  │    │
│  │  │  ├── sample-apps/sample-app-2-xxxxx                           │  │    │
│  │  │  └── istio-system/ztunnel-xxxxx (per node)                    │  │    │
│  │  └───────────────────────────────────────────────────────────────┘  │    │
│  │                                                                      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
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
# 1. Deploy Azure infrastructure (generates TLS certificates)
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
| SC-2 | `/healthz/ready` returns HTTP 200 | `curl -k https://<IP>/healthz/ready` |
| SC-3 | `/app1` routes to Sample App 1 | Returns "Hello from App 1" |
| SC-4 | `/app2` routes to Sample App 2 | Returns "Hello from App 2" |
| SC-5 | Istio Ambient Mesh active | Pods have 1 container (no sidecars) |
| SC-6 | ztunnel running | `kubectl get pods -n istio-system -l app=ztunnel` |
| SC-7 | Using Gateway API | `kubectl get gateway,httproute -A` |
| SC-8 | End-to-End TLS working | `curl -k https://<IP>/app1` |

## Project Structure

```
kudos-poc/
├── terraform/              # Azure infrastructure
│   ├── providers.tf
│   ├── variables.tf        # Includes TLS configuration
│   ├── main.tf
│   ├── network.tf          # NSG rules for HTTPS
│   ├── aks.tf
│   ├── appgateway.tf       # HTTPS listeners, SSL certs
│   └── outputs.tf
├── kubernetes/             # K8s manifests
│   ├── 00-namespaces.yaml
│   ├── 01-gateway.yaml     # HTTPS listener with TLS
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

## End-to-End TLS Configuration

This POC implements **End-to-End TLS** encryption:

1. **Client → App Gateway**: HTTPS (TLS termination at App Gateway)
2. **App Gateway → Istio Gateway**: HTTPS (re-encrypted, TLS termination at Istio)
3. **Istio Gateway → Backend Pods**: HTTP (internal cluster traffic)

When running `01-deploy-terraform.sh`:
- Self-signed certificates are automatically generated
- App Gateway is configured with HTTPS listener (port 443)
- HTTP traffic is redirected to HTTPS (301)
- Backend communication uses HTTPS to Istio Gateway

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

## Critical Configuration Fixes

This POC required two critical fixes for Azure Application Gateway + AKS Internal Load Balancer integration:

### Fix #1: HTTPRoute for /healthz (Health Probe Routing)

**Problem:** App Gateway health probes to `/healthz/ready` returned 404 because Istio Gateway (Envoy) didn't know how to route health check requests.

**Solution:** Create a dedicated HTTPRoute that routes `/healthz/*` to a health-responder service.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WHY HTTPRoute FOR HEALTH PROBES?                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  App Gateway                  Istio Gateway                                  │
│  Health Probe                 (Envoy Proxy)                                  │
│       │                            │                                         │
│       │  GET /healthz/ready        │                                         │
│       │───────────────────────────►│                                         │
│       │                            │                                         │
│       │                    ┌───────┴───────┐                                │
│       │                    │ HTTPRoute     │                                │
│       │                    │ Matching?     │                                │
│       │                    └───────┬───────┘                                │
│       │                            │                                         │
│       │              ┌─────────────┴─────────────┐                          │
│       │              │                           │                          │
│       │         NO HTTPRoute              WITH HTTPRoute                    │
│       │              │                           │                          │
│       │              ▼                           ▼                          │
│       │         404 Not Found              200 OK                           │
│       │         (Backend Unhealthy)        (Backend Healthy)                │
│       │                                                                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Files containing this fix:**

| File | Purpose |
|------|---------|
| [kubernetes/05-httproutes.yaml](kubernetes/05-httproutes.yaml) | Defines `health-route` HTTPRoute for `/healthz/*` path |
| [kubernetes/02-health-responder.yaml](kubernetes/02-health-responder.yaml) | Deploys nginx pod that returns 200 OK for health checks |
| [kubernetes/06-reference-grants.yaml](kubernetes/06-reference-grants.yaml) | Allows cross-namespace routing from `istio-ingress` to `gateway-health` |

**HTTPRoute Configuration:**
```yaml
# From kubernetes/05-httproutes.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: health-route
  namespace: gateway-health
spec:
  parentRefs:
    - name: kudos-gateway
      namespace: istio-ingress
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /healthz
      backendRefs:
        - name: health-responder
          port: 8080
```

---

### Fix #2: externalTrafficPolicy: Local (Azure DSR Fix)

**Problem:** App Gateway backend health showed "Unhealthy" with connection timeouts, even though the Internal LB IP was correct and pods were running.

**Solution:** Set `externalTrafficPolicy: Local` on the Istio Gateway service to prevent kube-proxy SNAT from breaking Azure's DSR (Direct Server Return) traffic path.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              WHY externalTrafficPolicy: Local IS REQUIRED                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Azure App Gateway uses DSR (Direct Server Return) with Floating IP:        │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  DEFAULT: externalTrafficPolicy: Cluster (BROKEN)                    │   │
│  │                                                                       │   │
│  │  App Gateway ──► Internal LB ──► kube-proxy ──► Pod                  │   │
│  │      │                              │                                 │   │
│  │      │                         SNAT happens                           │   │
│  │      │                         (changes source IP)                    │   │
│  │      │                              │                                 │   │
│  │      │◄─────────────────────────────┘                                │   │
│  │      │  Response sent to wrong IP!                                    │   │
│  │      │  Connection timeout / 502 error                                │   │
│  │                                                                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  FIX: externalTrafficPolicy: Local (WORKING)                         │   │
│  │                                                                       │   │
│  │  App Gateway ──► Internal LB ──► Pod (direct, no SNAT)               │   │
│  │      │                              │                                 │   │
│  │      │                         No SNAT                                │   │
│  │      │                         (preserves source IP)                  │   │
│  │      │                              │                                 │   │
│  │      │◄─────────────────────────────┘                                │   │
│  │      │  Response returns correctly via DSR                            │   │
│  │      │  Connection successful!                                        │   │
│  │                                                                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Files containing this fix:**

| File | Purpose |
|------|---------|
| [scripts/03-deploy-kubernetes.sh](scripts/03-deploy-kubernetes.sh) | Applies patch after Gateway service is created (line 61) |
| [scripts/04-update-appgw-backend.sh](scripts/04-update-appgw-backend.sh) | Verifies/reapplies if needed before updating backend pool |

**The Fix (applied in scripts):**
```bash
# From scripts/03-deploy-kubernetes.sh (line 61)
kubectl patch svc kudos-gateway-istio -n istio-ingress \
  -p '{"spec":{"externalTrafficPolicy":"Local"}}'
```

**Verification:**
```bash
# Check current policy
kubectl get svc kudos-gateway-istio -n istio-ingress \
  -o jsonpath='{.spec.externalTrafficPolicy}'
# Should output: Local
```

---

### Summary of Critical Fixes

| Fix | Problem | Solution | Key Files |
|-----|---------|----------|-----------|
| **#1 HTTPRoute** | Health probes return 404 | Route `/healthz/*` to health-responder | `05-httproutes.yaml`, `02-health-responder.yaml` |
| **#2 externalTrafficPolicy** | Connection timeouts due to SNAT | Set `externalTrafficPolicy: Local` | `03-deploy-kubernetes.sh`, `04-update-appgw-backend.sh` |

---

## Additional Configuration Notes

### Network Contributor Role

AKS needs Network Contributor role on the VNet to create Internal Load Balancers:

```hcl
# From terraform/aks.tf
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

### Backend Pool Lifecycle (Terraform)

Terraform resets the backend pool on each apply. We use lifecycle ignore to prevent this:

```hcl
# From terraform/appgateway.tf
lifecycle {
  ignore_changes = [
    backend_address_pool,  # Managed by 04-update-appgw-backend.sh
  ]
}
```

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
# Use -k flag for self-signed certificates
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

After successful deployment (use `-k` flag with curl for self-signed certificates):

| Endpoint | URL |
|----------|-----|
| Health Check | `https://<IP>/healthz/ready` |
| App 1 | `https://<IP>/app1` |
| App 2 | `https://<IP>/app2` |

Get the IP from Terraform output:
```bash
cd terraform && terraform output appgw_public_ip
```

**Note:** HTTP requests to port 80 are automatically redirected to HTTPS (301).
