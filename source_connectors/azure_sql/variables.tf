variable "server_name" {
  description = "SQL logical server name (globally unique DNS label)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$", var.server_name))
    error_message = "Server name must be 2-63 chars, lowercase alphanumeric + hyphens, start/end alphanumeric."
  }
}

variable "database_name" {
  description = "Database name on the logical server"
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "admin_login" {
  description = "SQL server admin login (password auth). Used only for bootstrap; AAD is preferred."
  type        = string
  default     = "pipelineiqadmin"
}

variable "aad_admin_login" {
  description = "UPN (or group displayName) to set as Azure AD admin on the SQL server"
  type        = string
}

variable "aad_admin_object_id" {
  description = "Object ID of the AAD principal set as admin"
  type        = string
}

variable "sku_name" {
  description = "Database SKU. GP_S_Gen5_2 = serverless, 2 vCore max (DECISIONS #6)."
  type        = string
  default     = "GP_S_Gen5_2"
}

variable "min_capacity" {
  description = "Minimum vCores while active. 0.5 = lowest serverless setting."
  type        = number
  default     = 0.5
}

variable "auto_pause_delay_in_minutes" {
  description = "Minutes of idle before auto-pause. 60 is default; set -1 to disable pause."
  type        = number
  default     = 60
}

variable "max_size_gb" {
  type    = number
  default = 32
}

variable "public_network_access_enabled" {
  type    = bool
  default = true
}

variable "current_ip" {
  description = "Public IPv4 to whitelist for local sqlcmd. null skips the rule."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
