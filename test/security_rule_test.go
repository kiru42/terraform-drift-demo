package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestSecurityRuleModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform/modules/security-rule",
		Vars: map[string]interface{}{
			"name":        "test_allow_web",
			"source":      []string{"10.0.0.0/8"},
			"destination": []string{"any"},
			"service":     []string{"http", "https"},
			"action":      "allow",
			"enabled":     true,
			"description": "Test web access rule",
			"tags": map[string]string{
				"env":  "test",
				"team": "devops",
			},
			"log": map[string]interface{}{
				"at_session_start": false,
				"at_session_end":   true,
			},
			"security_profiles": map[string]string{
				"antivirus":     "strict-av",
				"anti_spyware":  "strict",
				"vulnerability": "strict",
			},
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	// Init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Validate outputs
	ruleName := terraform.Output(t, terraformOptions, "name")
	assert.Equal(t, "test_allow_web", ruleName)

	action := terraform.Output(t, terraformOptions, "action")
	assert.Equal(t, "allow", action)

	enabled := terraform.Output(t, terraformOptions, "enabled")
	assert.Equal(t, "true", enabled)
}

func TestSecurityRuleModuleValidation(t *testing.T) {
	t.Parallel()

	// Test invalid action
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform/modules/security-rule",
		Vars: map[string]interface{}{
			"name":        "test_invalid_action",
			"source":      []string{"10.0.0.0/8"},
			"destination": []string{"any"},
			"service":     []string{"http"},
			"action":      "invalid", // Should fail validation
			"enabled":     true,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	// This should fail during plan/apply
	_, err := terraform.InitAndApplyE(t, terraformOptions)
	assert.Error(t, err, "Should fail with invalid action")
	assert.Contains(t, err.Error(), "Action must be one of: allow, deny, drop")
}

func TestSecurityRuleDenyAction(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform/modules/security-rule",
		Vars: map[string]interface{}{
			"name":        "test_block_ssh",
			"source":      []string{"any"},
			"destination": []string{"10.0.0.0/8"},
			"service":     []string{"ssh"},
			"action":      "drop",
			"enabled":     true,
			"description": "Block external SSH",
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	action := terraform.Output(t, terraformOptions, "action")
	assert.Equal(t, "drop", action)
}

func TestSecurityRuleWithAllProfiles(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform/modules/security-rule",
		Vars: map[string]interface{}{
			"name":        "test_full_profiles",
			"source":      []string{"trust-zone"},
			"destination": []string{"dmz"},
			"service":     []string{"http", "https"},
			"action":      "allow",
			"enabled":     true,
			"security_profiles": map[string]string{
				"antivirus":      "strict-av",
				"anti_spyware":   "strict",
				"vulnerability":  "strict",
				"url_filtering":  "strict-url",
				"file_blocking":  "strict-file-blocking",
				"wildfire":       "strict-wildfire",
				"data_filtering": "pci-dss-dlp",
			},
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	ruleName := terraform.Output(t, terraformOptions, "name")
	assert.Equal(t, "test_full_profiles", ruleName)
}
