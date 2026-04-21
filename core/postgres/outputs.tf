output "id" {
  value = azurerm_postgresql_flexible_server.this.id
}

output "name" {
  value = azurerm_postgresql_flexible_server.this.name
}

output "fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}

output "admin_login" {
  value = azurerm_postgresql_flexible_server.this.administrator_login
}

output "admin_password" {
  value     = random_password.admin.result
  sensitive = true
}
