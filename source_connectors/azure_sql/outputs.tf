output "server_id" {
  value = azurerm_mssql_server.this.id
}

output "server_name" {
  value = azurerm_mssql_server.this.name
}

output "server_fqdn" {
  value = azurerm_mssql_server.this.fully_qualified_domain_name
}

output "database_id" {
  value = azurerm_mssql_database.this.id
}

output "database_name" {
  value = azurerm_mssql_database.this.name
}

output "admin_login" {
  value = azurerm_mssql_server.this.administrator_login
}

output "admin_password" {
  value     = random_password.sa.result
  sensitive = true
}
