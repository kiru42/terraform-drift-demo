variable "name" {
  description = "Name of the NAT rule"
  type        = string
}

variable "source_addresses" {
  description = "Source addresses"
  type        = list(string)
  default     = []
}

variable "destination_addresses" {
  description = "Destination addresses"
  type        = list(string)
  default     = []
}

variable "service" {
  description = "Service"
  type        = string
  default     = "any"
}

variable "source_translation" {
  description = "Source NAT configuration"
  type = object({
    type               = string
    interface_address  = optional(string)
    translated_address = optional(list(string))
  })
}

variable "destination_translation" {
  description = "Destination NAT configuration (DNAT only)"
  type = object({
    translated_address = string
    translated_port    = optional(number)
  })
  default = null
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

