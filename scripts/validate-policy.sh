#!/bin/bash
# Validate firewall policy before applying

set -e

CONFIG_FILE="${1:-terraform/desired-config.json}"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${YELLOW}==================================="
echo -e "POLICY VALIDATION"
echo -e "===================================${NC}"
echo ""

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${RED}❌ Config file not found: $CONFIG_FILE${NC}"
  exit 1
fi

# Validate JSON format
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
  echo -e "${RED}❌ Invalid JSON format${NC}"
  exit 1
fi

echo "✅ JSON format valid"

# Extract policies
POLICIES=$(jq -r '.policies.security[]' "$CONFIG_FILE")

# Rule 1: No blanket "deny all" rules (too restrictive)
DENY_ALL_COUNT=$(jq -r '[.policies.security[] | select(.action == "deny" and (.source | index("any")) and (.destination | index("any")))] | length' "$CONFIG_FILE")

if [ "$DENY_ALL_COUNT" -gt 0 ]; then
  echo -e "${RED}❌ VALIDATION FAILED: Found $DENY_ALL_COUNT blanket 'deny all' rule(s)${NC}"
  echo "Blanket deny rules are too restrictive and should be avoided."
  jq -r '.policies.security[] | select(.action == "deny" and (.source | index("any")) and (.destination | index("any"))) | .name' "$CONFIG_FILE"
  exit 1
fi

echo "✅ No blanket deny rules"

# Rule 2: All rules must have a name
UNNAMED_COUNT=$(jq -r '[.policies.security[] | select(.name == "" or .name == null)] | length' "$CONFIG_FILE")

if [ "$UNNAMED_COUNT" -gt 0 ]; then
  echo -e "${RED}❌ VALIDATION FAILED: Found $UNNAMED_COUNT unnamed rule(s)${NC}"
  exit 1
fi

echo "✅ All rules have names"

# Rule 3: All rules must have valid action
INVALID_ACTION_COUNT=$(jq -r '[.policies.security[] | select(.action != "allow" and .action != "deny" and .action != "drop")] | length' "$CONFIG_FILE")

if [ "$INVALID_ACTION_COUNT" -gt 0 ]; then
  echo -e "${RED}❌ VALIDATION FAILED: Found $INVALID_ACTION_COUNT rule(s) with invalid action${NC}"
  exit 1
fi

echo "✅ All rules have valid actions"

# Rule 4: Warn about overly permissive "any any any allow" rules
ANY_ANY_ALLOW_COUNT=$(jq -r '[.policies.security[] | select(.action == "allow" and (.source | index("any")) and (.destination | index("any")) and (.service | index("any")))] | length' "$CONFIG_FILE")

if [ "$ANY_ANY_ALLOW_COUNT" -gt 0 ]; then
  echo -e "${YELLOW}⚠️  WARNING: Found $ANY_ANY_ALLOW_COUNT overly permissive 'allow any any' rule(s)${NC}"
  jq -r '.policies.security[] | select(.action == "allow" and (.source | index("any")) and (.destination | index("any")) and (.service | index("any"))) | .name' "$CONFIG_FILE"
  echo "Consider restricting source, destination, or service"
  # Warning only, don't fail
fi

# Count total rules
TOTAL_RULES=$(jq -r '[.policies.security[]] | length' "$CONFIG_FILE")

echo ""
echo -e "${GREEN}✅ Policy validation passed${NC}"
echo "Total rules: $TOTAL_RULES"
echo ""
