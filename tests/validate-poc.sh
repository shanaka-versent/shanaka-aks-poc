#!/bin/bash
# Comprehensive POC validation script
# This script performs all validation checks for the MTKC POC
# @author Shanaka Jayasundera - shanakaj@gmail.com

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "=============================================="
echo "  MTKC POC - Comprehensive Validation       "
echo "=============================================="
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# Get configuration
cd "$PROJECT_ROOT/terraform"
APPGW_IP=$(terraform output -raw appgw_public_ip 2>/dev/null || echo "")
RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
APPGW_NAME=$(terraform output -raw appgw_name 2>/dev/null || echo "")
HTTPS_ENABLED=$(terraform output -raw https_enabled 2>/dev/null || echo "false")

if [ -z "$APPGW_IP" ]; then
    fail "Could not get App Gateway IP. Is Terraform deployed?"
    exit 1
fi

info "App Gateway Public IP: $APPGW_IP"
if [ "$HTTPS_ENABLED" == "true" ]; then
    info "HTTPS Mode: End-to-End TLS enabled"
else
    info "HTTPS Mode: HTTP only"
fi
echo ""

# ============================================
# SC-1: App Gateway health probes succeed
# ============================================
echo "--- SC-1: App Gateway Backend Health ---"
HEALTH=$(az network application-gateway show-backend-health \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APPGW_NAME" \
    --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[0].health' \
    -o tsv 2>/dev/null || echo "Unknown")
if [ "$HEALTH" == "Healthy" ]; then
    pass "Backend health: Healthy"
    ((TESTS_PASSED++))
else
    fail "Backend health: $HEALTH (expected: Healthy)"
    ((TESTS_FAILED++))
fi
echo ""

# ============================================
# SC-2: /healthz/ready returns HTTP 200
# ============================================
echo "--- SC-2: Health Endpoint ---"
if [ "$HTTPS_ENABLED" == "true" ]; then
    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://$APPGW_IP/healthz/ready" 2>/dev/null || echo "000")
else
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$APPGW_IP/healthz/ready" 2>/dev/null || echo "000")
fi
if [ "$HTTP_CODE" == "200" ]; then
    pass "/healthz/ready returned HTTP 200"
    ((TESTS_PASSED++))
else
    fail "/healthz/ready returned HTTP $HTTP_CODE"
    ((TESTS_FAILED++))
fi
echo ""

# ============================================
# SC-3: /app1 routes to Sample App 1
# ============================================
echo "--- SC-3: App 1 Routing ---"
if [ "$HTTPS_ENABLED" == "true" ]; then
    RESPONSE=$(curl -sk "https://$APPGW_IP/app1" 2>/dev/null || echo "")
else
    RESPONSE=$(curl -s "http://$APPGW_IP/app1" 2>/dev/null || echo "")
fi
if [[ "$RESPONSE" == *"Hello from App 1"* ]]; then
    pass "/app1 returns 'Hello from App 1'"
    ((TESTS_PASSED++))
else
    fail "/app1 returned: $RESPONSE"
    ((TESTS_FAILED++))
fi
echo ""

# ============================================
# SC-4: /app2 routes to Sample App 2
# ============================================
echo "--- SC-4: App 2 Routing ---"
if [ "$HTTPS_ENABLED" == "true" ]; then
    RESPONSE=$(curl -sk "https://$APPGW_IP/app2" 2>/dev/null || echo "")
else
    RESPONSE=$(curl -s "http://$APPGW_IP/app2" 2>/dev/null || echo "")
fi
if [[ "$RESPONSE" == *"Hello from App 2"* ]]; then
    pass "/app2 returns 'Hello from App 2'"
    ((TESTS_PASSED++))
else
    fail "/app2 returned: $RESPONSE"
    ((TESTS_FAILED++))
fi
echo ""

# ============================================
# SC-5: Istio Ambient Mesh active (no sidecars)
# ============================================
echo "--- SC-5: Ambient Mesh (No Sidecars) ---"
CONTAINERS=$(kubectl get pods -n sample-apps -o jsonpath='{range .items[*]}{.spec.containers[*].name}{"\n"}{end}' 2>/dev/null)
if echo "$CONTAINERS" | grep -q "istio-proxy"; then
    SIDECAR_COUNT=$(echo "$CONTAINERS" | grep -c "istio-proxy")
    fail "Found $SIDECAR_COUNT sidecars"
    ((TESTS_FAILED++))
else
    pass "No sidecars found - Ambient mesh active"
    ((TESTS_PASSED++))
fi

# Check container count per pod
info "Pod container counts:"
kubectl get pods -n sample-apps -o jsonpath='{range .items[*]}{.metadata.name}: {range .spec.containers[*]}{.name} {end}{"\n"}{end}' 2>/dev/null
echo ""

# ============================================
# SC-6: ztunnel running
# ============================================
echo "--- SC-6: ztunnel Status ---"
ZTUNNEL_RUNNING=$(kubectl get pods -n istio-system -l app=ztunnel -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -c "Running" || echo "0")
ZTUNNEL_TOTAL=$(kubectl get pods -n istio-system -l app=ztunnel --no-headers 2>/dev/null | wc -l)
if [ "$ZTUNNEL_RUNNING" -gt 0 ]; then
    pass "ztunnel pods running: $ZTUNNEL_RUNNING/$ZTUNNEL_TOTAL"
    ((TESTS_PASSED++))
else
    fail "ztunnel pods not running"
    ((TESTS_FAILED++))
fi
echo ""

# ============================================
# SC-7: Using Gateway API (not Ingress)
# ============================================
echo "--- SC-7: Gateway API Resources ---"
GATEWAY_COUNT=$(kubectl get gateway -A --no-headers 2>/dev/null | wc -l)
HTTPROUTE_COUNT=$(kubectl get httproute -A --no-headers 2>/dev/null | wc -l)
INGRESS_COUNT=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l)

if [ "$GATEWAY_COUNT" -ge 1 ] && [ "$HTTPROUTE_COUNT" -ge 3 ]; then
    pass "Gateway API in use: $GATEWAY_COUNT Gateway(s), $HTTPROUTE_COUNT HTTPRoute(s)"
    ((TESTS_PASSED++))
else
    fail "Gateway API resources missing"
    ((TESTS_FAILED++))
fi

if [ "$INGRESS_COUNT" -eq 0 ]; then
    pass "No legacy Ingress resources found"
else
    warn "Found $INGRESS_COUNT legacy Ingress resources"
fi
echo ""

# ============================================
# SC-8: HTTPS / End-to-End TLS (if enabled)
# ============================================
if [ "$HTTPS_ENABLED" == "true" ]; then
    echo "--- SC-8: End-to-End TLS ---"

    # Test HTTPS endpoint (using -k to allow self-signed certs)
    HTTPS_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://$APPGW_IP/healthz/ready" 2>/dev/null || echo "000")
    if [ "$HTTPS_CODE" == "200" ]; then
        pass "HTTPS /healthz/ready returned HTTP 200"
        ((TESTS_PASSED++))
    else
        fail "HTTPS /healthz/ready returned HTTP $HTTPS_CODE"
        ((TESTS_FAILED++))
    fi

    # Test HTTP to HTTPS redirect
    REDIRECT_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L "http://$APPGW_IP/healthz/ready" 2>/dev/null || echo "000")
    REDIRECT_URL=$(curl -s -o /dev/null -w "%{redirect_url}" "http://$APPGW_IP/healthz/ready" 2>/dev/null || echo "")
    if [[ "$REDIRECT_URL" == https://* ]] || [ "$REDIRECT_CODE" == "301" ] || [ "$REDIRECT_CODE" == "308" ]; then
        pass "HTTP to HTTPS redirect working"
    else
        warn "HTTP to HTTPS redirect may not be working (code: $REDIRECT_CODE)"
    fi

    # Test HTTPS app routes
    HTTPS_APP1=$(curl -sk "https://$APPGW_IP/app1" 2>/dev/null || echo "")
    if [[ "$HTTPS_APP1" == *"Hello from App 1"* ]]; then
        pass "HTTPS /app1 returns 'Hello from App 1'"
        ((TESTS_PASSED++))
    else
        fail "HTTPS /app1 failed"
        ((TESTS_FAILED++))
    fi

    HTTPS_APP2=$(curl -sk "https://$APPGW_IP/app2" 2>/dev/null || echo "")
    if [[ "$HTTPS_APP2" == *"Hello from App 2"* ]]; then
        pass "HTTPS /app2 returns 'Hello from App 2'"
        ((TESTS_PASSED++))
    else
        fail "HTTPS /app2 failed"
        ((TESTS_FAILED++))
    fi

    # Check TLS secret exists
    TLS_SECRET=$(kubectl get secret istio-gateway-tls -n istio-ingress -o name 2>/dev/null || echo "")
    if [ -n "$TLS_SECRET" ]; then
        pass "TLS secret exists in istio-ingress namespace"
    else
        warn "TLS secret not found in istio-ingress namespace"
    fi
    echo ""
fi

# ============================================
# Additional checks
# ============================================
echo "--- Additional Checks ---"

# Check Internal LB IP (Istio creates service as <gateway-name>-istio)
INTERNAL_LB_IP=$(kubectl get svc -n istio-ingress mtkc-gateway-istio -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [[ "$INTERNAL_LB_IP" == 10.0.1.* ]]; then
    pass "Internal LB IP in correct subnet: $INTERNAL_LB_IP"
else
    warn "Internal LB IP may not be in expected range: $INTERNAL_LB_IP"
fi

# Check externalTrafficPolicy (required for Azure ILB with App Gateway)
TRAFFIC_POLICY=$(kubectl get svc -n istio-ingress mtkc-gateway-istio -o jsonpath='{.spec.externalTrafficPolicy}' 2>/dev/null || echo "")
if [ "$TRAFFIC_POLICY" == "Local" ]; then
    pass "externalTrafficPolicy: Local (required for Azure ILB)"
else
    warn "externalTrafficPolicy is '$TRAFFIC_POLICY', should be 'Local' for Azure ILB"
fi

# Check all pods are ready
PODS_NOT_READY=$(kubectl get pods -A -l 'app in (health-responder,sample-app-1,sample-app-2)' --no-headers 2>/dev/null | grep -v "Running" | wc -l)
if [ "$PODS_NOT_READY" -eq 0 ]; then
    pass "All application pods are running"
else
    warn "$PODS_NOT_READY pods not in Running state"
fi
echo ""

# ============================================
# Summary
# ============================================
echo "=============================================="
echo "  VALIDATION SUMMARY                         "
echo "=============================================="
echo ""
echo -e "  ${GREEN}Passed${NC}: $TESTS_PASSED"
echo -e "  ${RED}Failed${NC}: $TESTS_FAILED"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All success criteria validated!${NC}"
    echo ""
    echo "POC demonstrates:"
    echo "  - Azure App Gateway with healthy backend"
    echo "  - Kubernetes Gateway API (not Ingress)"
    echo "  - Istio Ambient Mesh (no sidecars)"
    echo "  - Path-based routing working"
    if [ "$HTTPS_ENABLED" == "true" ]; then
        echo "  - End-to-End TLS (HTTPS)"
    fi
    echo ""
    echo "Access URLs:"
    if [ "$HTTPS_ENABLED" == "true" ]; then
        echo "  https://$APPGW_IP/healthz/ready"
        echo "  https://$APPGW_IP/app1"
        echo "  https://$APPGW_IP/app2"
    else
        echo "  http://$APPGW_IP/healthz/ready"
        echo "  http://$APPGW_IP/app1"
        echo "  http://$APPGW_IP/app2"
    fi
    exit 0
else
    echo -e "${RED}Some validation checks failed.${NC}"
    exit 1
fi
