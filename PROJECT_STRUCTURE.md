# Project Structure

Complete overview of the terraform-drift-demo project organization.

## Directory Tree

```
terraform-drift-demo/
│
├── README.md                    # Main documentation
├── QUICKSTART.md                # 5-minute quick start guide
├── PROJECT_STRUCTURE.md         # This file
├── Makefile                     # Global build/test commands
├── .gitignore                   # Git ignore rules
│
├── mock-panorama/               # Mock Panorama Firewall API
│   ├── package.json             # Node.js dependencies & scripts
│   ├── tsconfig.json            # TypeScript configuration
│   ├── jest.config.js           # Jest test configuration
│   ├── .eslintrc.js             # ESLint rules
│   │
│   ├── src/                     # TypeScript source code
│   │   ├── server.ts            # Express app entry point
│   │   ├── controllers/         # API controllers
│   │   │   └── configController.ts
│   │   ├── services/            # Business logic
│   │   │   └── configService.ts
│   │   ├── types/               # TypeScript type definitions
│   │   │   └── config.ts
│   │   └── utils/               # Utility functions
│   │       └── logger.ts
│   │
│   ├── tests/                   # Unit tests
│   │   └── configService.test.ts
│   │
│   ├── data/                    # Runtime data storage
│   │   ├── .gitkeep
│   │   └── config.json          # Generated at runtime
│   │
│   └── dist/                    # Compiled JavaScript (generated)
│
├── terraform/                   # Terraform configuration
│   ├── main.tf                  # Main Terraform config
│   ├── desired-config.json      # Source of truth for firewall config
│   ├── Makefile                 # Terraform shortcuts
│   └── .terraform/              # Terraform state (generated)
│
├── .github/                     # GitHub Actions
│   └── workflows/
│       └── drift-detection.yml  # CI/CD pipeline
│
├── scripts/                     # Helper scripts
│   ├── drift.sh                 # Inject drift for testing
│   ├── validate-policy.sh       # Policy validation
│   ├── trigger.sh               # Trigger GitHub Action
│   ├── e2e-test.sh              # End-to-end test
│   └── test-integration.sh      # Integration tests
│
└── docs/                        # Documentation
    ├── ARCHITECTURE.md          # Architecture deep dive
    ├── DRIFT-DETECTION.md       # Drift detection explained
    └── POLICY-VALIDATION.md     # Policy validation guide
```

## File Descriptions

### Root Level

| File | Purpose |
|------|---------|
| `README.md` | Main documentation with setup instructions |
| `QUICKSTART.md` | 5-minute quick start for impatient users |
| `PROJECT_STRUCTURE.md` | This file - project organization reference |
| `Makefile` | Build automation and shortcuts |
| `.gitignore` | Files to exclude from version control |

### mock-panorama/

Node.js + TypeScript application simulating a Panorama firewall API.

#### Configuration Files

| File | Purpose |
|------|---------|
| `package.json` | NPM dependencies, scripts, and metadata |
| `tsconfig.json` | TypeScript compiler options |
| `jest.config.js` | Jest unit testing configuration |
| `.eslintrc.js` | ESLint code quality rules |

#### Source Code (`src/`)

| File/Directory | Purpose |
|----------------|---------|
| `server.ts` | Express app entry point, middleware setup |
| `controllers/configController.ts` | HTTP request handlers |
| `services/configService.ts` | Business logic, config management |
| `types/config.ts` | TypeScript interfaces |
| `utils/logger.ts` | Winston logger configuration |

**Architecture Pattern:** MVC (Model-View-Controller)
- Controllers: HTTP layer
- Services: Business logic
- Types: Data models

#### Tests (`tests/`)

| File | Coverage |
|------|----------|
| `configService.test.ts` | Unit tests for config service |

**Test Framework:** Jest with ts-jest

#### Data (`data/`)

| File | Purpose |
|------|---------|
| `config.json` | Runtime firewall configuration (generated) |
| `.gitkeep` | Preserve directory in Git |

### terraform/

Infrastructure as Code for firewall configuration management.

| File | Purpose |
|------|---------|
| `main.tf` | Terraform resources, drift detection logic |
| `desired-config.json` | Source of truth for firewall policies |
| `Makefile` | Terraform command shortcuts |

**Key Resources:**
- `null_resource.panorama_config`: Config management with local-exec provisioners

**Drift Detection:**
- Hash-based comparison
- Detailed diff output
- Automatic reconciliation

### .github/workflows/

GitHub Actions CI/CD automation.

| File | Purpose |
|------|---------|
| `drift-detection.yml` | Automated drift detection pipeline |

**Triggers:**
- Manual (`workflow_dispatch`)
- Event-driven (`repository_dispatch`)
- Scheduled (`cron` - optional)

**Steps:**
1. Checkout code
2. Setup Node.js + Terraform
3. Build and start mock API
4. Detect drift
5. Validate policy
6. Reconcile if needed
7. Generate summary

### scripts/

Bash scripts for operations and testing.

| Script | Purpose | Usage |
|--------|---------|-------|
| `drift.sh` | Inject configuration drift | `./scripts/drift.sh [add_rule\|modify\|delete]` |
| `validate-policy.sh` | Validate firewall policies | `./scripts/validate-policy.sh config.json` |
| `trigger.sh` | Trigger GitHub Actions | `./scripts/trigger.sh` (requires `GITHUB_TOKEN`) |
| `e2e-test.sh` | End-to-end automated test | `./scripts/e2e-test.sh` |
| `test-integration.sh` | Integration tests | `./scripts/test-integration.sh` |

**All scripts:**
- Use bash strict mode (`set -e`)
- Colored output for readability
- Detailed error messages

### docs/

Comprehensive documentation.

| File | Content |
|------|---------|
| `ARCHITECTURE.md` | System architecture, data flow, components |
| `DRIFT-DETECTION.md` | Drift detection theory and practice |
| `POLICY-VALIDATION.md` | Policy as Code validation guide |

## Build Artifacts (Generated)

These directories/files are created during build/runtime:

```
mock-panorama/
├── node_modules/        # NPM dependencies
├── dist/                # Compiled TypeScript
├── coverage/            # Test coverage reports
└── data/config.json     # Runtime config storage

terraform/
├── .terraform/          # Terraform providers
├── .terraform.lock.hcl  # Provider version lock
├── terraform.tfstate    # Terraform state
└── terraform.tfstate.backup  # State backup
```

**All excluded from Git via `.gitignore`**

## Dependencies

### Mock API

```json
{
  "dependencies": {
    "express": "^4.18.2",     // Web framework
    "cors": "^2.8.5",         // CORS middleware
    "morgan": "^1.10.0",      // HTTP logger
    "winston": "^3.11.0"      // Application logger
  },
  "devDependencies": {
    "@types/*": "*",          // TypeScript type definitions
    "typescript": "^5.3.3",   // TypeScript compiler
    "jest": "^29.7.0",        // Testing framework
    "ts-jest": "^29.1.1",     // TypeScript Jest support
    "supertest": "^6.3.3",    // HTTP testing
    "eslint": "^8.56.0"       // Linter
  }
}
```

### Terraform

```hcl
required_providers {
  null = {
    source  = "hashicorp/null"
    version = "~> 3.2"
  }
}
```

### Scripts

- `bash` (POSIX-compliant)
- `jq` (JSON processor)
- `curl` (HTTP client)
- `md5sum` (hashing)

## Code Quality Standards

### TypeScript

- **Strict mode enabled**
- **No `any` types** (except where absolutely necessary)
- **Explicit return types** for public functions
- **Consistent naming:**
  - camelCase for variables/functions
  - PascalCase for types/interfaces
  - UPPER_CASE for constants

### Testing

- **Unit test coverage:** 70% minimum
- **Integration tests:** All critical paths
- **E2E test:** Complete workflow validation

### Documentation

- **Every major component** has inline comments
- **README.md** for each subsystem
- **Markdown** for all docs (no PDFs/Word)

### Git Workflow

```
main (protected)
  ↑
feature/drift-detection-logic
  ↑
feature/policy-validation
```

**Commit messages:**
```
feat: add drift detection hash comparison
fix: handle null config in API
docs: update ARCHITECTURE.md
test: add integration tests
```

## Scalability Roadmap

### Phase 1: Current (Demo)

- Single mock API instance
- File-based config storage
- Local Terraform state
- Manual testing

### Phase 2: Production-Ready

- Load balancer + multiple API instances
- PostgreSQL database backend
- S3 remote state backend
- Automated E2E tests in CI

### Phase 3: Enterprise

- Multi-region deployment
- Real Panorama API integration
- Audit trail + compliance reporting
- Advanced policy validation (OPA)
- Slack/Teams notifications

## Contributing

### Adding a New Feature

1. Create feature branch from `main`
2. Add tests first (TDD)
3. Implement feature
4. Update documentation
5. Run full test suite
6. Create PR with detailed description

### Project Commands

```bash
# Development
make install          # Install dependencies
make build            # Build TypeScript
make start-api        # Start development server

# Testing
make test-api         # Run unit tests
make test             # Run all tests
make e2e              # End-to-end test
./scripts/test-integration.sh  # Integration tests

# Cleanup
make clean            # Remove build artifacts
```

## License

MIT License - See LICENSE file for details

## Authors

DevOps Team

## Version History

- **v1.0.0** (2024-01-15): Initial release
  - Mock Panorama API
  - Terraform drift detection
  - GitHub Actions integration
  - Policy validation
  - Complete documentation

## Support

For questions or issues:
- Check documentation in `docs/`
- Review QUICKSTART.md
- Run integration tests
- Check GitHub Actions logs

---

**Last Updated:** 2024-01-15
**Project Status:** ✅ Production-Ready Demo
