// AzureKeyVault linked service.
//
// The secret store every other linked service resolves credentials through.
// ADF authenticates to Key Vault with the factory's system-assigned MI
// (granted "Key Vault Secrets User" in core/adf/main.tf), so no credential
// is declared here. build_order 6.2.

@description('Name of the existing Data Factory (live mode, Git disabled).')
param factoryName string

@description('Key Vault base URI, e.g. https://pipelineiq-kv-dev.vault.azure.net/')
param keyVaultBaseUrl string

resource ls_keyvault 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: '${factoryName}/ls_keyvault'
  properties: {
    type: 'AzureKeyVault'
    description: 'Velora secret store — resolves sql-connection-string for the SQL linked service.'
    typeProperties: {
      baseUrl: keyVaultBaseUrl
    }
  }
}
