// Parameterised Azure SQL source dataset.
//
// ONE dataset serves all 12 pipeline.entity_registry rows. The chunk-2 master
// pipeline's ForEach binds these parameters per entity from entity_registry
// (schema, table, watermark_column, load_type). schema + table resolve the
// physical table; watermark_column + load_type are carried so the copy
// activity's source query (incremental WHERE watermark_column > @watermark,
// or full SELECT *) can reference them without a second lookup. build_order 6.3.

@description('Name of the existing Data Factory.')
param factoryName string

@description('Name of the Azure SQL linked service (velora_oms).')
param sqlLinkedServiceName string = 'ls_azuresql_velora'

resource ds_sql_source 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${factoryName}/ds_sql_source'
  properties: {
    type: 'AzureSqlTable'
    description: 'Parameterised velora_oms source — one dataset for all entity_registry rows.'
    linkedServiceName: {
      referenceName: sqlLinkedServiceName
      type: 'LinkedServiceReference'
    }
    parameters: {
      schema: { type: 'String' }
      table: { type: 'String' }
      watermark_column: { type: 'String' }
      load_type: { type: 'String' }
    }
    schema: []
    typeProperties: {
      schema: {
        value: '@dataset().schema'
        type: 'Expression'
      }
      table: {
        value: '@dataset().table'
        type: 'Expression'
      }
    }
  }
}
