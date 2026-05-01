variable "subscription_id" {
  description = "Azure subscription ID (Microsoft Azure Sponsorship)"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID (Sail Analytics)"
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group created by scripts/bootstrap_state.sh"
  type        = string
  default     = "pipelineiq-rg-dev"
}

variable "location" {
  description = "Primary region for data/pipeline resources. Per DECISIONS.md #10."
  type        = string
  default     = "centralindia"
}

variable "openai_location" {
  description = "Azure OpenAI region. Split from primary region per DECISIONS #25 — southindia is closest India region with OpenAI."
  type        = string
  default     = "southindia"
}

variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev, staging, prod."
  }
}

variable "client_name" {
  description = "Platform short name used as a prefix in resource naming"
  type        = string
  default     = "pipelineiq"
}

variable "log_retention_days" {
  description = "Log Analytics data retention"
  type        = number
  default     = 30
}

variable "kv_purge_protection_enabled" {
  description = "Key Vault purge protection. Cannot be disabled once enabled — keep false in dev."
  type        = bool
  default     = false
}

variable "current_user_upn" {
  description = "UPN of the identity running terraform. Set as AAD admin on PostgreSQL + Azure SQL."
  type        = string
}

variable "current_ip" {
  description = "Public IPv4 to whitelist for local psql/sqlcmd access. null skips whitelist (Azure-services rule still applies)."
  type        = string
  default     = null
}

variable "databricks_account_id" {
  description = "Databricks account UUID. Find it at https://accounts.azuredatabricks.net (top-right user menu → 'Account ID', or end of URL after login). One per Azure tenant."
  type        = string
}
