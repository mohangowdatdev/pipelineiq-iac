terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    databricks = {
      source                = "databricks/databricks"
      version               = "~> 1.50"
      configuration_aliases = [databricks.workspace, databricks.accounts]
    }
  }
}
