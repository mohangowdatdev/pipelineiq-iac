// Parameterised ADLS Gen2 Parquet sink dataset.
//
// ONE dataset serves all 12 entity_registry rows. Mirrors the same
// {schema, table, watermark_column, load_type} contract as the source, plus
// a computed `folder_path` that the chunk-2 pipeline derives per run:
//   incremental -> landing/<table>/date=<YYYY-MM-DD>/
//   full        -> landing/<table>/full/
// Snappy-compressed Parquet, matching what the bronze notebook already reads
// (recursiveFileLookup=true). build_order 6.3.

@description('Name of the existing Data Factory.')
param factoryName string

@description('Name of the ADLS Gen2 linked service.')
param adlsLinkedServiceName string = 'ls_adls'

@description('ADLS filesystem (container) for raw extracts.')
param landingFileSystem string = 'landing'

resource ds_adls_sink 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${factoryName}/ds_adls_sink'
  properties: {
    type: 'Parquet'
    description: 'Parameterised landing Parquet sink — one dataset for all entity_registry rows.'
    linkedServiceName: {
      referenceName: adlsLinkedServiceName
      type: 'LinkedServiceReference'
    }
    parameters: {
      schema: { type: 'String' }
      table: { type: 'String' }
      watermark_column: { type: 'String' }
      load_type: { type: 'String' }
      folder_path: { type: 'String' }
    }
    schema: []
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileSystem: landingFileSystem
        folderPath: {
          value: '@dataset().folder_path'
          type: 'Expression'
        }
      }
      compressionCodec: 'snappy'
    }
  }
}
