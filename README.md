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
