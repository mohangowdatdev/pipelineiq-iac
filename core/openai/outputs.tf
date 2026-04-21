output "id" {
  value = azurerm_cognitive_account.this.id
}

output "name" {
  value = azurerm_cognitive_account.this.name
}

output "endpoint" {
  value = azurerm_cognitive_account.this.endpoint
}

output "primary_access_key" {
  value     = azurerm_cognitive_account.this.primary_access_key
  sensitive = true
}

output "deployment_names" {
  value = [for k, _ in azurerm_cognitive_deployment.this : k]
}
