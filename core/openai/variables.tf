variable "name" {
  description = "Azure OpenAI account name. Doubles as custom_subdomain_name (globally unique DNS label)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]$", var.name))
    error_message = "Name must be 2-64 chars, lowercase alphanumeric + hyphens, must start and end alphanumeric."
  }
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  description = "Azure OpenAI region. PipelineIQ uses southindia (DECISIONS #25)."
  type        = string
  default     = "southindia"
}

variable "sku_name" {
  description = "Cognitive Services SKU. S0 is the only current production SKU for OpenAI."
  type        = string
  default     = "S0"
}

variable "public_network_access_enabled" {
  type    = bool
  default = true
}

variable "deployments" {
  description = "Map of deployment_name => { model_name, model_version, sku_name, capacity }."
  type = map(object({
    model_name    = string
    model_version = string
    sku_name      = string
    capacity      = number
  }))
  default = {
    "gpt-4o" = {
      model_name    = "gpt-4o"
      model_version = "2024-11-20"
      sku_name      = "Standard"
      capacity      = 10
    }
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
