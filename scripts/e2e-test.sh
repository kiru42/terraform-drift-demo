#!/bin/bash
# End-to-end test of drift detection and reconciliation

set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

API_ENDPOINT="http://localhost:3000"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}==================================="
echo -e "END-TO-END DRIFT DETECTION TEST"
echo -e "===================================${NC}"
echo ""

# Cleanup function
cleanup() {
  echo ""
  echo -e "${YELLOW}Cleaning up...${NC}"
  if [ ! -z "$API_PID" ]; then
    kill $API_PID 2>/dev/null || true
    wait $API_PID 2>/dev/null || true
  fi
}

trap cleanup EXIT

# Step 1: Start Mock API
echo -e "${BLUE}Step 1: Starting Mock API...${NC}"
cd "$PROJECT_ROOT/mock-panorama"

if [ ! -d "node_modules" ]; then
  echo "Installing dependencies..."
  npm install --silent
fi

if [ ! -d "dist" ]; then
  echo "Building TypeScript..."
  npm run build --silent
fi

npm start > /tmp/panorama-api.log 2>&1 &
API_PID=$!

# Wait for API to be ready
echo "Waiting for API to start..."
for i in {1..30}; do
  if curl -s "${API_ENDPOINT}/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ API started successfully${NC}"
    break
  fi
  if [ $i -eq 30 ]; then
    echo -e "${RED}❌ API failed to start${NC}"
    cat /tmp/panorama-api.log
    exit 1
  fi
  sleep 1
done

echo ""

# Step 2: Reset and apply baseline
echo -e "${BLUE}Step 2: Applying baseline configuration...${NC}"
cd "$PROJECT_ROOT/terraform"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
  terraform init > /dev/null
fi

# Apply baseline
terraform apply -auto-approve

BASELINE_HASH=$(curl -s "${API_ENDPOINT}/config" | jq -r '.data.policies.security | tostring | @base64')

echo -e "${GREEN}✅ Baseline applied${NC}"
echo ""

# Step 3: Inject drift
echo -e "${BLUE}Step 3: Injecting drift...${NC}"
"${SCRIPT_DIR}/drift.sh" add_rule

DRIFTED_HASH=$(curl -s "${API_ENDPOINT}/config" | jq -r '.data.policies.security | tostring | @base64')

if [ "$BASELINE_HASH" = "$DRIFTED_HASH" ]; then
  echo -e "${RED}❌ Drift injection failed - hash unchanged${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Drift injected successfully${NC}"
echo ""

# Step 4: Detect drift with Terraform
echo -e "${BLUE}Step 4: Detecting drift with Terraform...${NC}"

set +e
terraform plan -detailed-exitcode > /tmp/terraform-plan.log 2>&1
PLAN_EXIT_CODE=$?
set -e

if [ $PLAN_EXIT_CODE -eq 0 ]; then
  echo -e "${RED}❌ No drift detected (expected drift!)${NC}"
  cat /tmp/terraform-plan.log
  exit 1
elif [ $PLAN_EXIT_CODE -eq 2 ]; then
  echo -e "${GREEN}✅ Drift detected by Terraform${NC}"
else
  echo -e "${RED}❌ Terraform plan failed with exit code $PLAN_EXIT_CODE${NC}"
  cat /tmp/terraform-plan.log
  exit 1
fi

echo ""

# Step 5: Reconcile configuration
echo -e "${BLUE}Step 5: Reconciling configuration...${NC}"
terraform apply -auto-approve

RECONCILED_HASH=$(curl -s "${API_ENDPOINT}/config" | jq -r '.data.policies.security | tostring | @base64')

if [ "$BASELINE_HASH" != "$RECONCILED_HASH" ]; then
  echo -e "${RED}❌ Reconciliation failed - hash doesn't match baseline${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Configuration reconciled successfully${NC}"
echo ""

# Step 6: Verify no drift
echo -e "${BLUE}Step 6: Verifying no drift after reconciliation...${NC}"

set +e
terraform plan -detailed-exitcode > /dev/null 2>&1
VERIFY_EXIT_CODE=$?
set -e

if [ $VERIFY_EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}✅ No drift detected after reconciliation${NC}"
elif [ $VERIFY_EXIT_CODE -eq 2 ]; then
  echo -e "${RED}❌ Drift still present after reconciliation${NC}"
  exit 1
else
  echo -e "${RED}❌ Terraform plan failed with exit code $VERIFY_EXIT_CODE${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}==================================="
echo -e "✅ ALL TESTS PASSED"
echo -e "===================================${NC}"
echo ""
echo "Summary:"
echo "  1. ✅ Mock API started successfully"
echo "  2. ✅ Baseline configuration applied"
echo "  3. ✅ Drift injected successfully"
echo "  4. ✅ Drift detected by Terraform"
echo "  5. ✅ Configuration reconciled"
echo "  6. ✅ No drift after reconciliation"
