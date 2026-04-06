# Architecture Documentation

## Overview

This project demonstrates a production-like Terraform drift detection and auto-reconciliation pipeline for firewall management, using a mock Panorama API.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions (CI/CD)                     │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Triggers:                                            │   │
│  │  • manual (workflow_dispatch)                         │   │
│  │  • event-driven (repository_dispatch)                 │   │
│  │  • scheduled (cron - optional)                        │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Drift Detection Pipeline                     │
│                                                               │
│  1. Fetch current config from API                            │
│  2. Compare with desired state (Terraform)                   │
│  3. Detect drift (hash comparison)                           │
│  4. Validate policy (Policy as Code)                         │
│  5. Apply reconciliation (if drift detected)                 │
│  6. Verify final state                                       │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┴───────────────────┐
        ▼                                       ▼
┌──────────────────┐                  ┌──────────────────┐
│    Terraform     │                  │  Mock Panorama   │
│                  │                  │      API         │
│ • State mgmt     │◄────────────────►│                  │
│ • Drift detect   │   HTTP/REST      │ • Config store   │
│ • Config apply   │                  │ • Drift inject   │
└──────────────────┘                  │ • Hash tracking  │
                                      └──────────────────┘
```

## Components

### 1. Mock Panorama API (Node.js + TypeScript + Express)

**Purpose:** Simulate a real Panorama firewall API

**Technology Stack:**
- TypeScript (strict mode)
- Express.js (REST API)
- Winston (logging)
- Jest (testing)

**Key Features:**
- In-memory config storage (with file persistence)
- RESTful endpoints for CRUD operations
- Drift injection for testing
- Configuration hashing for drift detection
- Clean architecture (controllers → services → types)

**Endpoints:**
```
GET  /health               # Health check
GET  /config               # Fetch current config
POST /config               # Update config (used by Terraform)
POST /drift                # Inject drift (testing)
POST /reset                # Reset to default
```

### 2. Terraform Configuration

**Purpose:** Manage firewall configuration as Infrastructure as Code

**Key Resources:**
- `null_resource.panorama_config` - Main config management resource

**Drift Detection Mechanism:**
1. **Trigger**: Hash of desired configuration
2. **Fetch**: Current config from API via curl
3. **Compare**: MD5 hash of desired vs current policies
4. **Report**: Detailed diff if drift detected

**Provisioners:**
1. **local-exec #1**: Drift detection + comparison
2. **local-exec #2**: Policy validation
3. **local-exec #3**: Config push to API

**Why null_resource?**
- Flexible execution model
- No actual infrastructure to create
- Perfect for API integrations
- Trigger-based refresh logic

### 3. GitHub Actions Workflow

**Purpose:** Automated drift detection and reconciliation

**Trigger Types:**

1. **Manual (`workflow_dispatch`)**
   - Run from GitHub UI
   - On-demand drift checks

2. **Event-Driven (`repository_dispatch`)**
   - Triggered by external systems
   - Webhooks from monitoring tools
   - Example: `curl -X POST ... -d '{"event_type":"panorama-drift"}'`

3. **Scheduled (`cron`)** - Optional
   - Periodic checks every 30 min
   - Disabled by default to save CI minutes

**Pipeline Steps:**
1. Checkout code
2. Setup Node.js + Terraform
3. Build and start mock API
4. Terraform init
5. Terraform plan (drift detection)
6. Policy validation (if drift)
7. Terraform apply (if drift)
8. Verification
9. Summary report

### 4. Policy as Code Validation

**Purpose:** Prevent dangerous firewall configurations

**Validation Rules:**
- ❌ No blanket "deny all" rules (too restrictive)
- ✅ All rules must have names
- ✅ All rules must have valid actions (allow/deny/drop)
- ⚠️  Warning for overly permissive "any any any" allow rules

**Implementation:** Bash script with `jq` JSON processing

**Execution:** Before every Terraform apply

## Data Flow

### Normal Apply (No Drift)

```
Terraform                  API
    │                      │
    ├─ GET /config ───────►│
    │◄─ Hash: abc123 ──────┤
    │                      │
    ├─ Compare hashes      │
    │  (desired: abc123)   │
    │  (current: abc123)   │
    │                      │
    └─ ✅ No drift         │
       Skip apply          │
```

### Drift Detected

```
Terraform                  API
    │                      │
    ├─ GET /config ───────►│
    │◄─ Hash: xyz789 ──────┤  (drift!)
    │                      │
    ├─ Compare hashes      │
    │  (desired: abc123)   │
    │  (current: xyz789)   │
    │                      │
    ├─ ⚠️ DRIFT DETECTED   │
    │                      │
    ├─ Validate policy     │
    │  └─ ✅ Valid         │
    │                      │
    ├─ POST /config ──────►│
    │  (desired config)    │
    │◄─ Success ───────────┤
    │                      │
    ├─ Verify              │
    │◄─ Hash: abc123 ──────┤
    └─ ✅ Reconciled       │
```

## Security Considerations

### Authentication (Not Implemented - Demo Only)

In a production system, you would add:
- API key authentication
- OAuth2/JWT tokens
- mTLS for Terraform ↔ API communication
- GitHub Actions secrets for credentials

### Policy Validation

- Prevents accidental lockouts (deny all)
- Warns about security risks
- Can be extended with OPA (Open Policy Agent)

### Audit Trail

- All config changes logged
- Metadata tracks who/when/what
- API logs all operations with Winston

## Extending for Production

### 1. Real Panorama Integration

Replace mock API with:
```python
# Using pan-os-python library
from panos.firewall import Firewall
from panos.policies import SecurityRule

fw = Firewall('panorama.example.com', api_key='...')
# Fetch/update policies
```

### 2. State Backend

Add remote state:
```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "panorama/prod"
    region = "eu-west-1"
  }
}
```

### 3. Multi-Environment

```
terraform/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── modules/
    └── panorama/
```

### 4. Notifications

Add Slack/Teams notifications on drift:
```yaml
- name: Notify on Drift
  if: steps.drift.outputs.drift_detected == 'true'
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {"text": "⚠️ Firewall drift detected and reconciled!"}
```

### 5. Advanced Policy Validation

Use Open Policy Agent (OPA):
```rego
# policy.rego
deny[msg] {
  input.policies.security[_].action == "allow"
  input.policies.security[_].source[_] == "any"
  input.policies.security[_].destination[_] == "any"
  msg := "Overly permissive allow rule detected"
}
```

## Performance Considerations

### API Response Time

Current implementation:
- GET /config: ~10ms (in-memory)
- POST /config: ~20ms (write to file)

Production recommendations:
- Use Redis for config caching
- Implement rate limiting
- Add request timeouts

### Terraform Execution

- **Cold start:** ~5-10s (init + plan + apply)
- **Warm run:** ~2-3s (plan only, no drift)

Optimization strategies:
- Use `-target` for specific resources
- Implement partial drifts detection
- Parallelize API calls

### CI/CD Pipeline

- **Full run:** ~2-3 minutes
- **With cache:** ~1 minute

Speed improvements:
- Cache npm dependencies
- Use Terraform providers cache
- Parallel job execution

## Testing Strategy

### Unit Tests (Mock API)

- Service layer logic
- Configuration management
- Drift injection
- Hash generation

Coverage target: 70%+

### Integration Tests

- End-to-end workflow
- API + Terraform interaction
- Drift detection accuracy

### E2E Test (Automated)

Script: `scripts/e2e-test.sh`

Validates:
1. API startup
2. Baseline apply
3. Drift injection
4. Drift detection
5. Reconciliation
6. Final verification

## Monitoring & Observability

### Metrics to Track

- Drift detection frequency
- Reconciliation success rate
- API response times
- Policy validation failures

### Logging

- API: Winston (JSON format)
- Terraform: stdout/stderr capture
- GitHub Actions: job logs + summaries

### Alerting

Implement alerts for:
- Repeated drift detection (potential issue)
- Reconciliation failures
- Policy validation failures
- API downtime

## Scalability

### Current Limitations

- Single API instance
- File-based storage
- No horizontal scaling

### Production Scaling

- Load balancer + multiple API instances
- Database backend (PostgreSQL)
- Distributed state locking
- Multi-region deployments

## Disaster Recovery

### Backup Strategy

1. **Config Backups:** Automated snapshots before changes
2. **State Backups:** S3 versioning for Terraform state
3. **Rollback:** Previous version restore via Git

### Recovery Procedures

```bash
# Rollback to previous config
git checkout HEAD~1 terraform/desired-config.json
terraform apply -auto-approve

# Reset to default
curl -X POST http://localhost:3000/reset
terraform apply -auto-approve
```

## Compliance

### Audit Requirements

- All changes tracked in Git
- API logs retained for 90 days
- Approval workflow for prod changes

### Change Management

1. PR review required
2. Policy validation pass
3. Test environment validation
4. Approval from security team
5. Automated apply to prod

## Conclusion

This architecture provides a solid foundation for Infrastructure as Code firewall management with automated drift detection and reconciliation. It's designed to be:

- **Scalable:** Easy to extend for production
- **Testable:** Comprehensive test coverage
- **Maintainable:** Clean code separation
- **Secure:** Policy validation + audit trail
- **Automated:** CI/CD integrated
