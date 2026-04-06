/**
 * Terraform Drift Detection Demo - Modular Configuration
 *
 * This is the production-ready refactored version using:
 * - Reusable modules (security-rule, nat-rule)
 * - YAML configuration (firewall-rules.yaml)
 * - Terraform for_each loops for DRY code
 * - Proper separation of concerns
 */

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Load firewall rules from YAML
locals {
  firewall_config = yamldecode(file("${path.module}/firewall-rules.yaml"))

  # Convert list to map for for_each
  security_rules_map = {
    for rule in local.firewall_config.security_rules :
    rule.name => rule
  }
}

# Security Rules using module
module "security_rules" {
  source = "./modules/security-rule"

  for_each = local.security_rules_map

  name                  = each.value.name
  source_addresses      = each.value.source
  destination_addresses = each.value.destination
  service               = each.value.service
  application           = lookup(each.value, "application", ["any"])
  action                = each.value.action
  enabled               = each.value.enabled
  description           = lookup(each.value, "description", "")
  tags                  = lookup(each.value, "tags", {})

  log = {
    at_session_start = lookup(each.value.log, "at_session_start", false)
    at_session_end   = lookup(each.value.log, "at_session_end", true)
    log_forwarding   = lookup(each.value.log, "log_forwarding", null)
  }

  # Security profiles (if present)
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

# Outputs for policy inventory
output "security_rules_count" {
  description = "Total number of security rules"
  value       = length(module.security_rules)
}

output "security_rules_names" {
  description = "List of all security rule names"
  value       = [for rule in module.security_rules : rule.name]
}

output "allow_rules_count" {
  description = "Number of allow rules"
  value       = length([for rule in local.security_rules_map : rule if rule.action == "allow"])
}

output "deny_rules_count" {
  description = "Number of deny/drop rules"
  value       = length([for rule in local.security_rules_map : rule if contains(["deny", "drop"], rule.action)])
}

