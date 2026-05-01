variable "name_prefix" {
  description = "Prefix for resource names (e.g. 'pipelineiq-dev')"
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "workspace_id" {
  description = "Databricks workspace numeric ID (azurerm_databricks_workspace.workspace_id)"
  type        = string
}

variable "workspace_resource_id" {
  description = "Azure resource ID of the Databricks workspace"
  type        = string
}

variable "adls_account_id" {
  description = "Azure resource ID of the ADLS Gen2 storage account"
  type        = string
}

variable "adls_account_name" {
  description = "ADLS Gen2 storage account name (used in abfss:// URIs)"
  type        = string
}

variable "containers" {
  description = "ADLS filesystems to register as UC external locations"
  type        = list(string)
  default     = ["landing", "bronze", "silver", "gold", "quarantine"]
}

variable "catalogs" {
  description = "UC catalogs to create. Each is rooted at abfss://{name}@{adls}/."
  type        = list(string)
  default     = ["bronze", "silver", "gold"]
}

variable "key_vault_id" {
  description = "Resource ID of the Key Vault to back the secret scope with"
  type        = string
}

variable "key_vault_uri" {
  description = "DNS name of the Key Vault (https://*.vault.azure.net/)"
  type        = string
}

variable "metastore_id" {
  description = "ID of the existing UC metastore for the workspace's region. Use the system-created metastore (e.g. metastore_azure_centralindia)."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "sql_warehouse_size" {
  description = "Databricks SQL Warehouse t-shirt size"
  type        = string
  default     = "2X-Small"
}

variable "sql_warehouse_auto_stop_minutes" {
  type    = number
  default = 10
}

variable "cluster_policy_node_type" {
  type    = string
  default = "Standard_DS3_v2"
}

variable "cluster_policy_max_workers" {
  type    = number
  default = 2
}
