// AzureFunction linked service — ls_function (chunk 2).
//
// The master copy pipeline (pl_master_copy) calls the PipelineIQ control-plane
// REST API through this linked service. The Function App uses function-key auth
// (AuthLevel.FUNCTION), so ADF authenticates with the host default key, resolved
// at runtime from Key Vault secret `functions-host-key` via the ls_keyvault
// linked service (the factory MI has Key Vault Secrets User). DECISIONS #75.
//
// build_order 6.7-6.10 (the ADF consumer of the pipeline.* endpoints).

@description('Name of the existing Data Factory.')
param factoryName string

@description('Function App base URL, e.g. https://pipelineiq-functions-dev.azurewebsites.net')
param functionAppUrl string

@description('Name of the Key Vault linked service that resolves the function key.')
param keyVaultLinkedServiceName string = 'ls_keyvault'

@description('Key Vault secret name holding the Function App host default key.')
param functionKeySecretName string = 'functions-host-key'

resource ls_function 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: '${factoryName}/ls_function'
  properties: {
    type: 'AzureFunction'
    description: 'PipelineIQ control-plane REST API — function-key auth, key from Key Vault.'
    typeProperties: {
      functionAppUrl: functionAppUrl
      functionKey: {
        type: 'AzureKeyVaultSecret'
        store: {
          referenceName: keyVaultLinkedServiceName
          type: 'LinkedServiceReference'
        }
        secretName: functionKeySecretName
      }
    }
  }
}
