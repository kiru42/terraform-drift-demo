package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestNATRuleModuleSNAT(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform/modules/nat-rule",
		Vars: map[string]interface{}{
			"name":                "test_snat_outbound",
			"source_address":      []string{"10.0.0.0/8"},
			"destination_address": []string{"any"},
			"service":             "any",
			"source_translation": map[string]interface{}{
				"type":              "dynamic-ip-and-port",
				"interface_address": "ethernet1/1",
			},
			"enabled":     true,
			"description": "Test SNAT for outbound traffic",
			"tags": map[string]string{
				"type": "snat",
				"env":  "test",
			},
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	ruleName := terraform.Output(t, terraformOptions, "name")
	assert.Equal(t, "test_snat_outbound", ruleName)
}

func TestNATRuleModuleDNAT(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform/modules/nat-rule",
		Vars: map[string]interface{}{
			"name":                "test_dnat_web_server",
			"source_address":      []string{"any"},
			"destination_address": []string{"203.0.113.10"},
			"service":             "tcp/80",
			"source_translation": map[string]interface{}{
				"type": "none",
			},
			"destination_translation": map[string]interface{}{
				"translated_address": "10.0.1.100",
				"translated_port":    8080,
			},
			"enabled":     true,
			"description": "Test DNAT for web server",
			"tags": map[string]string{
				"type": "dnat",
				"env":  "test",
			},
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	ruleName := terraform.Output(t, terraformOptions, "name")
	assert.Equal(t, "test_dnat_web_server", ruleName)
}

func TestNATRuleModuleDisabled(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform/modules/nat-rule",
		Vars: map[string]interface{}{
			"name":                "test_disabled_nat",
			"source_address":      []string{"10.0.0.0/8"},
			"destination_address": []string{"any"},
			"source_translation": map[string]interface{}{
				"type":              "dynamic-ip-and-port",
				"interface_address": "ethernet1/1",
			},
			"enabled":     false,
			"description": "Disabled NAT rule for testing",
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	ruleName := terraform.Output(t, terraformOptions, "name")
	assert.Equal(t, "test_disabled_nat", ruleName)
}
