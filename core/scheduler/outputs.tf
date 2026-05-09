output "logic_app_id" {
  value = azurerm_logic_app_workflow.this.id
}

output "logic_app_name" {
  value = azurerm_logic_app_workflow.this.name
}

output "callback_url" {
  value     = azurerm_logic_app_workflow.this.access_endpoint
  sensitive = true
}
