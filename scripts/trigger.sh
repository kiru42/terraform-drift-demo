#!/bin/bash
# Trigger GitHub Actions drift detection workflow

set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
REPO_OWNER="${REPO_OWNER:-your-username}"
REPO_NAME="${REPO_NAME:-terraform-drift-demo}"

echo -e "${YELLOW}==================================="
echo -e "TRIGGER DRIFT DETECTION WORKFLOW"
echo -e "===================================${NC}"
echo ""

# Check if GitHub token is set
if [ -z "$GITHUB_TOKEN" ]; then
  echo -e "${RED}❌ GITHUB_TOKEN environment variable not set${NC}"
  echo ""
  echo "Create a personal access token at:"
  echo "https://github.com/settings/tokens"
  echo ""
  echo "Then export it:"
  echo "export GITHUB_TOKEN='your_token_here'"
  exit 1
fi

# Check if gh CLI is available
if command -v gh &> /dev/null; then
  echo "Using GitHub CLI..."
  gh workflow run drift-detection.yml \
    --repo "${REPO_OWNER}/${REPO_NAME}"
  
  echo -e "${GREEN}✅ Workflow triggered successfully via gh CLI${NC}"
else
  # Use curl with GitHub API
  echo "Using GitHub API..."
  
  RESPONSE=$(curl -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/dispatches" \
    -d '{"event_type":"panorama-drift"}' \
    -s -w "\n%{http_code}")
  
  HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
  
  if [ "$HTTP_CODE" = "204" ]; then
    echo -e "${GREEN}✅ Workflow triggered successfully via API${NC}"
  else
    echo -e "${RED}❌ Failed to trigger workflow (HTTP $HTTP_CODE)${NC}"
    echo "$RESPONSE"
    exit 1
  fi
fi

echo ""
echo "View workflow runs at:"
echo "https://github.com/${REPO_OWNER}/${REPO_NAME}/actions"
