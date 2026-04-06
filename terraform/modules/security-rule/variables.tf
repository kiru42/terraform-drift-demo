variable "name" {
  description = "Name of the security rule"
  type        = string
}

variable "source_addresses" {
  description = "Source addresses/zones"
  type        = list(string)
  default     = []
}

variable "destination_addresses" {
  description = "Destination addresses/zones"
  type        = list(string)
  default     = []
}

variable "service" {
  description = "Services (ports/protocols)"
  type        = list(string)
  default     = ["application-default"]
}

variable "application" {
  description = "Applications"
  type        = list(string)
  default     = ["any"]
}

variable "action" {
  description = "Action to take (allow/deny/drop)"
  type        = string
  
  validation {
    condition     = contains(["allow", "deny", "drop"], var.action)
    error_message = "Action must be one of: allow, deny, drop"
  }
}

variable "enabled" {
  description = "Whether the rule is enabled"
  type        = bool
  default     = true
}

variable "description" {
  description = "Rule description"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags for the rule"
  type        = map(string)
  default     = {}
}

variable "log" {
  description = "Logging configuration"
  type = object({
    at_session_start = bool
    at_session_end   = bool
    log_forwarding   = optional(string)
  })
  default = {
    at_session_start = false
    at_session_end   = true
    log_forwarding   = null
  }
}

variable "schedule" {
  description = "Schedule name (optional)"
  type        = string
  default     = null
}

variable "negate" {
  description = "Negate source/destination"
  type = object({
    source      = bool
    destination = bool
  })
  default = {
    source      = false
    destination = false
  }
}

variable "hip_profiles" {
  description = "Host Information Profile (HIP) profiles"
  type        = list(string)
  default     = []
}

# Security Profiles (legacy flat structure)
variable "antivirus" {
  description = "Antivirus profile name"
  type        = string
  default     = null
}

variable "anti_spyware" {
  description = "Anti-spyware profile name"
  type        = string
  default     = null
}

variable "vulnerability" {
  description = "Vulnerability protection profile name"
  type        = string
  default     = null
}

variable "url_filtering" {
  description = "URL filtering profile (string or object)"
  type        = any
  default     = null
}

variable "file_blocking" {
  description = "File blocking profile name"
  type        = string
  default     = null
}

variable "wildfire" {
  description = "WildFire analysis profile name"
  type        = string
  default     = null
}

variable "data_filtering" {
  description = "Data filtering profile name"
  type        = string
  default     = null
}

# Security Profiles (structured object, preferred)
variable "security_profiles" {
  description = "Security profiles (structured object, overrides individual profile vars)"
  type = object({
    antivirus      = optional(string)
    anti_spyware   = optional(string)
    vulnerability  = optional(string)
    url_filtering  = optional(string)
    file_blocking  = optional(string)
    wildfire       = optional(string)
    data_filtering = optional(string)
  })
  default = null
}
