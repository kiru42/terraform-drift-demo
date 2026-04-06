terraform {
  required_version = ">= 1.0"
  
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Variables
variable "api_endpoint" {
  description = "Mock Panorama API endpoint"
  type        = string
  default     = "http://localhost:3000"
}

variable "desired_config_file" {
  description = "Path to desired configuration JSON file"
  type        = string
  default     = "desired-config.json"
}

# Load desired configuration
locals {
  desired_config = jsondecode(file(var.desired_config_file))
  config_json    = jsonencode(local.desired_config)
  config_hash    = md5(local.config_json)
}

# Drift detection and configuration apply
resource "null_resource" "panorama_config" {
  triggers = {
    config_hash = local.config_hash
    # Force check on every run
    always_run = timestamp()
  }

  # Step 1: Fetch current config and detect drift
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo "==================================="
      echo "DRIFT DETECTION"
      echo "==================================="
      
      # Fetch current config from API
      CURRENT_CONFIG=$(curl -s ${var.api_endpoint}/config | jq -r '.data.policies')
      CURRENT_HASH=$(echo "$CURRENT_CONFIG" | md5sum | cut -d' ' -f1)
      
      DESIRED_POLICIES=$(cat ${var.desired_config_file} | jq -r '.policies')
      DESIRED_HASH=$(echo "$DESIRED_POLICIES" | md5sum | cut -d' ' -f1)
      
      echo "Desired config hash: $DESIRED_HASH"
      echo "Current config hash: $CURRENT_HASH"
      
      if [ "$DESIRED_HASH" != "$CURRENT_HASH" ]; then
        echo "⚠️  DRIFT DETECTED!"
        echo "Configuration has diverged from desired state"
        echo ""
        echo "Differences:"
        echo "Desired:" > /tmp/desired.json
        echo "$DESIRED_POLICIES" | jq '.' >> /tmp/desired.json
        echo "Current:" > /tmp/current.json
        echo "$CURRENT_CONFIG" | jq '.' >> /tmp/current.json
        diff /tmp/desired.json /tmp/current.json || true
      else
        echo "✅ No drift detected"
      fi
    EOT
    
    interpreter = ["bash", "-c"]
  }

  # Step 2: Validate policy before apply
  provisioner "local-exec" {
    command = "${path.module}/../scripts/validate-policy.sh ${var.desired_config_file}"
  }

  # Step 3: Push configuration to API
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e
      
      echo ""
      echo "==================================="
      echo "APPLYING CONFIGURATION"
      echo "==================================="
      
      RESPONSE=$(curl -X POST ${var.api_endpoint}/config \
        -H "Content-Type: application/json" \
        -d @${var.desired_config_file} \
        -s -w "\n%{http_code}")
      
      HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
      BODY=$(echo "$RESPONSE" | sed '$d')
      
      if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Configuration applied successfully"
        echo "$BODY" | jq '.'
      else
        echo "❌ Failed to apply configuration (HTTP $HTTP_CODE)"
        echo "$BODY"
        exit 1
      fi
    EOT
    
    interpreter = ["bash", "-c"]
  }
}

# Outputs
output "config_hash" {
  description = "Hash of desired configuration"
  value       = local.config_hash
}

output "policy_count" {
  description = "Number of security policies in desired config"
  value       = length(local.desired_config.policies.security)
}

output "api_endpoint" {
  description = "Mock Panorama API endpoint"
  value       = var.api_endpoint
}
