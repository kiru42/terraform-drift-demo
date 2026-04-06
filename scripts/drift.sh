#!/bin/bash
# Inject drift into mock Panorama API

set -e

API_ENDPOINT="${API_ENDPOINT:-http://localhost:3000}"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${YELLOW}==================================="
echo -e "DRIFT INJECTION"
echo -e "===================================${NC}"
echo ""

# Check if API is running
if ! curl -s "${API_ENDPOINT}/health" > /dev/null 2>&1; then
  echo -e "${RED}❌ API is not running at ${API_ENDPOINT}${NC}"
  echo "Start it with: cd mock-panorama && npm start"
  exit 1
fi

# Get drift type from argument or use default
DRIFT_TYPE="${1:-add_rule}"

case "$DRIFT_TYPE" in
  add_rule)
    echo "Injecting drift: Adding rogue firewall rule..."
    DRIFT_DATA='{
      "rule": {
        "name": "rogue_allow_all",
        "source": ["any"],
        "destination": ["any"],
        "service": ["any"],
        "action": "allow",
        "enabled": true,
        "description": "Unauthorized rule added manually"
      }
    }'
    ;;
    
  modify)
    echo "Injecting drift: Modifying first rule..."
    DRIFT_DATA='{"action": "modify_first"}'
    ;;
    
  delete)
    echo "Injecting drift: Deleting last rule..."
    DRIFT_DATA='{"action": "delete_last"}'
    ;;
    
  *)
    echo -e "${RED}Unknown drift type: $DRIFT_TYPE${NC}"
    echo "Usage: $0 [add_rule|modify|delete]"
    exit 1
    ;;
esac

# Inject drift
RESPONSE=$(curl -X POST "${API_ENDPOINT}/drift" \
  -H "Content-Type: application/json" \
  -d "$DRIFT_DATA" \
  -s)

SUCCESS=$(echo "$RESPONSE" | jq -r '.success')

if [ "$SUCCESS" = "true" ]; then
  echo -e "${GREEN}✅ Drift injected successfully${NC}"
  echo "$RESPONSE" | jq '.'
  echo ""
  echo -e "${YELLOW}Configuration has been modified manually!${NC}"
  echo "Run 'cd terraform && terraform plan' to detect drift"
else
  echo -e "${RED}❌ Failed to inject drift${NC}"
  echo "$RESPONSE" | jq '.'
  exit 1
fi
