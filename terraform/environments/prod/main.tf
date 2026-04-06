/**
 * Production Environment
 *
 * Strict security policies with full logging and compliance.
 */

terraform {
  required_version = ">= 1.5.0"

  # Production uses remote state backend
  backend "s3" {
    bucket         = "my-terraform-state-prod"
    key            = "firewall/prod/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks-prod"
    encrypt        = true
  }

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Load production firewall rules
locals {
  firewall_config = yamldecode(file("${path.module}/firewall-rules.yaml"))

  security_rules_map = {
    for rule in local.firewall_config.security_rules :
    rule.name => rule
  }
}

# Security Rules
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
    at_session_start = lookup(each.value.log, "at_session_start", false)
    at_session_end   = lookup(each.value.log, "at_session_end", true)
    log_forwarding   = lookup(each.value.log, "log_forwarding", "prod-siem")
  }

  security_profiles = lookup(each.value, "security_profiles", null) != null ? {
    antivirus      = lookup(each.value.security_profiles, "antivirus", null)
    anti_spyware   = lookup(each.value.security_profiles, "antiSpyware", null)
    vulnerability  = lookup(each.value.security_profiles, "vulnerability", null)
    url_filtering  = lookup(each.value.security_profiles, "urlFiltering", null)
    file_blocking  = lookup(each.value.security_profiles, "fileBlocking", null)
    wildfire       = lookup(each.value.security_profiles, "wildfire", null)
    data_filtering = lookup(each.value.security_profiles, "dataFiltering", null)
  } : null
}

# Outputs
output "environment" {
  value = "production"
}

output "security_rules_count" {
  value = length(module.security_rules)
}

output "allow_rules_count" {
  value = length([for rule in local.security_rules_map : rule if rule.action == "allow"])
}

