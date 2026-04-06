# Multi-Environment Configuration

This directory contains environment-specific Terraform configurations for **production**, **staging**, and **development**.

## 📁 Structure

```
environments/
├── prod/
│   ├── main.tf
│   ├── firewall-rules.yaml
│   └── terraform.tfvars (optional)
├── staging/
│   ├── main.tf
│   ├── firewall-rules.yaml
│   └── terraform.tfvars (optional)
└── dev/
    ├── main.tf
    ├── firewall-rules.yaml
    └── terraform.tfvars (optional)
```

## 🌍 Environment Comparison

| Feature | Production | Staging | Development |
|---------|-----------|---------|-------------|
| **Security Profiles** | ✅ Strict (all enabled) | ⚠️ Standard | ❌ Disabled |
| **Logging** | ✅ Full (start+end) | ⚠️ End only | ❌ Minimal |
| **SIEM Integration** | ✅ prod-siem | ⚠️ staging-syslog | ❌ None |
| **Compliance** | ✅ PCI-DSS/HIPAA | ⚠️ Standard | ❌ None |
| **SSH Access** | ❌ Blocked | ⚠️ Limited | ✅ Allowed |
| **State Backend** | ✅ S3 + DynamoDB | ✅ S3 + DynamoDB | ⚠️ Local (optional) |
| **Rules Count** | ~15-20 | ~8-12 | ~2-3 |
| **Default Action** | ❌ Deny | ⚠️ Selective | ✅ Allow |

## 🚀 Usage

### Deploy to Production

```bash
cd environments/prod

# Initialize Terraform (downloads modules + providers)
terraform init

# Preview changes
terraform plan

# Apply changes (requires approval)
terraform apply
```

### Deploy to Staging

```bash
cd environments/staging
terraform init
terraform apply
```

### Deploy to Development

```bash
cd environments/dev
terraform init
terraform apply
```

## 🔄 Switching Between Environments

### Method 1: Change Directory

```bash
# Work on prod
cd environments/prod
terraform plan
terraform apply

# Work on staging
cd ../staging
terraform plan
terraform apply
```

### Method 2: Use Workspaces (Single Directory)

```bash
# Create workspaces
terraform workspace new prod
terraform workspace new staging
terraform workspace new dev

# Switch workspace
terraform workspace select prod
terraform plan -var-file=environments/prod/terraform.tfvars

terraform workspace select staging
terraform plan -var-file=environments/staging/terraform.tfvars
```

## 📝 Adding a New Rule

### Option 1: Edit YAML (Recommended)

```bash
# Edit environment-specific YAML
nano environments/prod/firewall-rules.yaml

# Add your rule:
  - name: allow_new_service_prod
    source: [10.0.0.0/8]
    destination: [any]
    service: [tcp/8080]
    action: allow
    enabled: true
    description: "Production: New service access"
    tags:
      environment: production
      category: application
    log:
      at_session_start: false
      at_session_end: true
      log_forwarding: prod-siem
    security_profiles:
      antivirus: strict-av-prod
      antiSpyware: strict-prod
      vulnerability: strict-prod

# Apply
terraform plan
terraform apply
```

### Option 2: Copy from Another Environment

```bash
# Copy staging rule to prod
cat environments/staging/firewall-rules.yaml >> environments/prod/firewall-rules.yaml

# Edit to update tags/profiles for prod
nano environments/prod/firewall-rules.yaml
```

## 🔒 Remote State Backend Setup

### Prerequisites

```bash
# Create S3 bucket for state
aws s3 mb s3://my-terraform-state-prod --region eu-west-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket my-terraform-state-prod \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket my-terraform-state-prod \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-locks-prod \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1
```

### Configure Backend

Update `environments/prod/main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-prod"
    key            = "firewall/prod/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks-prod"
    encrypt        = true
  }
}
```

### Migrate from Local to Remote State

```bash
cd environments/prod

# Initialize with new backend
terraform init -migrate-state

# Verify
terraform state list
```

## 🧪 Testing Environment Changes

### Validate Configuration

```bash
# Check Terraform syntax
terraform fmt -check -recursive
terraform validate

# Dry-run
terraform plan -out=plan.tfplan

# Review plan
terraform show plan.tfplan
```

### Run OPA Policy Validation

```bash
# Convert YAML to JSON for OPA
yq eval -o=json firewall-rules.yaml > firewall-rules.json

# Validate with OPA
opa eval --data ../../../opa/policies/firewall-security.rego \
  --input firewall-rules.json \
  'data.firewall.security.deny'
```

## 🔄 Promoting Changes Across Environments

### Workflow: Dev → Staging → Prod

```bash
# 1. Test in dev
cd environments/dev
terraform plan
terraform apply

# 2. Copy to staging (update tags)
cp firewall-rules.yaml ../staging/
cd ../staging
sed -i 's/environment: development/environment: staging/g' firewall-rules.yaml
terraform plan
terraform apply

# 3. Copy to prod (strict security)
cp firewall-rules.yaml ../prod/
cd ../prod
sed -i 's/environment: staging/environment: production/g' firewall-rules.yaml
sed -i 's/default-av-staging/strict-av-prod/g' firewall-rules.yaml
terraform plan
terraform apply
```

## 📊 Outputs

Each environment exposes outputs:

```bash
# Get environment name
terraform output environment

# Count security rules
terraform output security_rules_count
```

## 🆘 Troubleshooting

### State Lock Error

```bash
# Force unlock (use ID from error message)
terraform force-unlock <LOCK_ID>
```

### Backend Not Initialized

```bash
terraform init -reconfigure
```

### Module Not Found

```bash
# Re-download modules
terraform get -update
terraform init -upgrade
```

### YAML Parse Error

```bash
# Validate YAML syntax
yq eval . firewall-rules.yaml
```

## 🎯 Best Practices

1. **Never commit `.terraform/`** - Add to `.gitignore`
2. **Always use remote state for prod/staging** - Enables team collaboration
3. **Tag all rules with environment** - Makes filtering easier
4. **Test in dev first** - Then promote to staging → prod
5. **Use descriptive rule names** - Include environment suffix (`_prod`, `_staging`)
6. **Enable state locking** - Prevents concurrent modifications
7. **Backup state files** - S3 versioning + periodic snapshots

## 📚 Further Reading

- [Terraform Workspaces](https://www.terraform.io/docs/language/state/workspaces.html)
- [Remote State Backends](https://www.terraform.io/docs/language/settings/backends/index.html)
- [Environment Separation Patterns](https://www.terraform-best-practices.com/)
