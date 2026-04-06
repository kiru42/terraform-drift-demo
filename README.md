# Terraform Drift Detection Demo

Production-like demo project simulating drift detection and reconciliation for a firewall system (Panorama-like) using Terraform, GitHub Actions, and a mock API.

## 🏗️ Architecture

```
terraform-drift-demo/
├── mock-panorama/          # Fake firewall API (TypeScript + Express)
├── terraform/              # Terraform configuration
├── .github/workflows/      # GitHub Actions pipeline
├── scripts/                # Helper scripts
├── docs/                   # Documentation
└── README.md
```

## 🎯 Key Features

- **Drift Detection**: Automated detection via Terraform state comparison
- **Event-Driven CI/CD**: GitHub Actions triggered via `repository_dispatch`
- **Auto-Reconciliation**: Terraform apply on drift detection
- **Policy as Code**: Validation layer preventing dangerous policies
- **Full Mock Stack**: No external dependencies required

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- Terraform 1.0+
- Make (optional)
- GitHub CLI (for trigger script)

### 1. Install Dependencies

```bash
# Install mock API dependencies
cd mock-panorama
npm install
npm run build
```

### 2. Start Mock API

```bash
cd mock-panorama
npm start
```

The API will run on `http://localhost:3000`

### 3. Initialize Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Test Drift Detection

Terminal 1 - Keep API running:
```bash
cd mock-panorama && npm start
```

Terminal 2 - Inject drift and test:
```bash
# Inject drift (simulate manual firewall change)
./scripts/drift.sh

# Detect drift
cd terraform && terraform plan

# Fix drift
terraform apply -auto-approve
```

## 🧪 End-to-End Test

Run the complete automated test:

```bash
./scripts/e2e-test.sh
```

This will:
1. Start mock API
2. Apply baseline config
3. Inject drift
4. Detect drift
5. Reconcile automatically
6. Verify final state

## 🔔 GitHub Actions Integration

### Manual Trigger via GitHub UI

1. Go to Actions tab
2. Select "Panorama Drift Detection"
3. Click "Run workflow"

### Trigger via API (Programmatic)

```bash
# Set your GitHub token
export GITHUB_TOKEN="your_token_here"

# Trigger drift detection
./scripts/trigger.sh
```

### Automatic Triggers

- **Cron**: Every 30 minutes (optional, disabled by default)
- **repository_dispatch**: Via external systems

## 📋 API Endpoints

### Mock Panorama API

```bash
# Get current config
curl http://localhost:3000/config

# Update config (used by Terraform)
curl -X POST http://localhost:3000/config \
  -H "Content-Type: application/json" \
  -d @terraform/desired-config.json

# Inject drift (simulate manual change)
curl -X POST http://localhost:3000/drift \
  -H "Content-Type: application/json" \
  -d '{"rule": "allow_rogue_traffic", "action": "allow"}'
```

## 🛡️ Policy as Code Validation

Before every `terraform apply`, policies are validated:

- ❌ Block rules with `action: "deny"` (too permissive)
- ✅ Require explicit allow rules
- ✅ Validate source/destination networks

Validation runs in: `scripts/validate-policy.sh`

## 🧪 Testing

### Unit Tests (Mock API)

```bash
cd mock-panorama
npm test
npm run test:coverage
```

### Integration Tests

```bash
./scripts/test-integration.sh
```

## 📦 Project Structure

```
terraform-drift-demo/
│
├── mock-panorama/
│   ├── src/
│   │   ├── controllers/      # API controllers
│   │   ├── services/          # Business logic
│   │   ├── types/             # TypeScript types
│   │   └── server.ts          # Express app
│   ├── tests/                 # Jest unit tests
│   ├── package.json
│   └── tsconfig.json
│
├── terraform/
│   ├── main.tf                # Terraform config
│   ├── variables.tf
│   ├── desired-config.json    # Source of truth
│   └── Makefile
│
├── .github/workflows/
│   └── drift-detection.yml    # GitHub Actions pipeline
│
├── scripts/
│   ├── drift.sh               # Inject drift
│   ├── trigger.sh             # Trigger GitHub Action
│   ├── validate-policy.sh     # Policy validation
│   └── e2e-test.sh            # End-to-end test
│
└── docs/
    ├── ARCHITECTURE.md
    ├── DRIFT-DETECTION.md
    └── POLICY-VALIDATION.md
```

## 🔧 Configuration

### Terraform Variables

Edit `terraform/terraform.tfvars`:

```hcl
api_endpoint = "http://localhost:3000"
desired_config_file = "desired-config.json"
```

### Mock API Config

Edit `mock-panorama/src/config.ts`:

```typescript
export const config = {
  port: 3000,
  logLevel: 'info',
  persistenceFile: './data/config.json'
};
```

## 🐛 Troubleshooting

### API Not Starting

```bash
# Check port availability
lsof -i :3000

# Use different port
PORT=3001 npm start
```

### Terraform State Issues

```bash
# Reset state
cd terraform
rm -rf .terraform terraform.tfstate*
terraform init
```

### Drift Not Detected

```bash
# Force refresh
terraform apply -refresh-only

# Check API state
curl http://localhost:3000/config
```

## 🔥 Migrating to Real Palo Alto Panorama

### Why Use the Mock API?

The mock API is perfect for:
- ✅ **CI/CD testing** without infrastructure costs
- ✅ **Local development** and learning
- ✅ **Demonstrations** and training
- ✅ **No licensing required**

### When to Use Real Panorama

Migrate to real Panorama when you have:
- Production firewall management needs
- Access to Palo Alto VM-Series or appliances
- Valid Palo Alto licenses

### Option 1: Palo Alto VM-Series (Trial Available)

**Get VM-Series:**
1. Register at [Palo Alto Support Portal](https://support.paloaltonetworks.com/)
2. Download VM-Series trial (30 days free)
3. Deploy on VMware, AWS, Azure, or GCP
4. Minimum requirements: 4GB RAM, 2 vCPU

**Deploy VM-Series with Docker (unofficial):**
```bash
# Note: No official Docker image, but you can use EVE-NG or GNS3
# For quick testing, use pfSense as a close alternative:
docker run -d --name pfsense \
  -p 8443:443 \
  -p 8080:80 \
  --privileged \
  pfsense/pfsense
```

### Option 2: Use Official Palo Alto Terraform Provider

Replace the mock API calls with the official provider:

**1. Update `versions.tf`:**
```hcl
terraform {
  required_providers {
    panos = {
      source  = "PaloAltoNetworks/panos"
      version = "~> 1.11"
    }
  }
}

provider "panos" {
  hostname = var.panorama_hostname
  username = var.panorama_username
  password = var.panorama_password  # Use env var or Key Vault
  
  # Or use API key
  api_key = var.panorama_api_key
}
```

**2. Create variables:**
```hcl
variable "panorama_hostname" {
  description = "Panorama hostname or IP"
  type        = string
}

variable "panorama_username" {
  description = "Panorama admin username"
  type        = string
  sensitive   = true
}

variable "panorama_password" {
  description = "Panorama admin password"
  type        = string
  sensitive   = true
}
```

**3. Replace null_resource with panos resources:**

Instead of:
```hcl
resource "null_resource" "panorama_config" {
  # Mock API calls
}
```

Use:
```hcl
# Security policy rules
resource "panos_security_rule_group" "rules" {
  position_keyword = "top"
  
  rule {
    name                  = "allow_internal_web"
    source_zones          = ["trust"]
    source_addresses      = ["10.0.0.0/8"]
    destination_zones     = ["untrust"]
    destination_addresses = ["any"]
    applications          = ["web-browsing", "ssl"]
    services              = ["application-default"]
    action                = "allow"
  }
}

# Address objects
resource "panos_address_object" "internal_network" {
  name        = "internal-network"
  value       = "10.0.0.0/8"
  description = "Internal network range"
}
```

**4. Example complete migration:**

```hcl
# panorama-integration/main.tf
terraform {
  required_providers {
    panos = {
      source  = "PaloAltoNetworks/panos"
      version = "~> 1.11"
    }
  }
}

provider "panos" {
  hostname = "panorama.company.com"
  api_key  = var.panorama_api_key
}

# Commit configuration
resource "panos_commit" "commit" {
  description = "Terraform automated commit"
  
  depends_on = [
    panos_security_rule_group.rules
  ]
}
```

### Option 3: Hybrid Approach (Recommended)

Keep both mock and real firewall support:

```hcl
variable "use_real_firewall" {
  description = "Use real Panorama instead of mock"
  type        = bool
  default     = false
}

locals {
  api_endpoint = var.use_real_firewall ? var.panorama_api_url : "http://localhost:3000"
}
```

### Testing with Real Panorama

**Prerequisites:**
```bash
# Set credentials
export TF_VAR_panorama_hostname="panorama.lab.local"
export TF_VAR_panorama_username="admin"
export TF_VAR_panorama_password="your-secure-password"

# Or use API key (recommended)
export TF_VAR_panorama_api_key="LUFRPT14MW5xOEo..."
```

**Test connection:**
```bash
# Using panos provider
terraform init
terraform plan
```

### Palo Alto Provider Resources

The official provider supports:
- ✅ Security policies
- ✅ NAT policies  
- ✅ Address/service objects
- ✅ Zones and interfaces
- ✅ Device groups (Panorama)
- ✅ Templates (Panorama)
- ✅ Commit operations

**Documentation:**
- [PaloAltoNetworks/panos Provider](https://registry.terraform.io/providers/PaloAltoNetworks/panos/latest/docs)
- [Palo Alto API Documentation](https://docs.paloaltonetworks.com/pan-os/10-2/pan-os-panorama-api)

### Alternative: pfSense (Open Source)

For testing Terraform firewall automation without Palo Alto licenses:

```bash
# Deploy pfSense
docker run -d --name pfsense \
  -p 8443:443 \
  --privileged \
  pfsense/pfsense

# Access: https://localhost:8443
# Default: admin/pfsense
```

**pfSense Terraform Provider:**
```hcl
provider "pfsense" {
  url      = "https://localhost:8443"
  username = "admin"
  password = "pfsense"
  insecure = true  # For self-signed cert
}
```

### Cost Comparison

| Option | Cost | Best For |
|--------|------|----------|
| **Mock API** | Free | CI/CD, learning, demos |
| **VM-Series Trial** | Free (30 days) | Testing real integration |
| **VM-Series License** | $1,000+/year | Production (small) |
| **Panorama** | $10,000+/year | Enterprise management |
| **pfSense** | Free | Open-source alternative |

### Migration Checklist

- [ ] Obtain Palo Alto VM-Series or trial
- [ ] Install and configure Panorama/firewall
- [ ] Generate API key
- [ ] Update Terraform provider to `panos`
- [ ] Refactor resources from null_resource to panos_*
- [ ] Test in non-production first
- [ ] Update CI/CD credentials
- [ ] Document custom configuration
- [ ] Train team on real API differences

### Support Resources

- **Palo Alto Live Community**: https://live.paloaltonetworks.com/
- **Terraform Provider Issues**: https://github.com/PaloAltoNetworks/terraform-provider-panos
- **VM-Series Deployment Guides**: https://docs.paloaltonetworks.com/vm-series

## 📚 Learn More

- [Architecture Details](docs/ARCHITECTURE.md)
- [Drift Detection Explained](docs/DRIFT-DETECTION.md)
- [Policy Validation Guide](docs/POLICY-VALIDATION.md)

## 🤝 Contributing

This is a demo project. Feel free to fork and extend with:

- Real Panorama API integration
- Multi-environment support
- Slack/Teams notifications
- Advanced policy validation (OPA)
- Drift history tracking

## 📄 License

MIT
