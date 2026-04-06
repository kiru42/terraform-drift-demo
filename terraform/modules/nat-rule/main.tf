/**
 * NAT Rule Module
 * 
 * Creates a NAT policy rule (SNAT/DNAT).
 */

terraform {
  required_version = ">= 1.0"
}

resource "null_resource" "nat_rule" {
  triggers = {
    name                    = var.name
    source_addresses        = jsonencode(var.source_addresses)
    destination_addresses   = jsonencode(var.destination_addresses)
    service              = var.service
    source_translation   = jsonencode(var.source_translation)
    destination_translation = var.destination_translation != null ? jsonencode(var.destination_translation) : null
    enabled              = var.enabled
    description          = var.description
    tags                 = jsonencode(var.tags)
  }

  provisioner "local-exec" {
    command = "echo 'NAT rule ${var.name} configured'"
  }
}
