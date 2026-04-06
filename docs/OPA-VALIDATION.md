# Advanced Policy Validation with OPA

> **Open Policy Agent (OPA)** provides enterprise-grade policy validation with declarative rules, compliance checking, and detailed reporting.

---

## Table of Contents

1. [What is OPA?](#what-is-opa)
2. [Why Use OPA for Firewall Validation?](#why-use-opa)
3. [Installation](#installation)
4. [Quick Start](#quick-start)
5. [Policy Rules Explained](#policy-rules-explained)
6. [Running Validations](#running-validations)
7. [CI/CD Integration](#cicd-integration)
8. [Custom Policy Development](#custom-policy-development)
9. [Troubleshooting](#troubleshooting)

---

## What is OPA?

**Open Policy Agent (OPA)** is a general-purpose policy engine that enables unified policy enforcement across your stack.

**Key Benefits:**
- ✅ **Declarative** - Write policies in Rego (policy language)
- ✅ **Flexible** - Validate JSON, YAML, Terraform, Kubernetes, etc.
- ✅ **Extensible** - Custom rules for your organization
- ✅ **Auditable** - Clear violation reports
- ✅ **Fast** - Sub-millisecond evaluation

---

## Why Use OPA for Firewall Validation?

### vs. Simple Bash Script (`validate-policy.sh`)

| Feature | Bash Script | OPA |
|---------|-------------|-----|
| **Rule Complexity** | Simple checks | Complex logic, relationships |
| **Maintainability** | Harder to extend | Declarative, easy to add rules |
| **Reporting** | Basic messages | Detailed, structured output |
| **Compliance** | Manual | Built-in compliance frameworks |
| **Testing** | Manual | Built-in test framework |
| **Reusability** | Script-specific | Policies shared across tools |

### Use Cases for OPA

✅ **Enterprise environments** with complex policies
✅ **Compliance requirements** (PCI-DSS, HIPAA, SOC2)
✅ **Multi-team** setups (shared policy library)
✅ **CI/CD pipelines** (automated validation)
✅ **Audit requirements** (detailed reports)

---

## Installation

### Linux

```bash
curl -L -o /tmp/opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
chmod +x /tmp/opa
sudo mv /tmp/opa /usr/local/bin/
```

### macOS

```bash
# Homebrew
brew install opa

# Or direct download
curl -L -o /tmp/opa https://openpolicyagent.org/downloads/latest/opa_darwin_amd64
chmod +x /tmp/opa
sudo mv /tmp/opa /usr/local/bin/
```

### Windows

```powershell
# Download from https://www.openpolicyagent.org/docs/latest/#running-opa
# Or use Chocolatey
choco install opa
```

### Verify Installation

```bash
opa version
# Expected: Version: 0.x.x
```

---

## Quick Start

### 1. Run OPA Validation

```bash
./scripts/validate-opa.sh
```

**Output:**
```
====================================
OPA POLICY VALIDATION
====================================

✅ Configuration: terraform/desired-config.json
✅ Policy: opa/policies/firewall-security.rego

Validating OPA policy syntax...
✅ Policy syntax valid

Checking for security violations (deny rules)...
✅ No security violations found

Checking for best practice warnings...
⚠️  Found 3 warning(s):

  Rule 'allow_k8s_pod_to_pod' has no tags (recommended: category, owner, compliance)
  Rule 'allow_aws_s3_access' allows file transfer without WildFire sandboxing (recommended)
  ...

Generating summary report...

====================================
SUMMARY REPORT
====================================
{
  "total_rules": 26,
  "allow_rules": 20,
  "deny_rules": 6,
  "rules_with_security_profiles": 16,
  "security_profile_coverage_percent": 80,
  "violations": 0,
  "warnings": 3
}

====================================
✅ VALIDATION PASSED
⚠️  3 warning(s) found
Consider fixing warnings for best practices
====================================
```

### 2. Test with Custom Config

```bash
./scripts/validate-opa.sh path/to/custom-config.json
```

---

## Policy Rules Explained

The OPA policy is organized into **deny**, **warn**, and **compliance** rules.

### Deny Rules (Violations - Must Fix)

These block configurations that violate security policies:

#### 1. **Blanket Allow-All Rules**

```rego
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    "any" in rule.source
    "any" in rule.destination
    "any" in rule.service
    
    msg := sprintf("Rule '%s' is a blanket allow-all", [rule.name])
}
```

**What it catches:**
```json
{
  "name": "dangerous_rule",
  "source": ["any"],
  "destination": ["any"],
  "service": ["any"],
  "action": "allow"
}
```

**Why it's denied:** Defeats the purpose of a firewall.

---

#### 2. **Missing Descriptions**

```rego
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    not rule.description
    
    msg := sprintf("Rule '%s' is missing a description", [rule.name])
}
```

**Why it's denied:** Rules must be documented for audit/maintenance.

---

#### 3. **Allow Rules Without Security Profiles**

```rego
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    not has_critical_security_profiles(rule)
    not is_protocol_exception(rule)
    
    msg := sprintf("Rule '%s' allows traffic without critical security profiles", [rule.name])
}
```

**What it catches:**
```json
{
  "name": "unprotected_web",
  "source": ["10.0.0.0/8"],
  "destination": ["any"],
  "service": ["http", "https"],
  "action": "allow"
  // Missing: antivirus, antiSpyware, vulnerability
}
```

**Why it's denied:** Traffic must be inspected for malware/exploits.

**Exceptions:**
- ICMP/ping (no files to scan)
- DNS override rules
- Emergency rules (disabled)

---

#### 4. **External SSH Access Allowed**

```rego
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    "any" in rule.source
    is_private_network(rule.destination[_])
    "ssh" in rule.service
    
    msg := sprintf("Rule '%s' allows external SSH (security risk)", [rule.name])
}
```

**What it catches:**
```json
{
  "name": "bad_ssh_rule",
  "source": ["any"],
  "destination": ["10.0.0.0/8"],
  "service": ["ssh"],
  "action": "allow"
}
```

**Why it's denied:** Brute force attack vector.

---

#### 5. **P2P/Torrent Applications Allowed**

```rego
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    is_p2p_application(rule.application[_])
    
    msg := sprintf("Rule '%s' allows P2P (bandwidth + legal risk)", [rule.name])
}
```

**What it catches:**
- `bittorrent`, `torrent`, `utorrent`, `emule`

**Why it's denied:** Bandwidth abuse, legal liability.

---

#### 6. **Risky Remote Access Tools**

```rego
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    is_risky_remote_tool(rule.application[_])
    
    msg := sprintf("Rule '%s' allows risky remote tool", [rule.name])
}
```

**What it catches:**
- `teamviewer`, `anydesk`, `logmein`, `tor`

**Why it's denied:** Uncontrolled remote access, data exfiltration risk.

---

### Warn Rules (Best Practices - Should Fix)

These highlight violations of best practices but don't block:

#### 1. **Rules Without Tags**

```rego
warn[msg] {
    some rule in input.policies.security
    not rule.tags
    
    msg := sprintf("Rule '%s' has no tags", [rule.name])
}
```

**Recommendation:** Add tags for organization:
```json
"tags": {
  "category": "internet-access",
  "owner": "network-team",
  "compliance": "standard"
}
```

---

#### 2. **Web Traffic Without URL Filtering**

```rego
warn[msg] {
    some rule in input.policies.security
    is_web_application(rule.application[_])
    not rule.urlFiltering
    
    msg := sprintf("Rule '%s' allows web without URL filtering", [rule.name])
}
```

**Recommendation:** Add URL filtering profile:
```json
"urlFiltering": {
  "profile": "default-url-filtering",
  "blockedCategories": ["adult", "gambling", "malware"]
}
```

---

#### 3. **File Transfer Without WildFire**

```rego
warn[msg] {
    some rule in input.policies.security
    is_file_transfer_app(rule.application[_])
    not rule.wildfire
    
    msg := sprintf("Rule '%s' allows file transfer without WildFire", [rule.name])
}
```

**Recommendation:** Add WildFire:
```json
"wildfire": "default"
```

---

#### 4. **VPN Access Without HIP Check**

```rego
warn[msg] {
    some rule in input.policies.security
    contains(rule.source[_], "vpn")
    count(rule.hipProfiles) == 0
    
    msg := sprintf("Rule '%s' allows VPN without HIP checks", [rule.name])
}
```

**Recommendation:** Require endpoint compliance:
```json
"hipProfiles": ["corporate-endpoint-security"]
```

---

#### 5. **Admin Access Without MFA**

```rego
warn[msg] {
    some rule in input.policies.security
    is_admin_service(rule.service[_])
    not rule.mfa.required
    
    msg := sprintf("Rule '%s' allows admin access without MFA", [rule.name])
}
```

**Recommendation:** Require multi-factor authentication:
```json
"mfa": {
  "required": true,
  "profile": "duo-security"
}
```

---

### Compliance Rules

#### PCI-DSS Validation

```rego
# Enhanced logging required
deny[msg] {
    some rule in input.policies.security
    rule.tags.compliance == "pci-dss"
    not rule.log.atSessionStart
    
    msg := sprintf("Rule '%s' is PCI-DSS scoped but missing session-start logging", [rule.name])
}

# Data filtering required
deny[msg] {
    some rule in input.policies.security
    rule.tags.compliance == "pci-dss"
    not rule.dataFiltering
    
    msg := sprintf("Rule '%s' is PCI-DSS scoped but missing DLP", [rule.name])
}
```

#### HIPAA Validation

```rego
deny[msg] {
    some rule in input.policies.security
    rule.tags.standard == "hipaa"
    not contains(rule.dataFiltering, "phi")
    
    msg := sprintf("Rule '%s' is HIPAA scoped but missing PHI data filtering", [rule.name])
}
```

---

## Running Validations

### Basic Validation

```bash
./scripts/validate-opa.sh
```

### Validate Custom Config

```bash
./scripts/validate-opa.sh path/to/config.json
```

### JSON Output (for CI/CD)

```bash
opa eval --data opa/policies/firewall-security.rego \
         --input terraform/desired-config.json \
         --format json 'data.firewall.security'
```

### Query Specific Rules

**Check only deny rules:**
```bash
opa eval --data opa/policies/firewall-security.rego \
         --input terraform/desired-config.json \
         --format pretty 'data.firewall.security.deny'
```

**Check only warnings:**
```bash
opa eval --data opa/policies/firewall-security.rego \
         --input terraform/desired-config.json \
         --format pretty 'data.firewall.security.warn'
```

**Get summary:**
```bash
opa eval --data opa/policies/firewall-security.rego \
         --input terraform/desired-config.json \
         --format pretty 'data.firewall.security.summary'
```

---

## CI/CD Integration

### GitHub Actions

Add to `.github/workflows/drift-detection.yml`:

```yaml
- name: Install OPA
  run: |
    curl -L -o /tmp/opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
    chmod +x /tmp/opa
    sudo mv /tmp/opa /usr/local/bin/

- name: OPA Policy Validation
  run: |
    ./scripts/validate-opa.sh terraform/desired-config.json
```

### GitLab CI

```yaml
opa_validation:
  image: openpolicyagent/opa:latest
  script:
    - opa eval --data opa/policies/firewall-security.rego 
                --input terraform/desired-config.json 
                --format pretty 'data.firewall.security.deny'
    - test $(opa eval --data opa/policies/firewall-security.rego 
             --input terraform/desired-config.json 
             --format json 'data.firewall.security.deny' | jq 'length') -eq 0
```

### Pre-commit Hook

```bash
# .git/hooks/pre-commit
#!/bin/bash
./scripts/validate-opa.sh terraform/desired-config.json
if [ $? -ne 0 ]; then
    echo "❌ OPA validation failed. Commit blocked."
    exit 1
fi
```

---

## Custom Policy Development

### Add a New Deny Rule

```rego
# Deny: Cryptocurrency mining applications
deny[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    rule.enabled == true
    
    some app in rule.application
    is_crypto_mining_app(app)
    
    msg := sprintf("Rule '%s' allows crypto mining app '%s'", [rule.name, app])
}

is_crypto_mining_app(app) {
    app == "bitcoin-mining"
}

is_crypto_mining_app(app) {
    app == "ethereum-mining"
}
```

### Add a New Warn Rule

```rego
# Warn: Database traffic without encryption
warn[msg] {
    some rule in input.policies.security
    rule.action == "allow"
    
    some svc in rule.service
    is_database_port(svc)
    
    # No TLS/encryption mentioned
    not contains(rule.description, "tls")
    not contains(rule.description, "encrypted")
    
    msg := sprintf("Rule '%s' allows database traffic, ensure encryption is used", [rule.name])
}

is_database_port(port) {
    port == "tcp/3306"  # MySQL
}

is_database_port(port) {
    port == "tcp/5432"  # PostgreSQL
}
```

### Test Your Policy

```bash
# Check syntax
opa check opa/policies/firewall-security.rego

# Test against config
opa eval --data opa/policies/firewall-security.rego \
         --input terraform/desired-config.json \
         --format pretty 'data.firewall.security'
```

---

## Troubleshooting

### OPA Not Installed

**Error:**
```
❌ OPA is not installed
```

**Solution:**
```bash
curl -L -o /tmp/opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
chmod +x /tmp/opa
sudo mv /tmp/opa /usr/local/bin/
```

### Policy Syntax Error

**Error:**
```
1 error occurred: opa/policies/firewall-security.rego:15: rego_parse_error: unexpected identifier token
```

**Solution:**
- Check line 15 for syntax errors
- Common issues:
  - Missing brackets `{ }`
  - Missing `if` keyword
  - Incorrect variable scoping

### No Output from `opa eval`

**Problem:** Policy doesn't match any rules

**Debug:**
```bash
# Test with simple query
opa eval --data opa/policies/firewall-security.rego \
         --input terraform/desired-config.json \
         --format pretty 'input'

# Check if policy loaded
opa eval --data opa/policies/firewall-security.rego \
         --format pretty 'data'
```

### False Positives

**Example:** Rule flagged as violation but should be allowed

**Solution:** Add exception to policy:

```rego
# Original rule
deny[msg] {
    some rule in input.policies.security
    # ... conditions ...
    
    # Add exception
    not is_exception(rule)
    
    msg := "..."
}

# Exception helper
is_exception(rule) {
    rule.name == "specific_rule_name"
}
```

---

## Best Practices

### 1. **Version Control Your Policies**

```bash
git add opa/policies/
git commit -m "Add OPA firewall security policy"
```

### 2. **Test Policies Separately**

Create `opa/tests/firewall-security_test.rego`:

```rego
package firewall.security

test_deny_allow_all {
    deny with input as {
        "policies": {
            "security": [{
                "name": "bad_rule",
                "action": "allow",
                "enabled": true,
                "source": ["any"],
                "destination": ["any"],
                "service": ["any"]
            }]
        }
    }
}
```

Run tests:
```bash
opa test opa/
```

### 3. **Gradual Rollout**

1. Start with warnings only (no deny rules)
2. Fix warnings gradually
3. Promote warnings to deny rules
4. Add compliance rules last

### 4. **Document Exceptions**

```rego
# Exception: Legacy system migration (expires 2026-12-31)
is_exception(rule) {
    rule.name == "legacy_system_access"
    # TODO: Remove after migration complete
}
```

---

## Comparison: Bash vs OPA

### Simple Bash Script

**Good for:**
- ✅ Quick checks
- ✅ Simple deployments
- ✅ No dependencies
- ✅ Fast to write

**Limitations:**
- ❌ Hard to maintain complex rules
- ❌ No structured output
- ❌ Limited reusability
- ❌ No compliance frameworks

### OPA

**Good for:**
- ✅ Complex policy logic
- ✅ Enterprise environments
- ✅ Compliance requirements
- ✅ Reusable policies
- ✅ CI/CD integration
- ✅ Detailed reporting

**Limitations:**
- ❌ Requires OPA installation
- ❌ Learning curve (Rego language)
- ❌ More setup overhead

---

## When to Use Which?

| Scenario | Use Bash | Use OPA |
|----------|----------|---------|
| Quick local validation | ✅ | |
| Simple rules (<10) | ✅ | |
| One-time checks | ✅ | |
| Enterprise deployment | | ✅ |
| Compliance requirements | | ✅ |
| Complex rule relationships | | ✅ |
| Multi-team environments | | ✅ |
| CI/CD pipeline | | ✅ |
| Audit requirements | | ✅ |

**Recommendation:** Use **both**!
- Bash for quick local checks
- OPA for CI/CD and production

---

## Next Steps

1. ✅ Install OPA
2. ✅ Run `./scripts/validate-opa.sh`
3. ✅ Review violations and warnings
4. ✅ Add custom rules for your organization
5. ✅ Integrate into CI/CD pipeline

**Resources:**
- [OPA Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Rego Playground](https://play.openpolicyagent.org/)
- [Policy Library](https://github.com/open-policy-agent/library)

---

For more validation guides:
- [Basic Policy Validation (Bash)](POLICY-VALIDATION.md)
- [Configuration Guide](CONFIGURATION-GUIDE.md)
- [Architecture Guide](ARCHITECTURE.md)
