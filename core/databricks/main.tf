resource "azurerm_databricks_workspace" "this" {
  name                        = var.name
  resource_group_name         = var.resource_group_name
  location                    = var.location
  sku                         = var.sku
  managed_resource_group_name = coalesce(var.managed_resource_group_name, "${var.name}-managed-rg")

  tags = var.tags
}
