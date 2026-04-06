output "name" {
  description = "Rule name"
  value       = var.name
}

output "action" {
  description = "Rule action"
  value       = var.action
}

output "enabled" {
  description = "Whether rule is enabled"
  value       = var.enabled
}

output "rule_id" {
  description = "Unique identifier for this rule"
  value       = null_resource.security_rule.id
}

