data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  common_tags = {
    project     = "pipelineiq"
    environment = var.environment
    owner       = "data-engineering"
    managed_by  = "terraform"
    client      = "velora"
  }

  name_prefix = var.client_name
  name_suffix = var.environment
}

module "key_vault" {
  source = "../../core/keyvault"

  name                       = "${local.name_prefix}-kv-${local.name_suffix}"
  resource_group_name        = data.azurerm_resource_group.this.name
  location                   = data.azurerm_resource_group.this.location
  tenant_id                  = var.tenant_id
  purge_protection_enabled   = var.kv_purge_protection_enabled
  soft_delete_retention_days = 7

  tags = local.common_tags
}

module "log_analytics" {
  source = "../../core/log_analytics"

  name                = "${local.name_prefix}-logs-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  retention_days      = var.log_retention_days

  tags = local.common_tags
}

module "adls" {
  source = "../../core/adls"

  name                = "${local.name_prefix}adls${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  containers          = ["landing", "bronze", "silver", "gold", "quarantine"]

  tags = local.common_tags
}

module "postgres" {
  source = "../../core/postgres"

  name                        = "${local.name_prefix}-pg-${local.name_suffix}"
  resource_group_name         = data.azurerm_resource_group.this.name
  location                    = data.azurerm_resource_group.this.location
  current_user_principal_name = var.current_user_upn
  current_ip                  = var.current_ip

  tags = local.common_tags
}

module "databricks" {
  source = "../../core/databricks"

  name                = "${local.name_prefix}-dbx-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location

  tags = local.common_tags
}

module "azure_sql_velora" {
  source = "../../source_connectors/azure_sql"

  server_name         = "${local.name_prefix}-sql-velora-${local.name_suffix}"
  database_name       = "velora_oms"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location

  aad_admin_login     = var.current_user_upn
  aad_admin_object_id = data.azurerm_client_config.current.object_id

  current_ip = var.current_ip

  tags = local.common_tags
}

module "openai" {
  source = "../../core/openai"

  name                = "${local.name_prefix}-openai-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = var.openai_location

  tags = local.common_tags
}

module "databricks_uc" {
  source = "../../core/databricks_uc"

  providers = {
    databricks.workspace = databricks.workspace
    databricks.accounts  = databricks.accounts
  }

  name_prefix         = "${local.name_prefix}-${local.name_suffix}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location

  workspace_id          = module.databricks.workspace_id
  workspace_resource_id = module.databricks.id

  adls_account_id   = module.adls.id
  adls_account_name = module.adls.storage_account_name

  key_vault_id  = module.key_vault.id
  key_vault_uri = module.key_vault.uri

  # Adopt the auto-created system metastore for centralindia (1-per-region limit).
  metastore_id = "a2d5ffb1-1ac9-42ec-babb-80eacf4ba2fb"

  tags = local.common_tags

  depends_on = [
    module.databricks,
    module.adls,
    module.key_vault,
  ]
}

resource "azurerm_key_vault_secret" "postgres_admin_password" {
  name         = "postgres-admin-password"
  value        = module.postgres.admin_password
  key_vault_id = module.key_vault.id

  depends_on = [module.key_vault]
}

resource "azurerm_key_vault_secret" "postgres_connection_string" {
  name         = "postgres-connection-string"
  value        = "host=${module.postgres.fqdn} port=5432 dbname=postgres user=${module.postgres.admin_login} password=${module.postgres.admin_password} sslmode=require"
  key_vault_id = module.key_vault.id

  depends_on = [module.key_vault]
}

resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = module.azure_sql_velora.admin_password
  key_vault_id = module.key_vault.id

  depends_on = [module.key_vault]
}

resource "azurerm_key_vault_secret" "sql_connection_string" {
  name         = "sql-connection-string"
  value        = "Server=tcp:${module.azure_sql_velora.server_fqdn},1433;Initial Catalog=${module.azure_sql_velora.database_name};User ID=${module.azure_sql_velora.admin_login};Password=${module.azure_sql_velora.admin_password};Encrypt=true;TrustServerCertificate=false;"
  key_vault_id = module.key_vault.id

  depends_on = [module.key_vault]
}

resource "azurerm_key_vault_secret" "openai_api_key" {
  name         = "openai-api-key"
  value        = module.openai.primary_access_key
  key_vault_id = module.key_vault.id

  depends_on = [module.key_vault]
}

resource "azurerm_key_vault_secret" "openai_endpoint" {
  name         = "openai-endpoint"
  value        = module.openai.endpoint
  key_vault_id = module.key_vault.id

  depends_on = [module.key_vault]
}
