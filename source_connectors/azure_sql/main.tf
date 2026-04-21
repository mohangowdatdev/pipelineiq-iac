data "azurerm_client_config" "current" {}

resource "random_password" "sa" {
  length           = 24
  special          = true
  override_special = "!#%*_-="
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "azurerm_mssql_server" "this" {
  name                = var.server_name
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = "12.0"

  administrator_login          = var.admin_login
  administrator_login_password = random_password.sa.result
  minimum_tls_version          = "1.2"

  public_network_access_enabled = var.public_network_access_enabled

  azuread_administrator {
    login_username              = var.aad_admin_login
    object_id                   = var.aad_admin_object_id
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    azuread_authentication_only = false
  }

  tags = var.tags
}

resource "azurerm_mssql_database" "this" {
  name      = var.database_name
  server_id = azurerm_mssql_server.this.id

  sku_name                    = var.sku_name
  min_capacity                = var.min_capacity
  auto_pause_delay_in_minutes = var.auto_pause_delay_in_minutes
  max_size_gb                 = var.max_size_gb
  zone_redundant              = false
  collation                   = "SQL_Latin1_General_CP1_CI_AS"

  tags = var.tags
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "allow_current_ip" {
  count = var.current_ip == null ? 0 : 1

  name             = "allow-current-ip"
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = var.current_ip
  end_ip_address   = var.current_ip
}
