output "id" {
  value = azurerm_data_factory.this.id
}

output "name" {
  value = azurerm_data_factory.this.name
}

output "principal_id" {
  description = "Object ID of the Data Factory's system-assigned managed identity."
  value       = azurerm_data_factory.this.identity[0].principal_id
}

output "tenant_id" {
  value = azurerm_data_factory.this.identity[0].tenant_id
}
