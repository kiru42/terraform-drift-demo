# Terraform Module Tests

Automated tests for Terraform modules using [Terratest](https://terratest.gruntwork.io/).

## Prerequisites

- Go 1.22+
- Terraform 1.5+

## Installation

```bash
cd test
go mod download
```

## Running Tests

### Run All Tests

```bash
go test -v -timeout 30m
```

### Run Specific Test

```bash
# Security rule tests
go test -v -run TestSecurityRuleModule

# NAT rule tests
go test -v -run TestNATRuleModuleSNAT
```

### Run Tests in Parallel

```bash
go test -v -parallel 4 -timeout 30m
```

## Test Coverage

### Security Rule Module (`security_rule_test.go`)

- ✅ `TestSecurityRuleModule`: Basic allow rule creation
- ✅ `TestSecurityRuleModuleValidation`: Input validation (invalid action)
- ✅ `TestSecurityRuleDenyAction`: Drop/deny rules
- ✅ `TestSecurityRuleWithAllProfiles`: All security profiles configured

### NAT Rule Module (`nat_rule_test.go`)

- ✅ `TestNATRuleModuleSNAT`: Source NAT (outbound)
- ✅ `TestNATRuleModuleDNAT`: Destination NAT (inbound)
- ✅ `TestNATRuleModuleDisabled`: Disabled NAT rules

## CI/CD Integration

### GitHub Actions

```yaml
- name: Run Terratest
  working-directory: ./test
  run: |
    go mod download
    go test -v -timeout 30m
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

cd test
go test -v -short -timeout 10m

if [ $? -ne 0 ]; then
  echo "❌ Tests failed. Commit aborted."
  exit 1
fi
```

## Writing New Tests

### Template

```go
func TestMyNewModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform/modules/my-module",
		Vars: map[string]interface{}{
			"name": "test_rule",
			// ... other variables
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Assertions
	output := terraform.Output(t, terraformOptions, "name")
	assert.Equal(t, "test_rule", output)
}
```

## Cleanup

Terratest automatically cleans up resources via `defer terraform.Destroy(t, terraformOptions)`.

If a test fails and resources are left behind:

```bash
# Find orphaned resources
terraform state list

# Manual cleanup
cd ../terraform/modules/security-rule
terraform destroy
```

## Troubleshooting

### Test Timeout

```bash
# Increase timeout
go test -v -timeout 60m
```

### Module Not Found

```bash
cd test
go mod tidy
go mod download
```

### Terraform Init Failed

```bash
# Clear Terraform cache
cd ../terraform/modules/security-rule
rm -rf .terraform
```

## Best Practices

1. **Parallel Execution**: Use `t.Parallel()` for faster test runs
2. **Cleanup**: Always use `defer terraform.Destroy()`
3. **Timeouts**: Set realistic timeouts (30-60min for full suite)
4. **Assertions**: Use `assert` for clear error messages
5. **Idempotency**: Test `terraform apply` twice to ensure no changes

## Example Output

```
=== RUN   TestSecurityRuleModule
=== PAUSE TestSecurityRuleModule
=== RUN   TestSecurityRuleModuleValidation
=== PAUSE TestSecurityRuleModuleValidation
=== CONT  TestSecurityRuleModule
=== CONT  TestSecurityRuleModuleValidation
--- PASS: TestSecurityRuleModule (12.34s)
--- PASS: TestSecurityRuleModuleValidation (8.56s)
PASS
ok      github.com/kiru42/terraform-drift-demo/test     20.901s
```

## Further Reading

- [Terratest Documentation](https://terratest.gruntwork.io/docs/)
- [Testing Terraform Modules](https://www.terraform.io/docs/extend/testing/index.html)
- [Go Testing Package](https://pkg.go.dev/testing)
