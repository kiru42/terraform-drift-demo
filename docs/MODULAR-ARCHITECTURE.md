# Modular Terraform Architecture

This document explains the production-ready modular architecture of this Terraform drift detection demo.

## 🏗️ Architecture Overview

```
terraform/
├── main-modular.tf          # Entry point using modules
├── firewall-rules.yaml      # Human-readable rule definitions
├── modules/
│   ├── security-rule/       # Reusable security policy module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── nat-rule/            # NAT policy module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ssl-decryption-rule/ # SSL decryption module
│   └── dos-profile/         # DoS protection module
└── desired-config.json      # Legacy format (backward compat)
```

## 📁 File Structure Explained

### **main-modular.tf** (Entry Point)
```hcl
# Loads YAML config
locals {
  firewall_config = yamldecode(file("firewall-rules.yaml"))
}

# Creates rules using modules
module "security_rules" {
  source = "./modules/security-rule"
  for_each = local.security_rules_map
  
  name        = each.value.name
  source      = each.value.source
  destination = each.value.destination
  # ...
}
```

**Benefits:**
- ✅ DRY (Don't Repeat Yourself) - no rule duplication
- ✅ Single source of truth (YAML file)
- ✅ Easy to review (module changes affect all rules)
- ✅ Type-safe (Terraform validates inputs)

### **firewall-rules.yaml** (Configuration)
```yaml
security_rules:
  - name: allow_internal_web
    source: [10.0.0.0/8, 172.16.0.0/12]
    destination: [any]
    service: [http, https]
    action: allow
    security_profiles:
      antivirus: strict-av
      anti_spyware: strict
```

**Benefits:**
- ✅ Human-readable (non-devs can review)
- ✅ Git-friendly (clean diffs)
- ✅ No programming required
- ✅ Easy bulk operations (search/replace)

### **modules/security-rule/** (Reusable Logic)
```hcl
# variables.tf - Input validation
variable "action" {
  validation {
    condition     = contains(["allow", "deny", "drop"], var.action)
    error_message = "Invalid action"
  }
}

# main.tf - Resource creation
resource "panos_security_policy" "rule" {
  name = var.name
  # ...
}

# outputs.tf - Data for other modules
output "rule_id" {
  value = panos_security_policy.rule.id
}
```

**Benefits:**
- ✅ Reusable across environments
- ✅ Testable in isolation
- ✅ Input validation enforced
- ✅ Versioned independently

## 🚀 Usage

### Viewing the Configuration

```bash
# List all security rules
cat firewall-rules.yaml | yq '.security_rules[].name'

# Filter by tag
cat firewall-rules.yaml | yq '.security_rules[] | select(.tags.compliance == "pci-dss")'

# Count allow vs deny rules
cat firewall-rules.yaml | yq '.security_rules[].action' | sort | uniq -c
```

### Adding a New Rule

```bash
# Edit firewall-rules.yaml
nano firewall-rules.yaml

# Add at the end of security_rules:
  - name: allow_new_service
    source: [10.0.0.0/8]
    destination: [any]
    service: [tcp/8080]
    action: allow
    enabled: true
    description: "New service access"
    tags:
      category: application
      owner: dev-team
    log:
      at_session_start: false
      at_session_end: true
    security_profiles:
      antivirus: default-av-profile
      anti_spyware: default-anti-spyware
      vulnerability: default-vulnerability

# Apply changes
terraform plan
terraform apply
```

### Modifying Security Profiles

```bash
# Bulk update all rules to use strict profiles
sed -i 's/default-av-profile/strict-av/g' firewall-rules.yaml

terraform plan  # Review changes
terraform apply
```

### Disabling a Rule

```yaml
  - name: allow_legacy_app
    # ... (rule config)
    enabled: false  # ← Just change this
```

## 🔄 Migration from JSON

The repo includes both formats for demonstration:

| File | Format | Use Case |
|------|--------|----------|
| `main.tf` | JSON-based | Legacy demo (simple) |
| `main-modular.tf` | YAML + Modules | Production (recommended) |

### Converting JSON → YAML

```bash
# Run conversion script
./convert-to-yaml.sh

# Review output
cat firewall-rules.yaml

# Switch to modular config
mv main.tf main-legacy.tf
mv main-modular.tf main.tf

terraform init
terraform plan
```

## 🎯 Production Best Practices

### 1. **Environment Separation**

```
terraform/
├── environments/
│   ├── prod/
│   │   ├── main.tf
│   │   ├── firewall-rules.yaml
│   │   └── terraform.tfvars
│   ├── staging/
│   │   └── firewall-rules.yaml
│   └── dev/
│       └── firewall-rules.yaml
└── modules/  (shared)
```

### 2. **Remote State Backend**

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "firewall/prod/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### 3. **Module Versioning**

```hcl
module "security_rules" {
  source  = "git::https://github.com/myorg/terraform-modules.git//security-rule?ref=v1.2.0"
  # ...
}
```

### 4. **OPA Policy Validation**

```bash
# Validate before apply
opa eval --data policies/firewall.rego \
  --input firewall-rules.yaml \
  'data.firewall.deny'

# Block if violations found
if [ $? -ne 0 ]; then
  echo "❌ Policy violations detected"
  exit 1
fi

terraform apply
```

### 5. **Automated Testing**

```hcl
# test/security_rule_test.go
func TestSecurityRuleModule(t *testing.T) {
  terraformOptions := &terraform.Options{
    TerraformDir: "../modules/security-rule",
    Vars: map[string]interface{}{
      "name":   "test_rule",
      "action": "allow",
    },
  }
  
  defer terraform.Destroy(t, terraformOptions)
  terraform.InitAndApply(t, terraformOptions)
  
  ruleName := terraform.Output(t, terraformOptions, "name")
  assert.Equal(t, "test_rule", ruleName)
}
```

## 📊 Comparison: JSON vs Modular

| Aspect | JSON (Legacy) | YAML + Modules (Prod) |
|--------|---------------|----------------------|
| **Readability** | ❌ 2400+ line JSON | ✅ Clean YAML |
| **Reusability** | ❌ Copy-paste rules | ✅ Shared modules |
| **Validation** | ⚠️ Manual scripts | ✅ Terraform built-in |
| **Testing** | ❌ Hard to test | ✅ Unit testable |
| **Review** | ❌ Huge diffs | ✅ Readable diffs |
| **Environments** | ❌ Duplicate files | ✅ Shared modules |
| **Collaboration** | ❌ Merge conflicts | ✅ Git-friendly |

## 🔍 Troubleshooting

### Module not found
```bash
terraform get -update
terraform init
```

### YAML parse error
```bash
# Validate YAML syntax
yq eval . firewall-rules.yaml

# Or use Python
python3 -c "import yaml; yaml.safe_load(open('firewall-rules.yaml'))"
```

### Rule validation failed
```bash
# Check module variables
terraform console

# Inspect specific rule
> local.security_rules_map["allow_internal_web"]
```

## 📚 Further Reading

- [Terraform Module Best Practices](https://www.terraform.io/docs/modules/index.html)
- [OPA Policy as Code](https://www.openpolicyagent.org/docs/latest/terraform/)
- [GitOps for Infrastructure](https://www.gitops.tech/)
- [Terratest for Module Testing](https://terratest.gruntwork.io/)

---

**Next Steps:**
1. Review the modular architecture
2. Run `terraform plan` to see changes
3. Customize `firewall-rules.yaml` for your environment
4. Set up CI/CD pipeline with OPA validation
5. Migrate to remote state backend
