#!/bin/bash
# Run all validation tests
# @author Shanaka Jayasundera - shanakaj@gmail.com

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; }
fail() { echo -e "${RED}FAIL${NC}: $1"; }
warn() { echo -e "${YELLOW}WARN${NC}: $1"; }

echo "=============================================="
echo "  KUDOS POC - Step 5: Validation Tests       "
echo "=============================================="
echo ""

# Get App Gateway Public IP
cd "$TERRAFORM_DIR"
APPGW_IP=$(terraform output -raw appgw_public_ip)
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
APPGW_NAME=$(terraform output -raw appgw_name)

echo "App Gateway Public IP: $APPGW_IP"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Health probe endpoint
echo "---------------------------------------------"
echo "TEST 1: Health Probe Endpoint (/healthz/ready)"
echo "---------------------------------------------"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$APPGW_IP/healthz/ready" 2>/dev/null || echo "000")
if [ "$RESPONSE" == "200" ]; then
    pass "/healthz/ready returned HTTP 200"
    ((TESTS_PASSED++))
else
    fail "/healthz/ready returned HTTP $RESPONSE (expected 200)"
    ((TESTS_FAILED++))
fi
echo ""

# Test 2: App 1 endpoint
echo "---------------------------------------------"
echo "TEST 2: Sample App 1 (/app1)"
echo "---------------------------------------------"
RESPONSE=$(curl -s "http://$APPGW_IP/app1" 2>/dev/null || echo "")
if [[ "$RESPONSE" == *"Hello from App 1"* ]]; then
    pass "/app1 returned 'Hello from App 1'"
    ((TESTS_PASSED++))
else
    fail "/app1 did not return expected response: $RESPONSE"
    ((TESTS_FAILED++))
fi
echo ""

# Test 3: App 1 info endpoint
echo "---------------------------------------------"
echo "TEST 3: Sample App 1 Info (/app1/info)"
echo "---------------------------------------------"
RESPONSE=$(curl -s "http://$APPGW_IP/app1/info" 2>/dev/null || echo "")
if [[ "$RESPONSE" == *"sample-app-1"* ]]; then
    pass "/app1/info returned JSON with app info"
    ((TESTS_PASSED++))
else
    fail "/app1/info did not return expected response: $RESPONSE"
    ((TESTS_FAILED++))
fi
echo ""

# Test 4: App 2 endpoint
echo "---------------------------------------------"
echo "TEST 4: Sample App 2 (/app2)"
echo "---------------------------------------------"
RESPONSE=$(curl -s "http://$APPGW_IP/app2" 2>/dev/null || echo "")
if [[ "$RESPONSE" == *"Hello from App 2"* ]]; then
    pass "/app2 returned 'Hello from App 2'"
    ((TESTS_PASSED++))
else
    fail "/app2 did not return expected response: $RESPONSE"
    ((TESTS_FAILED++))
fi
echo ""

# Test 5: App 2 info endpoint
echo "---------------------------------------------"
echo "TEST 5: Sample App 2 Info (/app2/info)"
echo "---------------------------------------------"
RESPONSE=$(curl -s "http://$APPGW_IP/app2/info" 2>/dev/null || echo "")
if [[ "$RESPONSE" == *"sample-app-2"* ]]; then
    pass "/app2/info returned JSON with app info"
    ((TESTS_PASSED++))
else
    fail "/app2/info did not return expected response: $RESPONSE"
    ((TESTS_FAILED++))
fi
echo ""

# Test 6: Verify no sidecars (Ambient mesh)
echo "---------------------------------------------"
echo "TEST 6: Verify Ambient Mesh (No Sidecars)"
echo "---------------------------------------------"
SIDECAR_COUNT=$(kubectl get pods -n sample-apps -o jsonpath='{range .items[*]}{.spec.containers[*].name}{"\n"}{end}' | grep -c "istio-proxy" || echo "0")
if [ "$SIDECAR_COUNT" == "0" ]; then
    pass "No istio-proxy sidecars found in sample-apps namespace"
    ((TESTS_PASSED++))
else
    fail "Found $SIDECAR_COUNT istio-proxy sidecars (expected 0 for Ambient mesh)"
    ((TESTS_FAILED++))
fi
echo ""

# Test 7: Verify ztunnel running
echo "---------------------------------------------"
echo "TEST 7: Verify ztunnel Running"
echo "---------------------------------------------"
ZTUNNEL_READY=$(kubectl get pods -n istio-system -l app=ztunnel -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
if [ "$ZTUNNEL_READY" == "Running" ]; then
    pass "ztunnel pods are running"
    ((TESTS_PASSED++))
else
    fail "ztunnel pods not running (status: $ZTUNNEL_READY)"
    ((TESTS_FAILED++))
fi
echo ""

# Test 8: Verify Gateway API resources
echo "---------------------------------------------"
echo "TEST 8: Verify Gateway API Resources"
echo "---------------------------------------------"
GATEWAY_COUNT=$(kubectl get gateway -A --no-headers 2>/dev/null | wc -l)
HTTPROUTE_COUNT=$(kubectl get httproute -A --no-headers 2>/dev/null | wc -l)
if [ "$GATEWAY_COUNT" -ge 1 ] && [ "$HTTPROUTE_COUNT" -ge 3 ]; then
    pass "Found $GATEWAY_COUNT Gateway(s) and $HTTPROUTE_COUNT HTTPRoute(s)"
    ((TESTS_PASSED++))
else
    fail "Expected 1 Gateway and 3 HTTPRoutes, found $GATEWAY_COUNT and $HTTPROUTE_COUNT"
    ((TESTS_FAILED++))
fi
echo ""

# Test 9: App Gateway backend health
echo "---------------------------------------------"
echo "TEST 9: App Gateway Backend Health"
echo "---------------------------------------------"
HEALTH=$(az network application-gateway show-backend-health \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APPGW_NAME" \
    --query 'backendAddressPools[0].backendHttpSettingsCollection[0].servers[0].health' \
    -o tsv 2>/dev/null || echo "Unknown")
if [ "$HEALTH" == "Healthy" ]; then
    pass "App Gateway backend health: Healthy"
    ((TESTS_PASSED++))
else
    fail "App Gateway backend health: $HEALTH (expected: Healthy)"
    ((TESTS_FAILED++))
fi
echo ""

# Summary
echo "=============================================="
echo "  TEST SUMMARY                               "
echo "=============================================="
echo ""
echo -e "  ${GREEN}Passed${NC}: $TESTS_PASSED"
echo -e "  ${RED}Failed${NC}: $TESTS_FAILED"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All tests passed! POC validation successful.${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Check the output above.${NC}"
    exit 1
fi
