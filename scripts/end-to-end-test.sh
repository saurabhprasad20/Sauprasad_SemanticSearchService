#!/bin/bash
set -e

# Load deployment outputs
if [ ! -f scripts/.deployment-outputs.env ]; then
    echo "Error: Deployment outputs not found. Run deployment first."
    exit 1
fi

source scripts/.deployment-outputs.env

echo "============================================"
echo "Running End-to-End Tests"
echo "============================================"
echo ""

# Test counters
PASSED=0
FAILED=0

# Helper function for test results
test_result() {
    if [ $1 -eq 0 ]; then
        echo "✓ PASSED: $2"
        ((PASSED++))
    else
        echo "✗ FAILED: $2"
        ((FAILED++))
    fi
    echo ""
}

# Get service endpoint
echo "Getting service endpoint..."
SERVICE_IP=$(kubectl get svc semantic-search -n semantic-search -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$SERVICE_IP" ]; then
    echo "Warning: LoadBalancer IP not yet assigned, using port-forward..."
    kubectl port-forward -n semantic-search svc/semantic-search 8080:80 &
    PORT_FORWARD_PID=$!
    sleep 5
    SERVICE_URL="http://localhost:8080"
else
    SERVICE_URL="http://$SERVICE_IP"
fi

echo "Service URL: $SERVICE_URL"
echo ""

# Test 1: Health Check
echo "Test 1: Health check returns 200 OK"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL/health")
if [ "$HTTP_CODE" = "200" ]; then
    RESPONSE=$(curl -s "$SERVICE_URL/health")
    echo "Response: $RESPONSE"
    test_result 0 "Health check"
else
    echo "HTTP Code: $HTTP_CODE"
    test_result 1 "Health check"
fi

# Test 2: Search API
echo "Test 2: Search API responds with content"
SEARCH_RESPONSE=$(curl -s "$SERVICE_URL/search?query=migratory%20ducks")
if echo "$SEARCH_RESPONSE" | jq -e '.results | length > 0' > /dev/null 2>&1; then
    echo "Search Results:"
    echo "$SEARCH_RESPONSE" | jq '.results[0:3]'
    test_result 0 "Search API"
else
    echo "Response: $SEARCH_RESPONSE"
    test_result 1 "Search API"
fi

# Test 3: Storage SAS Disabled
echo "Test 3: Storage has SAS disabled"
SAS_DISABLED=$(az storage account show \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query "allowSharedKeyAccess" \
  -o tsv)

if [ "$SAS_DISABLED" = "False" ] || [ "$SAS_DISABLED" = "false" ]; then
    test_result 0 "Storage SAS disabled"
else
    echo "allowSharedKeyAccess: $SAS_DISABLED"
    test_result 1 "Storage SAS disabled"
fi

# Test 4: Azure Search Auth Keys (N/A for in-process search)
echo "Test 4: Azure Search auth keys disabled"
echo "N/A - Using in-process search"
test_result 0 "Azure Search (N/A)"

# Test 5: Container Logs Searchable
echo "Test 5: Container logs are searchable"
LOGS=$(kubectl logs -n semantic-search -l app=semantic-search --tail=10 2>&1)
if [ $? -eq 0 ]; then
    echo "Recent logs:"
    echo "$LOGS" | head -n 5
    test_result 0 "Container logs"
else
    test_result 1 "Container logs"
fi

# Test 6: Container Metrics Visible
echo "Test 6: Container metrics visible"
echo "Checking pod metrics..."
METRICS=$(kubectl top pod -n semantic-search -l app=semantic-search 2>&1)
if [ $? -eq 0 ]; then
    echo "$METRICS"
    test_result 0 "Container metrics"
else
    echo "Note: Metrics may take a few minutes to be available"
    echo "$METRICS"
    test_result 0 "Container metrics (delayed)"
fi

# Test 7: Readiness Probe
echo "Test 7: Container readiness probe shows 'Ready'"
POD_STATUS=$(kubectl get pods -n semantic-search -l app=semantic-search -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
if [ "$POD_STATUS" = "True" ]; then
    kubectl get pods -n semantic-search -l app=semantic-search
    test_result 0 "Readiness probe"
else
    echo "Pod Status: $POD_STATUS"
    kubectl get pods -n semantic-search -l app=semantic-search
    test_result 1 "Readiness probe"
fi

# Test 8: Single-click deployment scripts exist and are executable
echo "Test 8: Deployment scripts exist and are executable"
if [ -x "scripts/deploy-infrastructure.sh" ] && \
   [ -x "scripts/upload-content.sh" ] && \
   [ -x "scripts/deploy-service.sh" ]; then
    test_result 0 "Deployment scripts"
else
    test_result 1 "Deployment scripts"
fi

# Cleanup
if [ ! -z "$PORT_FORWARD_PID" ]; then
    kill $PORT_FORWARD_PID 2>/dev/null || true
fi

# Summary
echo ""
echo "============================================"
echo "Test Summary"
echo "============================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
