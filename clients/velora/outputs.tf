output "resource_group_name" {
  value = data.azurerm_resource_group.this.name
}

output "location" {
  value = data.azurerm_resource_group.this.location
}

# ------------------------------------------------------------
# Tier 2 — Core (Key Vault, Log Analytics, ADLS)
# ------------------------------------------------------------

output "key_vault_id" {
  value = module.key_vault.id
}

output "key_vault_name" {
  value = module.key_vault.name
}

output "key_vault_uri" {
  value = module.key_vault.uri
}

output "log_analytics_workspace_id" {
  value = module.log_analytics.id
}

output "log_analytics_workspace_name" {
  value = module.log_analytics.name
}

output "adls_account_name" {
  value = module.adls.storage_account_name
}

output "adls_primary_dfs_endpoint" {
  value = module.adls.primary_dfs_endpoint
}

output "adls_filesystems" {
  value = module.adls.filesystem_ids
}

# ------------------------------------------------------------
# Tier 3 — Data plane (Postgres, Databricks, OpenAI, Azure SQL)
# ------------------------------------------------------------

output "postgres_fqdn" {
  value = module.postgres.fqdn
}

output "postgres_admin_login" {
  value = module.postgres.admin_login
}

output "databricks_workspace_name" {
  value = module.databricks.name
}

output "databricks_workspace_url" {
  value = module.databricks.workspace_url
}

output "openai_endpoint" {
  value = module.openai.endpoint
}

output "openai_deployment_names" {
  value = module.openai.deployment_names
}

output "sql_server_fqdn" {
  value = module.azure_sql_velora.server_fqdn
}

output "sql_database_name" {
  value = module.azure_sql_velora.database_name
}

output "sql_admin_login" {
  value = module.azure_sql_velora.admin_login
}
