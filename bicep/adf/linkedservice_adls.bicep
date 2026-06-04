// ADLS Gen2 (AzureBlobFS) linked service — the medallion lake.
//
// Authenticates with the factory's system-assigned MI (granted "Storage Blob
// Data Contributor" on the account in core/adf/main.tf). No account key or SP
// is declared — MI auth is implicit when only `url` is supplied. ADF writes
// landing Parquet here; chunk 2 notebook activities consume it. build_order 6.2.

@description('Name of the existing Data Factory.')
param factoryName string

@description('ADLS Gen2 DFS endpoint, e.g. https://pipelineiqadlsdev.dfs.core.windows.net')
param adlsDfsEndpoint string

resource ls_adls 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: '${factoryName}/ls_adls'
  properties: {
    type: 'AzureBlobFS'
    description: 'Medallion lake (landing/bronze/silver/gold/quarantine) — MI auth.'
    typeProperties: {
      url: adlsDfsEndpoint
    }
  }
}
