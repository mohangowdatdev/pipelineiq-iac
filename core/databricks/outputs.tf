output "id" {
  value = azurerm_databricks_workspace.this.id
}

output "name" {
  value = azurerm_databricks_workspace.this.name
}

output "workspace_url" {
  description = "Full https:// URL to the workspace"
  value       = "https://${azurerm_databricks_workspace.this.workspace_url}"
}

output "workspace_id" {
  description = "Databricks numeric workspace ID (used by databricks provider)"
  value       = azurerm_databricks_workspace.this.workspace_id
}

output "managed_resource_group_id" {
  value = azurerm_databricks_workspace.this.managed_resource_group_id
}
