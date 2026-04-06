#!/bin/bash
# Integration tests for API + Terraform

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

API_ENDPOINT="http://localhost:3000"
FAILED=0

echo -e "${BLUE}==================================="
echo -e "INTEGRATION TESTS"
echo -e "===================================${NC}"
echo ""

# Check if API is running
echo -n "Checking API availability... "
if curl -s "${API_ENDPOINT}/health" > /dev/null 2>&1; then
  echo -e "${GREEN}✅${NC}"
else
  echo -e "${RED}❌ API not running${NC}"
  echo "Start it with: cd mock-panorama && npm start"
  exit 1
fi

# Test 1: Health endpoint
echo -n "Test 1: Health endpoint... "
RESPONSE=$(curl -s "${API_ENDPOINT}/health")
SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
if [ "$SUCCESS" = "true" ]; then
  echo -e "${GREEN}✅${NC}"
else
  echo -e "${RED}❌${NC}"
  FAILED=$((FAILED + 1))
fi

# Test 2: Get config
echo -n "Test 2: Get config... "
RESPONSE=$(curl -s "${API_ENDPOINT}/config")
SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
if [ "$SUCCESS" = "true" ]; then
  echo -e "${GREEN}✅${NC}"
else
  echo -e "${RED}❌${NC}"
  FAILED=$((FAILED + 1))
fi

# Test 3: Config has expected structure
echo -n "Test 3: Config structure... "
VERSION=$(echo "$RESPONSE" | jq -r '.data.version')
HOSTNAME=$(echo "$RESPONSE" | jq -r '.data.device.hostname')
if [ "$VERSION" = "1.0.0" ] && [ "$HOSTNAME" = "panorama-mock" ]; then
  echo -e "${GREEN}✅${NC}"
else
  echo -e "${RED}❌${NC}"
  FAILED=$((FAILED + 1))
fi

# Test 4: Inject drift
echo -n "Test 4: Inject drift... "
BEFORE_HASH=$(curl -s "${API_ENDPOINT}/config" | jq -r '.message' | grep -o 'Config hash: .*' | cut -d' ' -f3)

DRIFT_RESPONSE=$(curl -s -X POST "${API_ENDPOINT}/drift" \
  -H "Content-Type: application/json" \
  -d '{"rule": {"name": "test_rule", "source": ["any"], "destination": ["any"], "service": ["any"], "action": "allow", "enabled": true}}')

AFTER_HASH=$(curl -s "${API_ENDPOINT}/config" | jq -r '.message' | grep -o 'Config hash: .*' | cut -d' ' -f3)

if [ "$BEFORE_HASH" != "$AFTER_HASH" ]; then
  echo -e "${GREEN}✅${NC}"
else
  echo -e "${RED}❌ Hash unchanged${NC}"
  FAILED=$((FAILED + 1))
fi

# Test 5: Reset config
echo -n "Test 5: Reset config... "
RESET_RESPONSE=$(curl -s -X POST "${API_ENDPOINT}/reset")
SUCCESS=$(echo "$RESET_RESPONSE" | jq -r '.success')
if [ "$SUCCESS" = "true" ]; then
  echo -e "${GREEN}✅${NC}"
else
  echo -e "${RED}❌${NC}"
  FAILED=$((FAILED + 1))
fi

# Test 6: Policy validation (valid config)
echo -n "Test 6: Policy validation (valid)... "
if ./scripts/validate-policy.sh terraform/desired-config.json > /dev/null 2>&1; then
  echo -e "${GREEN}✅${NC}"
else
  echo -e "${RED}❌${NC}"
  FAILED=$((FAILED + 1))
fi

# Test 7: Policy validation (invalid config)
echo -n "Test 7: Policy validation (invalid)... "
cat > /tmp/test-invalid-config.json << EOF
{
  "version": "1.0.0",
  "device": {"hostname": "test", "model": "test"},
  "policies": {
    "security": [
      {
        "name": "bad_rule",
        "source": ["any"],
        "destination": ["any"],
        "service": ["any"],
        "action": "deny",
        "enabled": true
      }
    ]
  },
  "metadata": {"lastModified": "2024-01-01", "modifiedBy": "test"}
}
EOF

if ! ./scripts/validate-policy.sh /tmp/test-invalid-config.json > /dev/null 2>&1; then
  echo -e "${GREEN}✅ (correctly rejected)${NC}"
else
  echo -e "${RED}❌ (should have failed)${NC}"
  FAILED=$((FAILED + 1))
fi

rm -f /tmp/test-invalid-config.json

echo ""
echo "==================================="
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✅ ALL TESTS PASSED (7/7)${NC}"
  exit 0
else
  echo -e "${RED}❌ $FAILED TESTS FAILED${NC}"
  exit 1
fi
