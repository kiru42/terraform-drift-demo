# Policy Validation Guide

## Overview

Policy as Code validation ensures that firewall configurations meet security standards before being applied. This prevents dangerous misconfigurations and enforces organizational security policies.

## Why Policy Validation?

### Without Validation

```json
{
  "name": "oops_deny_all",
  "source": ["any"],
  "destination": ["any"],
  "service": ["any"],
  "action": "deny"
}
```

**Result:** Complete network lockout! ❌

### With Validation

```bash
$ ./scripts/validate-policy.sh config.json
❌ VALIDATION FAILED: Blanket deny rule detected
Rule: oops_deny_all
This would block all traffic!
```

**Result:** Configuration rejected, disaster avoided ✅

## Validation Rules

### Rule 1: No Blanket Deny Rules

**Policy:** Deny rules with source=any, destination=any are too restrictive

**Detection:**
```bash
jq -r '[.policies.security[] | 
  select(.action == "deny" and 
         (.source | index("any")) and 
         (.destination | index("any")))] 
  | length' config.json
```

**Why:** Can cause complete network outage

**Fix:** Use specific deny rules
```json
{
  "name": "block_specific_threat",
  "source": ["192.168.100.0/24"],  // Specific source
  "destination": ["any"],
  "service": ["any"],
  "action": "deny"
}
```

### Rule 2: All Rules Must Have Names

**Policy:** Every rule must have a non-empty name

**Detection:**
```bash
jq -r '[.policies.security[] | 
  select(.name == "" or .name == null)] 
  | length' config.json
```

**Why:**
- Audit trail requires identifiable rules
- Troubleshooting needs clear naming
- Documentation/compliance

**Fix:**
```json
{
  "name": "allow_web_traffic",  // ✅ Clear name
  "action": "allow",
  // ...
}
```

### Rule 3: Valid Actions Only

**Policy:** Actions must be `allow`, `deny`, or `drop`

**Detection:**
```bash
jq -r '[.policies.security[] | 
  select(.action != "allow" and 
         .action != "deny" and 
         .action != "drop")] 
  | length' config.json
```

**Why:** Invalid actions cause firewall errors

**Valid values:**
- `allow` - Permit traffic
- `deny` - Block and notify sender
- `drop` - Silently discard

### Rule 4 (Warning): Overly Permissive Rules

**Policy:** Warn about "allow any any any" rules

**Detection:**
```bash
jq -r '[.policies.security[] | 
  select(.action == "allow" and 
         (.source | index("any")) and 
         (.destination | index("any")) and 
         (.service | index("any")))] 
  | length' config.json
```

**Why:** Security best practices require least privilege

**Recommendation:**
```json
// ❌ Too permissive
{
  "source": ["any"],
  "destination": ["any"],
  "service": ["any"],
  "action": "allow"
}

// ✅ Better - restrict at least one dimension
{
  "source": ["10.0.0.0/8"],      // Internal only
  "destination": ["any"],
  "service": ["http", "https"],   // Web only
  "action": "allow"
}
```

## Validation Script Usage

### Basic Usage

```bash
./scripts/validate-policy.sh terraform/desired-config.json
```

### Output Examples

#### Passing Validation

```
===================================
POLICY VALIDATION
===================================

✅ JSON format valid
✅ No blanket deny rules
✅ All rules have names
✅ All rules have valid actions

✅ Policy validation passed
Total rules: 2
```

#### Failing Validation

```
===================================
POLICY VALIDATION
===================================

✅ JSON format valid
❌ VALIDATION FAILED: Found 1 blanket 'deny all' rule(s)
Blanket deny rules are too restrictive and should be avoided.
  block_everything

Exit code: 1
```

#### Warning (Non-Blocking)

```
===================================
POLICY VALIDATION
===================================

✅ JSON format valid
✅ No blanket deny rules
✅ All rules have names
✅ All rules have valid actions
⚠️  WARNING: Found 1 overly permissive 'allow any any' rule(s)
  temp_allow_all
Consider restricting source, destination, or service

✅ Policy validation passed
Total rules: 3
```

## Integration with Terraform

### Automatic Validation

```hcl
resource "null_resource" "panorama_config" {
  # Validate before applying
  provisioner "local-exec" {
    command = "./scripts/validate-policy.sh ${var.desired_config_file}"
  }
  
  # Only runs if validation passes
  provisioner "local-exec" {
    command = "apply_config.sh"
  }
}
```

### GitHub Actions Integration

```yaml
- name: Validate Policy
  run: |
    chmod +x ./scripts/validate-policy.sh
    ./scripts/validate-policy.sh terraform/desired-config.json
```

**Result:** PR fails if policy validation fails

## Advanced Validation with OPA

### What is OPA?

Open Policy Agent: Policy engine for cloud-native environments

### Installation

```bash
# macOS
brew install opa

# Linux
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
chmod +x opa
```

### OPA Policy Example

Create `policy/firewall.rego`:

```rego
package firewall

# Deny blanket deny rules
deny[msg] {
  rule := input.policies.security[_]
  rule.action == "deny"
  "any" == rule.source[_]
  "any" == rule.destination[_]
  msg := sprintf("Blanket deny rule detected: %s", [rule.name])
}

# Require named rules
deny[msg] {
  rule := input.policies.security[_]
  not rule.name
  msg := "All rules must have names"
}

# Warn about overly permissive rules
warn[msg] {
  rule := input.policies.security[_]
  rule.action == "allow"
  "any" == rule.source[_]
  "any" == rule.destination[_]
  "any" == rule.service[_]
  msg := sprintf("Overly permissive rule: %s", [rule.name])
}

# Require description for complex rules
deny[msg] {
  rule := input.policies.security[_]
  count(rule.source) > 5
  not rule.description
  msg := sprintf("Complex rule requires description: %s", [rule.name])
}
```

### Run OPA Validation

```bash
opa eval \
  --data policy/firewall.rego \
  --input terraform/desired-config.json \
  --format pretty \
  'data.firewall.deny'
```

### Integrate with CI/CD

```yaml
- name: Install OPA
  run: |
    curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
    chmod +x opa
    sudo mv opa /usr/local/bin/

- name: Validate with OPA
  run: |
    opa eval \
      --fail-defined \
      --data policy/ \
      --input terraform/desired-config.json \
      'data.firewall.deny'
```

## Custom Validation Rules

### Organization-Specific Rules

```bash
# Example: Enforce naming convention
validate_naming() {
  INVALID_NAMES=$(jq -r '[.policies.security[] | 
    select(.name | test("^[a-z_]+$") | not)] | length' "$1")
  
  if [ "$INVALID_NAMES" -gt 0 ]; then
    echo "❌ Rule names must be lowercase with underscores only"
    return 1
  fi
}

# Example: Require approval for production
validate_approval() {
  if [ "$ENV" = "prod" ]; then
    if [ ! -f "approval.txt" ]; then
      echo "❌ Production changes require approval file"
      return 1
    fi
  fi
}

# Example: Check for required tags
validate_tags() {
  MISSING_OWNER=$(jq -r '[.policies.security[] | 
    select(.tags.owner == null)] | length' "$1")
  
  if [ "$MISSING_OWNER" -gt 0 ]; then
    echo "⚠️  Rules missing owner tag"
  fi
}
```

### Integration

```bash
#!/bin/bash
# Enhanced validation script

validate_json "$CONFIG"
validate_basic_rules "$CONFIG"
validate_naming "$CONFIG"
validate_tags "$CONFIG"

if [ "$ENV" = "prod" ]; then
  validate_approval "$CONFIG"
fi
```

## Testing Validation Rules

### Test Cases

```bash
# Test 1: Valid config should pass
cat > test-valid.json << EOF
{
  "policies": {
    "security": [
      {
        "name": "allow_web",
        "action": "allow",
        "source": ["10.0.0.0/8"],
        "destination": ["any"],
        "service": ["http", "https"],
        "enabled": true
      }
    ]
  }
}
EOF

./scripts/validate-policy.sh test-valid.json
# Expected: Exit 0 (success)

# Test 2: Blanket deny should fail
cat > test-deny-all.json << EOF
{
  "policies": {
    "security": [
      {
        "name": "block_all",
        "action": "deny",
        "source": ["any"],
        "destination": ["any"],
        "service": ["any"],
        "enabled": true
      }
    ]
  }
}
EOF

./scripts/validate-policy.sh test-deny-all.json
# Expected: Exit 1 (failure)

# Test 3: Unnamed rule should fail
cat > test-no-name.json << EOF
{
  "policies": {
    "security": [
      {
        "action": "allow",
        "source": ["any"],
        "destination": ["any"],
        "service": ["http"]
      }
    ]
  }
}
EOF

./scripts/validate-policy.sh test-no-name.json
# Expected: Exit 1 (failure)
```

### Automated Test Suite

```bash
#!/bin/bash
# test-validation.sh

run_test() {
  local name=$1
  local config=$2
  local expected_exit=$3
  
  echo "Testing: $name"
  ./scripts/validate-policy.sh "$config"
  actual_exit=$?
  
  if [ $actual_exit -eq $expected_exit ]; then
    echo "✅ PASS"
  else
    echo "❌ FAIL (expected $expected_exit, got $actual_exit)"
    FAILED=$((FAILED + 1))
  fi
  echo ""
}

FAILED=0

run_test "Valid config" "test-valid.json" 0
run_test "Blanket deny" "test-deny-all.json" 1
run_test "Unnamed rule" "test-no-name.json" 1
run_test "Invalid action" "test-bad-action.json" 1

if [ $FAILED -eq 0 ]; then
  echo "✅ All tests passed"
  exit 0
else
  echo "❌ $FAILED tests failed"
  exit 1
fi
```

## Real-World Scenarios

### Scenario 1: Emergency Rule

**Situation:** Security incident requires immediate rule

```json
{
  "name": "emergency_block_c2_server",
  "source": ["any"],
  "destination": ["203.0.113.100/32"],
  "service": ["any"],
  "action": "drop",
  "enabled": true,
  "description": "Block known C2 server - Incident #12345"
}
```

**Validation:** ✅ Passes (specific destination)

### Scenario 2: Accidental Lockout

**Situation:** Admin creates overly broad rule

```json
{
  "name": "test_rule",
  "source": ["any"],
  "destination": ["any"],
  "service": ["any"],
  "action": "deny"
}
```

**Validation:** ❌ Fails (blanket deny)
**Result:** Prevented network outage

### Scenario 3: Compliance Requirement

**Situation:** SOC 2 requires all rules have descriptions

```rego
# Add to OPA policy
deny[msg] {
  rule := input.policies.security[_]
  not rule.description
  msg := sprintf("SOC 2 compliance: Rule must have description: %s", [rule.name])
}
```

**Validation:** Enforces compliance automatically

## Best Practices

### 1. Start Permissive, Tighten Gradually

```
Week 1: Warn about issues (don't block)
Week 2: Block critical issues only
Week 3: Enforce all rules
```

### 2. Provide Clear Error Messages

```bash
# ❌ Bad
echo "Error in config"

# ✅ Good
echo "❌ VALIDATION FAILED: Rule 'allow_all' is overly permissive"
echo "Recommendation: Restrict source to internal networks (10.0.0.0/8)"
echo "Documentation: https://wiki.company.com/firewall-policy"
```

### 3. Make Validation Fast

```bash
# Optimize for speed
# ❌ Slow: Multiple jq calls
for rule in $(jq -r '.policies.security[] | @base64' config.json); do
  # Process each rule separately
done

# ✅ Fast: Single jq call
ISSUES=$(jq -r '[.policies.security[] | select(condition)] | length' config.json)
```

### 4. Version Control Validation Rules

```
policy/
├── v1.0/
│   └── firewall.rego
├── v2.0/
│   └── firewall.rego
└── current -> v2.0/
```

### 5. Document Exceptions

```json
{
  "name": "legacy_app_rule",
  "action": "allow",
  "source": ["any"],
  "destination": ["10.0.50.0/24"],
  "service": ["any"],
  "description": "Exception approved by Security team - Ticket #5678",
  "tags": {
    "exception": "true",
    "expiry": "2024-12-31",
    "approver": "security-team@company.com"
  }
}
```

## Monitoring Validation

### Track Metrics

```yaml
validation_failures_total:
  Count of validation failures per day

validation_warnings_total:
  Count of warnings (non-blocking)

validation_duration_seconds:
  Time to run validation

bypassed_validations_total:
  Emergency bypasses (requires approval)
```

### Dashboard

```
Policy Validation Dashboard
─────────────────────────────────────
Last 30 Days:
  Validations Run:        450
  Failures:                12
  Warnings:                34
  Avg Duration:           1.2s
  
Top Violations:
  1. Unnamed rules:         7
  2. Overly permissive:     3
  3. Missing descriptions:  2
```

## Conclusion

Policy as Code validation is a critical safety mechanism that prevents dangerous firewall configurations. By combining basic script validation with advanced tools like OPA, you can enforce organizational security policies automatically and catch mistakes before they cause outages.

**Key Takeaways:**
- Validation prevents costly mistakes
- Start simple (bash + jq), evolve to OPA if needed
- Integrate validation into CI/CD pipeline
- Provide clear, actionable error messages
- Track metrics to improve over time
