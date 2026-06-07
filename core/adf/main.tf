# ------------------------------------------------------------
# Azure Data Factory — pipelineiq-adf-dev.
#
# Tier 6 orchestration backbone. This module owns ONLY the factory
# resource + its managed-identity RBAC. The ADF-internal objects
# (linked services, datasets, pipelines) are Bicep, deployed
# out-of-band via scripts/deploy_adf.sh — same split as the bronze/
# silver/gold notebooks (Terraform owns the compute, scripts deploy
# the artifacts). build_order 6.1.
#
# Git integration is intentionally DISABLED: we author ADF objects as
# Bicep in the IaC repo, not via the ADF Studio Git mode. The factory
# stays in "live" mode and `az deployment group create` is the single
# publish path.
# ------------------------------------------------------------

resource "azurerm_data_factory" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  # System-assigned MI — the principal every linked service authenticates
  # as (ADLS via MI, Key Vault via MI, Databricks via MSI).
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# ------------------------------------------------------------
# RBAC — what the factory MI can reach.
# ------------------------------------------------------------

# Write landing Parquet into ADLS Gen2.
resource "azurerm_role_assignment" "adf_adls_blob_contributor" {
  scope                = var.adls_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
}

# Resolve sql-connection-string (and any future secrets) from Key Vault
# via the AzureKeyVault linked service.
resource "azurerm_role_assignment" "adf_kv_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
}

# Orchestrate Databricks notebook runs (chunk 2). MSI linked service to
# Databricks requires Contributor on the workspace resource; the MI is
# additionally surfaced as a workspace user the first time ADF calls the
# Databricks REST API.
resource "azurerm_role_assignment" "adf_databricks_contributor" {
  scope                = var.databricks_workspace_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
}

# ------------------------------------------------------------
# Diagnostics — stream pipeline/activity/trigger runs to Log Analytics
# (pipelineiq-logs-dev). Phase 3 failure detection reads ADF run failures
# from here. build_order 6.6.
# ------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "adf" {
  name                       = "${var.name}-diagnostics"
  target_resource_id         = azurerm_data_factory.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "PipelineRuns"
  }

  enabled_log {
    category = "ActivityRuns"
  }

  enabled_log {
    category = "TriggerRuns"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
