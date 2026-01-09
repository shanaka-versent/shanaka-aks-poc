#!/bin/bash
# Generate TLS certificates for end-to-end TLS
# This creates self-signed certificates for POC purposes
# @author Shanaka Jayasundera - shanakaj@gmail.com

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="$PROJECT_ROOT/certs"

echo "=============================================="
echo "  MTKC POC - Generate TLS Certificates      "
echo "=============================================="
echo ""

# Create certs directory
mkdir -p "$CERTS_DIR"

# Get the domain name (default to the App Gateway IP if no domain provided)
DOMAIN="${1:-mtkc-poc.local}"

echo "[1/4] Generating Root CA..."
# Generate Root CA (for self-signed certs)
openssl genrsa -out "$CERTS_DIR/ca.key" 4096
openssl req -x509 -new -nodes -sha256 -days 365 \
    -key "$CERTS_DIR/ca.key" \
    -out "$CERTS_DIR/ca.crt" \
    -subj "/C=US/ST=State/L=City/O=MTKC-POC/CN=MTKC-POC-CA"

echo "[2/4] Generating App Gateway certificate..."
# Generate App Gateway certificate (frontend - public facing)
openssl genrsa -out "$CERTS_DIR/appgw.key" 2048

# Create SAN config for App Gateway
cat > "$CERTS_DIR/appgw-san.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = MTKC-POC
CN = $DOMAIN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF

openssl req -new -key "$CERTS_DIR/appgw.key" \
    -out "$CERTS_DIR/appgw.csr" \
    -config "$CERTS_DIR/appgw-san.cnf"

openssl x509 -req -in "$CERTS_DIR/appgw.csr" \
    -CA "$CERTS_DIR/ca.crt" \
    -CAkey "$CERTS_DIR/ca.key" \
    -CAcreateserial \
    -out "$CERTS_DIR/appgw.crt" \
    -days 365 \
    -sha256 \
    -extfile "$CERTS_DIR/appgw-san.cnf" \
    -extensions v3_req

# Create PFX for Azure App Gateway (requires password)
APPGW_PFX_PASSWORD="MTKCPoc2024!"
openssl pkcs12 -export \
    -out "$CERTS_DIR/appgw.pfx" \
    -inkey "$CERTS_DIR/appgw.key" \
    -in "$CERTS_DIR/appgw.crt" \
    -certfile "$CERTS_DIR/ca.crt" \
    -password "pass:$APPGW_PFX_PASSWORD"

echo "[3/4] Generating Istio Gateway certificate (backend)..."
# Generate Istio Gateway certificate (backend - internal)
openssl genrsa -out "$CERTS_DIR/istio-gw.key" 2048

# Create SAN config for Istio Gateway
cat > "$CERTS_DIR/istio-gw-san.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = MTKC-POC
CN = mtkc-gateway.istio-ingress.svc.cluster.local

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = mtkc-gateway.istio-ingress.svc.cluster.local
DNS.2 = mtkc-gateway-istio.istio-ingress.svc.cluster.local
DNS.3 = *.istio-ingress.svc.cluster.local
DNS.4 = localhost
DNS.5 = *
IP.1 = 127.0.0.1
EOF

openssl req -new -key "$CERTS_DIR/istio-gw.key" \
    -out "$CERTS_DIR/istio-gw.csr" \
    -config "$CERTS_DIR/istio-gw-san.cnf"

openssl x509 -req -in "$CERTS_DIR/istio-gw.csr" \
    -CA "$CERTS_DIR/ca.crt" \
    -CAkey "$CERTS_DIR/ca.key" \
    -CAcreateserial \
    -out "$CERTS_DIR/istio-gw.crt" \
    -days 365 \
    -sha256 \
    -extfile "$CERTS_DIR/istio-gw-san.cnf" \
    -extensions v3_req

echo "[4/4] Creating certificate summary..."

# Save password to file for scripts
echo "$APPGW_PFX_PASSWORD" > "$CERTS_DIR/appgw-pfx-password.txt"

# Create base64 encoded versions for Terraform
base64 -i "$CERTS_DIR/appgw.pfx" > "$CERTS_DIR/appgw.pfx.base64"

echo ""
echo "=============================================="
echo "  Certificates Generated Successfully        "
echo "=============================================="
echo ""
echo "Files created in: $CERTS_DIR"
echo ""
echo "  Root CA:"
echo "    - ca.key (private key)"
echo "    - ca.crt (certificate)"
echo ""
echo "  App Gateway (frontend):"
echo "    - appgw.key, appgw.crt"
echo "    - appgw.pfx (for Azure, password: $APPGW_PFX_PASSWORD)"
echo ""
echo "  Istio Gateway (backend):"
echo "    - istio-gw.key, istio-gw.crt"
echo ""
echo "Next steps:"
echo "  1. Run Terraform to deploy with HTTPS"
echo "  2. Create K8s TLS secret for Istio Gateway"
echo ""
