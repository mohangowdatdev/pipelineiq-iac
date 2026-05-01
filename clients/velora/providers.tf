provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }

    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Workspace-scoped provider — for cluster policy, SQL warehouse, secret scope,
# storage credential, external locations, catalogs (post-attachment).
# Uses az CLI auth — running principal must be a workspace user/admin.
provider "databricks" {
  alias     = "workspace"
  host      = module.databricks.workspace_url
  auth_type = "azure-cli"
}

# Account-scoped provider — for metastore creation and assignment.
# Uses az CLI auth — running principal must be a Databricks Account Admin.
provider "databricks" {
  alias      = "accounts"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
  auth_type  = "azure-cli"
}
