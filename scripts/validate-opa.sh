#!/bin/bash
# Advanced Policy Validation with OPA (Open Policy Agent)
# Validates firewall configuration against enterprise security policies

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONFIG_FILE="${1:-terraform/desired-config.json}"
POLICY_DIR="opa/policies"
POLICY_FILE="$POLICY_DIR/firewall-security.rego"

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}OPA POLICY VALIDATION${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Check if OPA is installed
if ! command -v opa &> /dev/null; then
    echo -e "${RED}❌ OPA is not installed${NC}"
    echo ""
    echo "Install OPA:"
    echo "  # Linux/macOS:"
    echo "  curl -L -o /tmp/opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64"
    echo "  chmod +x /tmp/opa"
    echo "  sudo mv /tmp/opa /usr/local/bin/"
    echo ""
    echo "  # Or via package manager:"
    echo "  brew install opa  # macOS"
    echo "  apt install opa   # Debian/Ubuntu"
    echo ""
    exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Configuration file not found: $CONFIG_FILE${NC}"
    exit 1
fi

# Check if policy file exists
if [ ! -f "$POLICY_FILE" ]; then
    echo -e "${RED}❌ OPA policy file not found: $POLICY_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Configuration: $CONFIG_FILE${NC}"
echo -e "${GREEN}✅ Policy: $POLICY_FILE${NC}"
echo ""

# Validate OPA policy syntax
echo -e "${BLUE}Validating OPA policy syntax...${NC}"
if ! opa check "$POLICY_FILE" 2>/dev/null; then
    echo -e "${RED}❌ OPA policy syntax error${NC}"
    opa check "$POLICY_FILE"
    exit 1
fi
echo -e "${GREEN}✅ Policy syntax valid${NC}"
echo ""

# Run OPA evaluation - Deny rules (violations)
echo -e "${BLUE}Checking for security violations (deny rules)...${NC}"
DENY_COUNT=$(opa eval --data "$POLICY_FILE" --input "$CONFIG_FILE" \
    --format pretty 'data.firewall.security.deny' 2>/dev/null | \
    grep -c "Rule" || echo "0")

if [ "$DENY_COUNT" -gt 0 ]; then
    echo -e "${RED}❌ Found $DENY_COUNT security violation(s):${NC}"
    echo ""
    opa eval --data "$POLICY_FILE" --input "$CONFIG_FILE" \
        --format pretty 'data.firewall.security.deny' | \
        sed 's/^/  /'
    echo ""
    VIOLATIONS=true
else
    echo -e "${GREEN}✅ No security violations found${NC}"
    echo ""
    VIOLATIONS=false
fi

# Run OPA evaluation - Warn rules (best practices)
echo -e "${BLUE}Checking for best practice warnings...${NC}"
WARN_COUNT=$(opa eval --data "$POLICY_FILE" --input "$CONFIG_FILE" \
    --format pretty 'data.firewall.security.warn' 2>/dev/null | \
    grep -c "Rule\|recommended" || echo "0")

if [ "$WARN_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $WARN_COUNT warning(s):${NC}"
    echo ""
    opa eval --data "$POLICY_FILE" --input "$CONFIG_FILE" \
        --format pretty 'data.firewall.security.warn' | \
        sed 's/^/  /'
    echo ""
else
    echo -e "${GREEN}✅ No warnings${NC}"
    echo ""
fi

# Generate summary report
echo -e "${BLUE}Generating summary report...${NC}"
SUMMARY=$(opa eval --data "$POLICY_FILE" --input "$CONFIG_FILE" \
    --format pretty 'data.firewall.security.summary' 2>/dev/null)

echo ""
echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}SUMMARY REPORT${NC}"
echo -e "${BLUE}====================================${NC}"
echo "$SUMMARY"
echo ""

# Exit with error if violations found
if [ "$VIOLATIONS" = true ]; then
    echo -e "${RED}====================================${NC}"
    echo -e "${RED}❌ VALIDATION FAILED${NC}"
    echo -e "${RED}Security violations must be fixed${NC}"
    echo -e "${RED}====================================${NC}"
    exit 1
else
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}✅ VALIDATION PASSED${NC}"
    if [ "$WARN_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $WARN_COUNT warning(s) found${NC}"
        echo -e "${YELLOW}Consider fixing warnings for best practices${NC}"
    else
        echo -e "${GREEN}No warnings${NC}"
    fi
    echo -e "${GREEN}====================================${NC}"
    exit 0
fi
