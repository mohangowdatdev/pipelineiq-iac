output "access_connector_id" {
  value = azurerm_databricks_access_connector.this.id
}

output "access_connector_principal_id" {
  value = azurerm_databricks_access_connector.this.identity[0].principal_id
}

output "metastore_id" {
  value = data.databricks_metastore.this.metastore_id
}

output "metastore_name" {
  value = data.databricks_metastore.this.name
}

output "storage_credential_name" {
  value = databricks_storage_credential.this.name
}

output "external_location_names" {
  value = { for k, v in databricks_external_location.this : k => v.name }
}

output "catalog_names" {
  value = [for c in databricks_catalog.this : c.name]
}

output "cluster_policy_id" {
  value = databricks_cluster_policy.jobs.id
}

output "sql_warehouse_id" {
  value = databricks_sql_endpoint.this.id
}

output "sql_warehouse_jdbc_url" {
  value = databricks_sql_endpoint.this.jdbc_url
}

output "secret_scope_name" {
  value = databricks_secret_scope.kv.name
}
