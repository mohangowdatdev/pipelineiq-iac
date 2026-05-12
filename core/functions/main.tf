# ------------------------------------------------------------
# Storage account — required by the Functions runtime for triggers,
# logging, binding state, AND (Flex Consumption only) the deployment
# package container that the platform downloads code from.
# ------------------------------------------------------------

resource "azurerm_storage_account" "func_runtime" {
  # Storage account names: 3-24 lowercase + digits, globally unique.
  # Derive from the function name with non-alphanum stripped.
  name                = substr(replace(replace(lower(var.name), "-", ""), "_", ""), 0, 24)
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = "Standard"
  account_replication_type = var.storage_account_replication_type
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = var.tags
}

# Flex Consumption requires a private blob container for the deployment
# package. The platform pulls the ZIP from this container at host start.
resource "azurerm_storage_container" "deployment_package" {
  name                  = "app-package-${var.name}"
  storage_account_id    = azurerm_storage_account.func_runtime.id
  container_access_type = "private"
}

# ------------------------------------------------------------
# App Service plan — Flex Consumption (FC1, Linux).
#
# Replaces the previous Y1 (Linux Consumption) plan. Same scale-to-zero
# economics, but timer triggers fire reliably (Y1 + Linux + non-HTTP
# triggers is the documented sad path).
# ------------------------------------------------------------

resource "azurerm_service_plan" "this" {
  name                = "${var.name}-plan"
  resource_group_name = var.resource_group_name
  location            = var.location

  os_type  = "Linux"
  sku_name = "FC1" # Flex Consumption

  tags = var.tags
}

# ------------------------------------------------------------
# Application Insights — wired to the existing Log Analytics workspace.
# ------------------------------------------------------------

resource "azurerm_application_insights" "this" {
  name                = "${var.name}-ai"
  resource_group_name = var.resource_group_name
  location            = var.location
  application_type    = "web"
  workspace_id        = var.log_analytics_workspace_id

  tags = var.tags
}

# ------------------------------------------------------------
# Function App — Flex Consumption (FC1).
#
# Why Flex Consumption (not Y1 Linux Consumption): Y1 timer triggers
# silently miss scheduled fires when the host scales to zero on Linux.
# Flex Consumption is Microsoft's documented replacement that fires
# non-HTTP triggers reliably while preserving scale-to-zero economics.
# Cost remains effectively zero for our once-a-day generator workload
# (well under the 100K GB-s/month free grant).
# ------------------------------------------------------------

resource "azurerm_function_app_flex_consumption" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  service_plan_id = azurerm_service_plan.this.id

  # Deployment package — Flex pulls the user code ZIP from this private
  # blob container. Auth via storage-account key (simplest; the runtime
  # storage account is dedicated to this Function App and not shared).
  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.func_runtime.primary_blob_endpoint}${azurerm_storage_container.deployment_package.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.func_runtime.primary_access_key

  runtime_name    = "python"
  runtime_version = "3.11"

  # Memory + max scale. 2048 MB is the Flex default and matches the old
  # Y1 footprint of the daily generator (peak ~512 MB observed S5).
  instance_memory_in_mb  = 2048
  maximum_instance_count = 40

  https_only = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.this.connection_string
    application_insights_key               = azurerm_application_insights.this.instrumentation_key
  }

  app_settings = merge(
    {
      # App Insights — explicit env vars in addition to site_config wiring,
      # so the Python worker picks them up regardless of host version.
      "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.this.connection_string
      "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.this.instrumentation_key

      "AzureWebJobsFeatureFlags"        = "EnableWorkerIndexing"
      "PYTHON_ENABLE_WORKER_EXTENSIONS" = "1"
      "KEY_VAULT_URI"                   = var.key_vault_uri
    },
    var.app_settings,
  )

  tags = var.tags
}

# ------------------------------------------------------------
# Grant the Function App's MSI read access to Key Vault secrets.
# ------------------------------------------------------------

resource "azurerm_role_assignment" "func_kv_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

# ------------------------------------------------------------
# Diagnostic settings — platform-side host logs to LA workspace.
#
# Separate observability layer from App Insights (which carries user-code
# traces). FunctionAppLogs captures host startup, function-host-worker
# lifecycle, and any platform-side termination events. Critical for
# diagnosing the host-side worker reaping we hit on 2026-05-11 / 5-12 fires
# where the Python worker died silently mid-inventory-write with no
# user-code exception emitted.
# ------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "function_app" {
  name                       = "${var.name}-diagnostics"
  target_resource_id         = azurerm_function_app_flex_consumption.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FunctionAppLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
