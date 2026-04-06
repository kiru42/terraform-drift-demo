/**
 * Security Rule Module
 * 
 * Creates a firewall security policy rule with optional security profiles.
 */

terraform {
  required_version = ">= 1.0"
}

locals {
  # Merge security profiles from both possible locations
  security_profiles = coalesce(
    var.security_profiles,
    var.antivirus != null ? {
      antivirus       = var.antivirus
      anti_spyware    = var.anti_spyware
      vulnerability   = var.vulnerability
      url_filtering   = var.url_filtering
      file_blocking   = var.file_blocking
      wildfire        = var.wildfire
      data_filtering  = var.data_filtering
    } : null
  )
}

resource "null_resource" "security_rule" {
  triggers = {
    name            = var.name
    source          = jsonencode(var.source)
    destination     = jsonencode(var.destination)
    service         = jsonencode(var.service)
    application     = jsonencode(var.application)
    action          = var.action
    enabled         = var.enabled
    description     = var.description
    tags            = jsonencode(var.tags)
    log_start       = var.log.at_session_start
    log_end         = var.log.at_session_end
    log_forwarding  = var.log.log_forwarding
    schedule        = var.schedule
    negate_source   = var.negate.source
    negate_dest     = var.negate.destination
    hip_profiles    = jsonencode(var.hip_profiles)
    
    # Security profiles
    antivirus      = try(local.security_profiles.antivirus, null)
    anti_spyware   = try(local.security_profiles.anti_spyware, null)
    vulnerability  = try(local.security_profiles.vulnerability, null)
    url_filtering  = try(local.security_profiles.url_filtering, null)
    file_blocking  = try(local.security_profiles.file_blocking, null)
    wildfire       = try(local.security_profiles.wildfire, null)
    data_filtering = try(local.security_profiles.data_filtering, null)
  }

  provisioner "local-exec" {
    command = "echo 'Security rule ${var.name} configured'"
  }
}
