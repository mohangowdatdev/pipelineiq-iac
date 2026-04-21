data "azurerm_client_config" "current" {}

resource "random_password" "admin" {
  length           = 24
  special          = true
  override_special = "!#%*_-="
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku_name = var.sku_name
  version  = var.postgres_version

  storage_mb   = var.storage_mb
  storage_tier = var.storage_tier

  administrator_login    = var.admin_login
  administrator_password = random_password.admin.result

  authentication {
    password_auth_enabled         = true
    active_directory_auth_enabled = true
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  public_network_access_enabled = var.public_network_access_enabled
  zone                          = "1"
  backup_retention_days         = var.backup_retention_days

  tags = var.tags

  lifecycle {
    ignore_changes = [
      zone,
      high_availability[0].standby_availability_zone,
    ]
  }
}

resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = join(",", var.allowed_extensions)
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "current_user" {
  count = var.grant_current_user_aad_admin ? 1 : 0

  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azurerm_client_config.current.object_id
  principal_name      = var.current_user_principal_name
  principal_type      = "User"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_current_ip" {
  count = var.current_ip == null ? 0 : 1

  name             = "allow-current-ip"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = var.current_ip
  end_ip_address   = var.current_ip
}
