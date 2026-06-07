variable "name" {
  description = "Data Factory name (3-63 chars, globally unique). Pattern: pipelineiq-adf-{env}."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

# ── Targets the ADF managed identity needs to reach ────────────────────────
# ADF authenticates to each of these with its system-assigned MI. The role
# assignments below are what make the Bicep linked services (deployed
# separately) actually able to read/write at runtime.

variable "adls_account_id" {
  description = "Resource ID of the ADLS Gen2 account ADF writes landing Parquet into. Needs Storage Blob Data Contributor."
  type        = string
}

variable "key_vault_id" {
  description = "Resource ID of the Key Vault holding sql-connection-string. ADF's KV linked service resolves secrets via its MI — needs Key Vault Secrets User."
  type        = string
}

variable "databricks_workspace_id" {
  description = "Resource ID of the Databricks workspace ADF orchestrates (chunk 2 notebook activities). MSI linked service needs Contributor on the workspace."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace (pipelineiq-logs-dev) ADF pipeline/activity/trigger run logs stream to. Required for Phase 3 failure detection. build_order 6.6."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
