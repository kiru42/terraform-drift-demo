# 🚀 Quick Start Guide

Get the drift detection demo running in **5 minutes**.

## Prerequisites

- Node.js 18+ (`node --version`)
- Terraform 1.0+ (`terraform version`)
- jq (`jq --version`)
- curl (`curl --version`)

## Step 1: Install Dependencies (1 min)

```bash
make install
```

Or manually:
```bash
cd mock-panorama
npm install
npm run build
cd ..
```

## Step 2: Start Mock API (30 seconds)

**Terminal 1:**
```bash
make start-api
```

Wait for:
```
🔥 Mock Panorama API listening on port 3000
```

## Step 3: Test Manually (2 minutes)

**Terminal 2:**

```bash
# Initialize Terraform
cd terraform
terraform init
terraform apply -auto-approve

# Inject drift
cd ..
./scripts/drift.sh

# Detect drift
cd terraform
terraform plan

# You should see: ⚠️ DRIFT DETECTED!

# Fix drift
terraform apply -auto-approve

# Verify
terraform plan
# You should see: No changes needed
```

## Step 4: Automated E2E Test (1 minute)

**Terminal 2:**
```bash
make e2e
```

Expected output:
```
===================================
END-TO-END DRIFT DETECTION TEST
===================================

Step 1: Starting Mock API...
✅ API started successfully

Step 2: Applying baseline configuration...
✅ Baseline applied

Step 3: Injecting drift...
✅ Drift injected successfully

Step 4: Detecting drift with Terraform...
✅ Drift detected by Terraform

Step 5: Reconciling configuration...
✅ Configuration reconciled successfully

Step 6: Verifying no drift after reconciliation...
✅ No drift detected after reconciliation

===================================
✅ ALL TESTS PASSED
===================================
```

## Common Issues

### Port 3000 already in use

```bash
# Find and kill the process
lsof -ti:3000 | xargs kill -9

# Or use a different port
PORT=3001 npm start
```

### jq not found

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# RHEL/CentOS
sudo yum install jq
```

### Terraform init fails

```bash
cd terraform
rm -rf .terraform .terraform.lock.hcl
terraform init
```

## What's Next?

1. **Explore the code**: Start with `mock-panorama/src/server.ts`
2. **Read the docs**: `docs/ARCHITECTURE.md` explains everything
3. **Customize**: Edit `terraform/desired-config.json` to add your own rules
4. **Test drift scenarios**: `./scripts/drift.sh modify` or `./scripts/drift.sh delete`
5. **Set up GitHub Actions**: Push to GitHub and enable the workflow

## Quick Commands Reference

```bash
# API Commands
curl http://localhost:3000/health           # Health check
curl http://localhost:3000/config           # Get config
./scripts/drift.sh add_rule                 # Inject drift
./scripts/drift.sh modify                   # Modify rule
./scripts/drift.sh delete                   # Delete rule

# Terraform Commands
cd terraform
terraform init                              # Initialize
terraform plan                              # Detect drift
terraform apply -auto-approve               # Apply changes
make drift                                  # Quick drift check

# Testing
make test-api                               # Unit tests
make e2e                                    # Full E2E test
./scripts/validate-policy.sh config.json   # Validate policy

# Cleanup
make clean                                  # Clean everything
curl -X POST http://localhost:3000/reset   # Reset API to default
```

## Success Criteria

You know it's working when:

1. ✅ API starts without errors
2. ✅ Terraform apply succeeds
3. ✅ Drift injection changes config hash
4. ✅ Terraform plan detects drift
5. ✅ Terraform apply reconciles drift
6. ✅ E2E test passes all 6 steps

## Need Help?

- Check the main [README.md](README.md)
- Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Review [docs/DRIFT-DETECTION.md](docs/DRIFT-DETECTION.md)
- Run tests with verbose output: `LOG_LEVEL=debug npm start`

Happy drift detecting! 🔥
