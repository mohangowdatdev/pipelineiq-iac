// AzureSqlDatabase linked service — the velora_oms source.
//
// The connection string (with SQL auth credentials) is NOT inlined; it is
// resolved at runtime from Key Vault secret `sql-connection-string` via the
// ls_keyvault linked service. That secret is written by Terraform
// (clients/velora/main.tf -> azurerm_key_vault_secret.sql_connection_string).
// build_order 6.2.

@description('Name of the existing Data Factory.')
param factoryName string

@description('Name of the Key Vault linked service that resolves the secret.')
param keyVaultLinkedServiceName string = 'ls_keyvault'

@description('Key Vault secret name holding the full velora_oms connection string.')
param sqlConnectionSecretName string = 'sql-connection-string'

resource ls_azuresql 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: '${factoryName}/ls_azuresql_velora'
  properties: {
    type: 'AzureSqlDatabase'
    description: 'velora_oms source — connection string resolved from Key Vault.'
    typeProperties: {
      connectionString: {
        type: 'AzureKeyVaultSecret'
        store: {
          referenceName: keyVaultLinkedServiceName
          type: 'LinkedServiceReference'
        }
        secretName: sqlConnectionSecretName
      }
    }
  }
}
