variable "name" {
  description = "Databricks workspace name"
  type        = string

  validation {
    condition     = length(var.name) >= 3 && length(var.name) <= 30
    error_message = "Workspace name must be 3-30 chars."
  }
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku" {
  description = "Workspace SKU. Premium required for Unity Catalog + audit logs (DECISIONS #4)."
  type        = string
  default     = "premium"

  validation {
    condition     = contains(["standard", "premium", "trial"], var.sku)
    error_message = "sku must be standard, premium, or trial."
  }
}

variable "managed_resource_group_name" {
  description = "Azure creates a second RG for workspace internals. null = auto-named '{workspace}-managed-rg'."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
