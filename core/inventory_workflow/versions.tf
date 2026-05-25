terraform {
  required_version = ">= 1.6"

  required_providers {
    databricks = {
      source                = "databricks/databricks"
      version               = "~> 1.50"
      configuration_aliases = [databricks.workspace]
    }
  }
}
