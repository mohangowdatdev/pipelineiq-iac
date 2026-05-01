terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
  }

  backend "azurerm" {
    resource_group_name  = "pipelineiq-rg-dev"
    storage_account_name = "pipelineiqtfstate"
    container_name       = "tfstate"
    key                  = "velora.tfstate"
  }
}
