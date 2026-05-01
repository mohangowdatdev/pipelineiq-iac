# ------------------------------------------------------------
# Access connector — managed identity used by UC to read/write ADLS.
# ------------------------------------------------------------

resource "azurerm_databricks_access_connector" "this" {
  name                = "${var.name_prefix}-dbx-ac"
  resource_group_name = var.resource_group_name
  location            = var.location

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "ac_blob_contributor" {
  scope                = var.adls_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.this.identity[0].principal_id
}

# ------------------------------------------------------------
# Unity Catalog metastore — adopt the auto-created system metastore
# (Databricks limit: 1 per region per account; centralindia already
# has `metastore_azure_centralindia` auto-assigned to the workspace).
# ------------------------------------------------------------

data "databricks_metastore" "this" {
  provider     = databricks.accounts
  metastore_id = var.metastore_id
}

# ------------------------------------------------------------
# Storage credential (workspace-scoped binding to the access connector).
# ------------------------------------------------------------

resource "databricks_storage_credential" "this" {
  provider = databricks.workspace

  name    = "${var.name_prefix}-sc"
  comment = "ADLS access via Databricks access connector managed identity"

  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.this.id
  }

  depends_on = [
    azurerm_role_assignment.ac_blob_contributor,
  ]
}

# ------------------------------------------------------------
# External locations — one per ADLS filesystem.
# ------------------------------------------------------------

resource "databricks_external_location" "this" {
  provider = databricks.workspace
  for_each = toset(var.containers)

  name            = "${each.value}-loc"
  url             = "abfss://${each.value}@${var.adls_account_name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.this.name
  comment         = "External location for ${each.value} filesystem"
}

# ------------------------------------------------------------
# UC catalogs — bronze / silver / gold.
# ------------------------------------------------------------

resource "databricks_catalog" "this" {
  provider = databricks.workspace
  for_each = toset(var.catalogs)

  name         = each.value
  storage_root = "abfss://${each.value}@${var.adls_account_name}.dfs.core.windows.net/"
  comment      = "${title(each.value)} medallion layer"

  depends_on = [databricks_external_location.this]
}

# ------------------------------------------------------------
# Jobs Compute cluster policy (DS3_v2, auto-terminate 30 min).
# ------------------------------------------------------------

resource "databricks_cluster_policy" "jobs" {
  provider = databricks.workspace

  name = "${var.name_prefix}-jobs-policy"

  definition = jsonencode({
    "spark_version" : {
      "type" : "fixed",
      "value" : "14.3.x-scala2.12"
    },
    "node_type_id" : {
      "type" : "fixed",
      "value" : var.cluster_policy_node_type
    },
    "driver_node_type_id" : {
      "type" : "fixed",
      "value" : var.cluster_policy_node_type
    },
    "autotermination_minutes" : {
      "type" : "fixed",
      "value" : 30
    },
    "autoscale.min_workers" : {
      "type" : "fixed",
      "value" : 1
    },
    "autoscale.max_workers" : {
      "type" : "range",
      "minValue" : 1,
      "maxValue" : var.cluster_policy_max_workers,
      "defaultValue" : var.cluster_policy_max_workers
    },
    "data_security_mode" : {
      "type" : "fixed",
      "value" : "SINGLE_USER"
    },
  })
}

# ------------------------------------------------------------
# SQL Warehouse — 2X-Small Classic, auto-stop 10 min.
# ------------------------------------------------------------

resource "databricks_sql_endpoint" "this" {
  provider = databricks.workspace

  name                      = "${var.name_prefix}-sqlwh"
  cluster_size              = var.sql_warehouse_size
  auto_stop_mins            = var.sql_warehouse_auto_stop_minutes
  warehouse_type            = "CLASSIC"
  enable_serverless_compute = false
  max_num_clusters          = 1

  tags {
    custom_tags {
      key   = "project"
      value = "pipelineiq"
    }
  }
}

# ------------------------------------------------------------
# Key-Vault-backed secret scope.
# ------------------------------------------------------------

resource "databricks_secret_scope" "kv" {
  provider = databricks.workspace

  name = "${var.name_prefix}-kv"

  keyvault_metadata {
    resource_id = var.key_vault_id
    dns_name    = var.key_vault_uri
  }
}
