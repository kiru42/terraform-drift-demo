output "name" {
  description = "NAT rule name"
  value       = var.name
}

output "rule_id" {
  description = "Unique identifier for this NAT rule"
  value       = null_resource.nat_rule.id
}
