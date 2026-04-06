/**
 * Development Environment
 * 
 * Minimal restrictions for local development and testing.
 */

terraform {
  required_version = ">= 1.5.0"
  
  # Dev can use local state for simplicity
  # Or remote state:
  # backend "s3" {
  #   bucket = "my-terraform-state-dev"
  #   key    = "firewall/dev/terraform.tfstate"
  #   region = "eu-west-1"
  # }
  
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

locals {
  firewall_config = yamldecode(file("${path.module}/firewall-rules.yaml"))
  
  security_rules_map = {
    for rule in local.firewall_config.security_rules :
    rule.name => rule
  }
}

module "security_rules" {
  source = "../../modules/security-rule"
  
  for_each = local.security_rules_map
  
  name                  = each.value.name
  source_addresses      = each.value.source
  destination_addresses = each.value.destination
  service     = each.value.service
  application = lookup(each.value, "application", ["any"])
  action      = each.value.action
  enabled     = each.value.enabled
  description = lookup(each.value, "description", "")
  tags        = lookup(each.value, "tags", {})
  
  log = {
    at_session_start = false
    at_session_end   = false
    log_forwarding   = null
  }
  
  # No security profiles in dev (faster testing)
  security_profiles = null
}

output "environment" {
  value = "development"
}

output "security_rules_count" {
  value = length(module.security_rules)
}
