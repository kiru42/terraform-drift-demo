# Quick Commands Reference

## 🚀 Getting Started

```bash
# Clone/navigate to project
cd terraform-drift-demo

# Install dependencies
make install

# Build TypeScript
make build

# Start Mock API (Terminal 1)
make start-api

# Run E2E test (Terminal 2)
make e2e
```

## 📦 Mock API Commands

```bash
# Development
cd mock-panorama
npm install                     # Install dependencies
npm run build                   # Build TypeScript
npm start                       # Start production server
npm run dev                     # Start dev server (auto-reload)

# Testing
npm test                        # Run unit tests
npm run test:watch              # Watch mode
npm run test:coverage           # Coverage report

# Quality
npm run lint                    # Run ESLint
npm run clean                   # Clean build artifacts

# Logs
LOG_LEVEL=debug npm start       # Debug logging
LOG_LEVEL=error npm start       # Error only
```

## 🔧 API Testing

```bash
# Health check
curl http://localhost:3000/health

# Get config
curl http://localhost:3000/config

# Get config (pretty)
curl -s http://localhost:3000/config | jq '.'

# Update config
curl -X POST http://localhost:3000/config \
  -H "Content-Type: application/json" \
  -d @terraform/desired-config.json

# Inject drift (add rule)
curl -X POST http://localhost:3000/drift \
  -H "Content-Type: application/json" \
  -d '{"rule": {"name": "test", "source": ["any"], "destination": ["any"], "service": ["any"], "action": "allow", "enabled": true}}'

# Inject drift (modify first rule)
curl -X POST http://localhost:3000/drift \
  -H "Content-Type: application/json" \
  -d '{"action": "modify_first"}'

# Inject drift (delete last rule)
curl -X POST http://localhost:3000/drift \
  -H "Content-Type: application/json" \
  -d '{"action": "delete_last"}'

# Reset to default
curl -X POST http://localhost:3000/reset

# Check config hash
curl -s http://localhost:3000/config | jq -r '.message'
```

## 🌍 Terraform Commands

```bash
cd terraform

# Initialize
terraform init

# Validate syntax
terraform validate

# Format code
terraform fmt

# Plan (detect drift)
terraform plan

# Plan (detailed exit code)
terraform plan -detailed-exitcode
# Exit code 0 = no changes
# Exit code 2 = changes needed (drift detected)

# Apply changes
terraform apply

# Apply without confirmation
terraform apply -auto-approve

# Destroy resources
terraform destroy

# Show current state
terraform show

# Refresh state without apply
terraform apply -refresh-only

# View outputs
terraform output

# Using Makefile
make init                       # terraform init
make plan                       # terraform plan -detailed-exitcode
make apply                      # terraform apply -auto-approve
make destroy                    # terraform destroy -auto-approve
make clean                      # Clean .terraform/
make drift                      # Quick drift check
make fmt                        # terraform fmt
make refresh                    # Refresh state
```

## 📜 Scripts

```bash
# Inject drift
./scripts/drift.sh              # Add rogue rule (default)
./scripts/drift.sh add_rule     # Add rogue rule
./scripts/drift.sh modify       # Modify first rule
./scripts/drift.sh delete       # Delete last rule

# Validate policy
./scripts/validate-policy.sh terraform/desired-config.json

# Trigger GitHub Action (requires GITHUB_TOKEN)
export GITHUB_TOKEN="your_token"
export REPO_OWNER="your-username"
export REPO_NAME="terraform-drift-demo"
./scripts/trigger.sh

# End-to-end test
./scripts/e2e-test.sh

# Integration tests
./scripts/test-integration.sh
```

## 🧪 Testing

```bash
# Unit tests (API)
cd mock-panorama
npm test                        # Run once
npm run test:watch              # Watch mode
npm run test:coverage           # With coverage

# Integration tests
./scripts/test-integration.sh   # 7 integration tests

# E2E test
./scripts/e2e-test.sh          # Full workflow
make e2e                        # Same via Makefile

# All tests
make test                       # Unit + validation
```

## 🔍 Debugging

```bash
# Verbose logging
LOG_LEVEL=debug npm start

# Check if API is running
curl http://localhost:3000/health
lsof -i :3000

# Check Terraform state
cd terraform
terraform show
cat terraform.tfstate | jq '.'

# View API config file
cat mock-panorama/data/config.json | jq '.'

# Check for drift manually
DESIRED=$(cat terraform/desired-config.json | jq -r '.policies' | md5sum)
CURRENT=$(curl -s http://localhost:3000/config | jq -r '.data.policies' | md5sum)
echo "Desired: $DESIRED"
echo "Current: $CURRENT"

# GitHub Actions logs
gh run list --workflow drift-detection.yml
gh run view <run-id>
```

## 🧹 Cleanup

```bash
# Clean mock API
cd mock-panorama
rm -rf node_modules dist coverage
npm install && npm run build

# Clean Terraform
cd terraform
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
terraform init

# Clean everything
make clean

# Reset API config
curl -X POST http://localhost:3000/reset

# Kill API process
lsof -ti:3000 | xargs kill -9
```

## 🔄 Typical Workflow

### 1. First Time Setup

```bash
make install
make build
```

### 2. Start Development

```bash
# Terminal 1: API
cd mock-panorama
npm run dev

# Terminal 2: Terraform
cd terraform
terraform init
```

### 3. Test Drift Detection

```bash
# Apply baseline
cd terraform
terraform apply -auto-approve

# Inject drift
./scripts/drift.sh

# Detect drift
terraform plan

# Fix drift
terraform apply -auto-approve

# Verify
terraform plan  # Should show no changes
```

### 4. Run Full Test Suite

```bash
# Run E2E test
make e2e

# Or manually:
# Terminal 1
make start-api

# Terminal 2
./scripts/test-integration.sh
./scripts/e2e-test.sh
```

## 📊 Monitoring

```bash
# Check API health continuously
watch -n 5 'curl -s http://localhost:3000/health | jq .'

# Monitor config hash
watch -n 10 'curl -s http://localhost:3000/config | jq -r ".message"'

# Monitor Terraform drift
watch -n 60 'cd terraform && terraform plan -detailed-exitcode || echo "DRIFT DETECTED"'

# View logs
cd mock-panorama
npm start | tee api.log

# View logs (follow)
tail -f api.log
```

## 🐛 Troubleshooting

```bash
# API won't start
lsof -ti:3000 | xargs kill -9  # Kill existing process
rm -rf node_modules             # Clean deps
npm install                     # Reinstall
npm run build                   # Rebuild
npm start                       # Start again

# Terraform errors
cd terraform
rm -rf .terraform*              # Clean state
terraform init                  # Reinit

# Tests failing
cd mock-panorama
npm test -- --clearCache        # Clear Jest cache
npm test -- --verbose           # Verbose output

# jq not found
brew install jq                 # macOS
sudo apt-get install jq         # Ubuntu
sudo yum install jq             # RHEL

# Permission denied on scripts
chmod +x scripts/*.sh           # Make executable
```

## 🚀 GitHub Actions

```bash
# Manual trigger via gh CLI
gh workflow run drift-detection.yml

# View recent runs
gh run list --workflow drift-detection.yml

# View specific run
gh run view <run-id> --log

# Cancel run
gh run cancel <run-id>

# Rerun failed run
gh run rerun <run-id>

# Via API (requires token)
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$OWNER/$REPO/dispatches \
  -d '{"event_type":"panorama-drift"}'
```

## 📝 Configuration Changes

```bash
# Edit desired config
vim terraform/desired-config.json

# Validate changes
./scripts/validate-policy.sh terraform/desired-config.json

# Apply changes
cd terraform
terraform apply

# Or use custom config file
terraform apply -var desired_config_file="../custom-config.json"
```

## 🔐 Environment Variables

```bash
# Mock API
export PORT=3000                # Server port
export LOG_LEVEL=info           # Log level
export NODE_ENV=production      # Environment

# GitHub Actions
export GITHUB_TOKEN="..."       # Personal access token
export REPO_OWNER="username"    # GitHub username/org
export REPO_NAME="repo-name"    # Repository name

# Terraform
export TF_LOG=DEBUG             # Terraform verbose logging
export TF_LOG_PATH=tf.log       # Log to file
```

## 📦 Package Management

```bash
# Update dependencies
cd mock-panorama
npm update

# Check for outdated packages
npm outdated

# Security audit
npm audit
npm audit fix

# Install specific version
npm install express@4.18.2
```

## 🎯 Quick Checks

```bash
# Is everything installed?
node --version && terraform version && jq --version

# Is API running?
curl -f http://localhost:3000/health || echo "API DOWN"

# Is drift present?
cd terraform && terraform plan -detailed-exitcode && echo "NO DRIFT" || echo "DRIFT DETECTED"

# Are tests passing?
cd mock-panorama && npm test && echo "TESTS PASS"

# Is policy valid?
./scripts/validate-policy.sh terraform/desired-config.json && echo "VALID"
```

## 💡 Tips & Tricks

```bash
# Run API in background
cd mock-panorama && npm start > /tmp/api.log 2>&1 &
API_PID=$!

# Stop API later
kill $API_PID

# Pretty print JSON
curl -s http://localhost:3000/config | jq '.' | less

# Compare configs
diff <(curl -s http://localhost:3000/config | jq -S '.data.policies') \
     <(cat terraform/desired-config.json | jq -S '.policies')

# Count rules
curl -s http://localhost:3000/config | jq '.data.policies.security | length'

# Extract rule names
curl -s http://localhost:3000/config | jq -r '.data.policies.security[].name'

# Check port usage
netstat -an | grep :3000

# Watch for file changes (macOS)
fswatch -o mock-panorama/src | xargs -n1 -I{} npm run build

# Create alias for common commands
alias api-start='cd mock-panorama && npm start'
alias api-test='cd mock-panorama && npm test'
alias tf-plan='cd terraform && terraform plan'
alias tf-apply='cd terraform && terraform apply -auto-approve'
```

## 📚 Help Commands

```bash
# Global help
make help

# Script help
./scripts/drift.sh --help
./scripts/validate-policy.sh --help

# Terraform help
terraform -help
terraform plan -help
terraform apply -help

# npm scripts
cd mock-panorama
npm run  # Shows all available scripts
```

---

**Bookmark this file for quick reference!** 📌
