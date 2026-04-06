# Drift Detection Explained

## What is Configuration Drift?

Configuration drift occurs when the actual state of infrastructure diverges from the desired state defined in code.

### Example Scenarios

**Scenario 1: Manual Change**
```
Desired State (Terraform):
  Rule: allow_web → source: 10.0.0.0/8

Actual State (Firewall):
  Rule: allow_web → source: any  ← Manual change by admin
  
Result: DRIFT DETECTED
```

**Scenario 2: Unauthorized Rule**
```
Desired State (Terraform):
  2 rules total

Actual State (Firewall):
  3 rules (someone added "allow_all")
  
Result: DRIFT DETECTED
```

## Why Drift Detection Matters

### Security Risks

- **Unauthorized access:** Manual changes may open security holes
- **Compliance violations:** Config may no longer meet audit requirements
- **Attack surface:** Extra rules increase potential vulnerabilities

### Operational Risks

- **Inconsistency:** Different environments diverge over time
- **Unpredictability:** Unknown config leads to unexpected behavior
- **Rollback difficulty:** Hard to revert without baseline

### Business Impact

- **Downtime:** Unexpected config can break applications
- **Audit failures:** Non-compliance penalties
- **Support overhead:** Troubleshooting unknown config

## How This Demo Detects Drift

### 1. Hash-Based Comparison

#### Step 1: Calculate Desired Hash

```bash
# From Terraform desired-config.json
DESIRED=$(cat desired-config.json | jq -r '.policies')
DESIRED_HASH=$(echo "$DESIRED" | md5sum)
# Output: abc123...
```

#### Step 2: Fetch Current Hash

```bash
# From API
CURRENT=$(curl http://localhost:3000/config | jq -r '.data.policies')
CURRENT_HASH=$(echo "$CURRENT" | md5sum)
# Output: xyz789...  (if drift)
```

#### Step 3: Compare

```bash
if [ "$DESIRED_HASH" != "$CURRENT_HASH" ]; then
  echo "DRIFT DETECTED"
fi
```

### 2. Terraform Triggers

Terraform uses `triggers` to force resource recreation when config changes:

```hcl
resource "null_resource" "panorama_config" {
  triggers = {
    config_hash = md5(jsonencode(local.desired_config))
    always_run  = timestamp()  # Force check on every run
  }
  
  # Provisioners run when triggers change
  provisioner "local-exec" {
    command = "detect_drift.sh"
  }
}
```

### 3. Detailed Diff

When drift is detected, show exactly what changed:

```bash
diff <(echo "$DESIRED" | jq '.') <(echo "$CURRENT" | jq '.')

# Output:
> {
>   "name": "rogue_rule",  ← This rule shouldn't exist
>   "action": "allow",
>   "source": ["any"]
> }
```

## Detection Methods Comparison

### Method 1: Hash Comparison (This Demo)

**Pros:**
- ✅ Fast (O(1) comparison)
- ✅ Works with any config format
- ✅ Low API overhead

**Cons:**
- ❌ Doesn't show what changed
- ❌ Hash collision risk (minimal with MD5)

**Best for:** Quick drift checks, automated workflows

### Method 2: Field-by-Field Comparison

**Pros:**
- ✅ Precise change identification
- ✅ Can generate detailed reports

**Cons:**
- ❌ Slower (O(n) for n fields)
- ❌ Complex logic for nested structures

**Best for:** Manual audits, compliance reporting

### Method 3: Event-Driven Detection

**Pros:**
- ✅ Real-time drift notification
- ✅ No polling needed

**Cons:**
- ❌ Requires webhook infrastructure
- ❌ Depends on API event support

**Best for:** Production environments with webhooks

## Demo Workflow

### 1. Baseline State

```bash
cd terraform
terraform apply
```

Result:
```
✅ Configuration applied
   Policies: 2 rules
   Hash: abc123
```

### 2. Inject Drift

```bash
./scripts/drift.sh add_rule
```

Result:
```
⚠️ Drift injected
   Added rule: "rogue_allow_all"
   New hash: xyz789
```

### 3. Detect Drift

```bash
cd terraform
terraform plan
```

Result:
```
⚠️ DRIFT DETECTED!
   Desired hash: abc123
   Current hash: xyz789
   
Differences:
+ Rule "rogue_allow_all" (not in desired state)
```

### 4. Reconcile

```bash
terraform apply -auto-approve
```

Result:
```
✅ Configuration reconciled
   Removed: "rogue_allow_all"
   Hash: abc123 (matches desired)
```

## Advanced Detection Techniques

### 1. Selective Drift Checking

Only check specific attributes:

```hcl
locals {
  # Only hash security-critical fields
  drift_signature = md5(jsonencode({
    rules   = local.desired_config.policies.security
    version = local.desired_config.version
  }))
}
```

### 2. Drift Tolerance

Allow minor drifts (e.g., description changes):

```hcl
locals {
  # Strip non-critical fields before hashing
  critical_config = [
    for rule in local.desired_config.policies.security : {
      name        = rule.name
      action      = rule.action
      source      = rule.source
      destination = rule.destination
      # description ignored
    }
  ]
}
```

### 3. Scheduled vs On-Demand

**Scheduled (Cron):**
```yaml
schedule:
  - cron: '0 */4 * * *'  # Every 4 hours
```

**Event-Driven:**
```yaml
on:
  repository_dispatch:
    types: [firewall-change-detected]
```

**Hybrid:**
```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # Nightly full scan
  repository_dispatch:
    types: [critical-drift]  # Immediate for critical
```

## Drift Remediation Strategies

### Strategy 1: Auto-Remediate (This Demo)

```yaml
- name: Detect Drift
  run: terraform plan -detailed-exitcode
  
- name: Auto-Fix
  if: steps.detect.outputs.drift == 'true'
  run: terraform apply -auto-approve
```

**Pros:** Fully automated, fast recovery
**Cons:** May override intentional changes
**Use case:** Dev/test environments

### Strategy 2: Alert + Manual Approval

```yaml
- name: Detect Drift
  run: terraform plan -detailed-exitcode
  
- name: Notify Team
  if: steps.detect.outputs.drift == 'true'
  run: slack-notify "Drift detected! Approve via /approve"
  
- name: Wait for Approval
  uses: trstringer/manual-approval@v1
  
- name: Fix Drift
  run: terraform apply -auto-approve
```

**Pros:** Human oversight, safer
**Cons:** Slower, requires on-call
**Use case:** Production environments

### Strategy 3: Document + Review

```yaml
- name: Detect Drift
  run: terraform plan -detailed-exitcode
  
- name: Generate Report
  run: |
    terraform show -json > drift-report.json
    generate-diff-report.sh
  
- name: Create Issue
  uses: actions/create-issue@v1
  with:
    title: "Drift Detected - Review Required"
    body-path: drift-report.md
```

**Pros:** Full audit trail, collaborative
**Cons:** Slowest response
**Use case:** Compliance-heavy orgs

## Real-World Examples

### Example 1: Emergency Firewall Rule

**Scenario:** At 3 AM, NOC adds emergency rule to block attack

**Without Drift Detection:**
- Rule stays forever
- May conflict with future changes
- Forgotten in 6 months

**With Drift Detection:**
- Alert sent at 6 AM (next scheduled check)
- Team reviews and decides:
  - Option A: Add to desired state permanently
  - Option B: Remove after incident

### Example 2: Config Corruption

**Scenario:** API bug corrupts firewall config

**Without Drift Detection:**
- Hours/days until noticed
- Manual recovery from backups
- Potential downtime

**With Drift Detection:**
- Detected within 30 min (scheduled check)
- Auto-remediated via Terraform
- Near-zero downtime

### Example 3: Audit Compliance

**Scenario:** SOC 2 audit requires proof of config control

**Without Drift Detection:**
- Manual snapshots
- Hard to prove no unauthorized changes

**With Drift Detection:**
- Automated drift reports
- Git history = audit trail
- CI/CD logs prove enforcement

## Monitoring Drift Patterns

### Metrics to Track

```yaml
# drift_frequency
Count of drift detections per day/week

# drift_types
Breakdown: manual_changes vs api_bugs vs sync_failures

# time_to_detection
Time between drift occurrence and detection

# time_to_remediation
Time between detection and fix

# false_positives
Drift alerts that weren't real issues
```

### Dashboard Example

```
Drift Detection Dashboard
─────────────────────────────────────
Last 7 Days:
  Drift Events:        12
  Auto-Remediated:     10
  Manual Review:        2
  
By Type:
  Manual Changes:       8
  Sync Failures:        3
  Unknown:              1
  
Avg Detection Time:    15 min
Avg Remediation Time:  2 min
```

## Testing Drift Detection

### Unit Tests

```typescript
describe('Drift Detection', () => {
  it('should detect added rule', () => {
    const desired = loadConfig('desired.json');
    const current = loadConfig('current-with-extra-rule.json');
    
    const drift = detectDrift(desired, current);
    expect(drift.detected).toBe(true);
    expect(drift.changes).toContain('added_rule: rogue_allow');
  });
});
```

### Integration Tests

```bash
# Test full workflow
./scripts/e2e-test.sh

# Expected output:
# ✅ Baseline applied
# ✅ Drift injected
# ✅ Drift detected
# ✅ Reconciled successfully
```

### Chaos Testing

Inject random drifts and verify detection:

```bash
# Add random rule
./scripts/drift.sh add_rule

# Verify detection
terraform plan | grep "DRIFT DETECTED"

# Modify random rule
./scripts/drift.sh modify

# Verify detection again
terraform plan | grep "DRIFT DETECTED"
```

## Best Practices

### 1. Set Appropriate Check Frequency

```yaml
# Too frequent: Waste CI resources
schedule:
  - cron: '* * * * *'  ❌ Every minute

# Too infrequent: Slow incident response
schedule:
  - cron: '0 0 * * 0'  ⚠️ Weekly only

# Balanced:
schedule:
  - cron: '*/30 * * * *'  ✅ Every 30 min
```

### 2. Use Meaningful Triggers

```hcl
triggers = {
  # Good: Semantic meaning
  config_version = local.desired_config.version
  rules_hash     = md5(jsonencode(local.rules))
  
  # Avoid: Too generic
  timestamp = timestamp()  # Changes every run
}
```

### 3. Implement Proper Logging

```typescript
logger.warn('Drift detected', {
  timestamp: new Date(),
  drift_type: 'rule_added',
  rule_name: 'rogue_allow',
  detected_by: 'terraform',
  severity: 'high'
});
```

### 4. Create Runbooks

```markdown
# Drift Detection Runbook

## Alert Received
1. Check #security-alerts Slack
2. Review drift details in GitHub Actions
3. Assess severity (critical/high/medium/low)

## Investigation
1. Check who made the change (API logs)
2. Determine if intentional or unauthorized
3. Document findings in incident ticket

## Remediation
- If unauthorized → Auto-remediate immediately
- If intentional → Add to desired state + approve
- If unclear → Escalate to security team
```

## Conclusion

Drift detection is essential for maintaining secure, compliant, and predictable infrastructure. This demo provides a solid foundation that can be extended for production use with real Panorama APIs, advanced detection logic, and comprehensive monitoring.

**Key Takeaways:**
- Drift is inevitable without automation
- Hash-based detection is fast and reliable
- Automated remediation reduces MTTR
- Proper monitoring provides visibility
- Testing ensures detection accuracy
