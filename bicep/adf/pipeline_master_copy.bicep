// Master metadata-driven copy pipeline — pl_master_copy (chunk 2).
//
// Faithful reproduction of scripts/export_velora_to_landing.py, but driven by
// pipeline.entity_registry (via the Function GET /entities endpoint) instead of
// a hardcoded list. For each active entity:
//   get registry rows -> log run start -> ForEach:
//     log entity start -> clear target folder -> copy SQL -> landing Parquet ->
//     register file -> commit watermark -> log entity end
//   -> run medallion (bronze->silver->gold orchestrator notebook) -> log run end
//
// Partitioning (DECISIONS #76): partition_date_column non-null (orders=order_date,
// inventory_snapshot=snapshot_date) => by-date extract into landing/<t>/date=<D>/;
// null => full dump into landing/<t>/full/. Watermark committed per-copy inside
// the ForEach, before the medallion (DECISIONS #75 — looser than build_order 6.8's
// strict end-to-end; acceptable under faithful reproduction).
//
// build_order 6.4 + 6.5 + 6.7-6.10.

@description('Name of the existing Data Factory.')
param factoryName string

@description('Source SQL dataset (parameterised) published in chunk 1.')
param sqlSourceDatasetName string = 'ds_sql_source'

@description('ADLS landing sink dataset (parameterised) published in chunk 1.')
param adlsSinkDatasetName string = 'ds_adls_sink'

@description('Function REST linked service.')
param functionLinkedServiceName string = 'ls_function'

@description('Databricks (MSI) linked service for the medallion orchestrator.')
param databricksLinkedServiceName string = 'ls_databricks'

@description('Workspace path of the medallion orchestrator notebook.')
param orchestratorNotebookPath string = '/Shared/pipelineiq/orchestrate_medallion'

@description('ForEach parallelism. Source is serverless 2-vCore — keep modest.')
param foreachBatchCount int = 4

// ── Per-item expressions (ADF expression language; single quotes escaped) ────
// landing/<table>/date=<run_date>/  (by-date)  or  landing/<table>/full/ (full)
var folderPathExpr = '@if(empty(item().partition_date_column), concat(item().source_table, \'/full\'), concat(item().source_table, \'/date=\', pipeline().parameters.run_date))'

// Full dump, or WHERE <partition_date_column> = '<run_date>' for by-date entities.
// The '''' sequences produce the SQL single-quotes around the date literal.
var sqlReaderQueryExpr = '@if(empty(item().partition_date_column), concat(\'SELECT * FROM [\', item().source_schema, \'].[\', item().source_table, \']\'), concat(\'SELECT * FROM [\', item().source_schema, \'].[\', item().source_table, \'] WHERE [\', item().partition_date_column, \'] = \', \'\'\'\', pipeline().parameters.run_date, \'\'\'\'))'

// Per-entity run id (distinct from the pipeline-level RunId so log_run_end's
// "end_time IS NULL" match is unambiguous).
var entityRunIdExpr = '@concat(pipeline().RunId, \':\', item().source_table)'

resource pl_master_copy 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${factoryName}/pl_master_copy'
  properties: {
    description: 'Metadata-driven Azure SQL -> landing copy + medallion orchestration (Tier 6 chunk 2).'
    parameters: {
      run_date: {
        type: 'String'
        defaultValue: '@formatDateTime(adddays(utcnow(), -1), \'yyyy-MM-dd\')'
      }
    }
    activities: [
      // ── 1. Read the registry ──────────────────────────────────────────────
      {
        name: 'GetEntities'
        type: 'AzureFunctionActivity'
        linkedServiceName: {
          referenceName: functionLinkedServiceName
          type: 'LinkedServiceReference'
        }
        typeProperties: {
          functionName: 'entities'
          method: 'GET'
        }
      }
      // ── 2. Open the master run-log row ────────────────────────────────────
      {
        name: 'LogRunStart'
        type: 'AzureFunctionActivity'
        dependsOn: [
          { activity: 'GetEntities', dependencyConditions: ['Succeeded'] }
        ]
        linkedServiceName: {
          referenceName: functionLinkedServiceName
          type: 'LinkedServiceReference'
        }
        typeProperties: {
          functionName: 'runs/start'
          method: 'POST'
          body: {
            run_id: '@pipeline().RunId'
            pipeline_name: 'pl_master_copy'
          }
        }
      }
      // ── 3. ForEach entity: copy + control-plane writes ────────────────────
      {
        name: 'ForEachEntity'
        type: 'ForEach'
        dependsOn: [
          { activity: 'LogRunStart', dependencyConditions: ['Succeeded'] }
        ]
        typeProperties: {
          items: {
            value: '@activity(\'GetEntities\').output.entities'
            type: 'Expression'
          }
          isSequential: false
          batchCount: foreachBatchCount
          activities: [
            {
              name: 'LogEntityStart'
              type: 'AzureFunctionActivity'
              linkedServiceName: {
                referenceName: functionLinkedServiceName
                type: 'LinkedServiceReference'
              }
              typeProperties: {
                functionName: 'runs/start'
                method: 'POST'
                body: {
                  run_id: entityRunIdExpr
                  pipeline_name: 'pl_master_copy'
                  entity_name: '@item().entity_name'
                }
              }
            }
            {
              name: 'ClearTarget'
              type: 'Delete'
              dependsOn: [
                { activity: 'LogEntityStart', dependencyConditions: ['Succeeded'] }
              ]
              typeProperties: {
                dataset: {
                  referenceName: adlsSinkDatasetName
                  type: 'DatasetReference'
                  parameters: {
                    schema: '@item().source_schema'
                    table: '@item().source_table'
                    watermark_column: '@item().watermark_column'
                    load_type: '@item().load_type'
                    folder_path: folderPathExpr
                  }
                }
                enableLogging: false
                storeSettings: {
                  type: 'AzureBlobFSReadSettings'
                  recursive: true
                  wildcardFileName: '*'
                }
              }
            }
            {
              name: 'CopyToLanding'
              type: 'Copy'
              // 'Completed' (not 'Succeeded'): on a fresh date the target folder
              // does not exist yet and Delete may fault — proceed regardless.
              dependsOn: [
                { activity: 'ClearTarget', dependencyConditions: ['Completed'] }
              ]
              inputs: [
                {
                  referenceName: sqlSourceDatasetName
                  type: 'DatasetReference'
                  parameters: {
                    schema: '@item().source_schema'
                    table: '@item().source_table'
                    watermark_column: '@item().watermark_column'
                    load_type: '@item().load_type'
                  }
                }
              ]
              outputs: [
                {
                  referenceName: adlsSinkDatasetName
                  type: 'DatasetReference'
                  parameters: {
                    schema: '@item().source_schema'
                    table: '@item().source_table'
                    watermark_column: '@item().watermark_column'
                    load_type: '@item().load_type'
                    folder_path: folderPathExpr
                  }
                }
              ]
              typeProperties: {
                source: {
                  type: 'AzureSqlSource'
                  sqlReaderQuery: sqlReaderQueryExpr
                  queryTimeout: '02:00:00'
                  partitionOption: 'None'
                }
                sink: {
                  type: 'ParquetSink'
                  storeSettings: {
                    type: 'AzureBlobFSWriteSettings'
                  }
                  formatSettings: {
                    type: 'ParquetWriteSettings'
                  }
                }
                enableStaging: false
              }
            }
            {
              name: 'RegisterFile'
              type: 'AzureFunctionActivity'
              dependsOn: [
                { activity: 'CopyToLanding', dependencyConditions: ['Succeeded'] }
              ]
              linkedServiceName: {
                referenceName: functionLinkedServiceName
                type: 'LinkedServiceReference'
              }
              typeProperties: {
                functionName: 'files/register'
                method: 'POST'
                body: {
                  file_path: folderPathExpr
                  source_entity: '@item().entity_name'
                  landed_at: '@utcnow()'
                  row_count: '@activity(\'CopyToLanding\').output.rowsCopied'
                  pipeline_run_id: '@pipeline().RunId'
                }
              }
            }
            {
              name: 'CommitWatermark'
              type: 'AzureFunctionActivity'
              dependsOn: [
                { activity: 'RegisterFile', dependencyConditions: ['Succeeded'] }
              ]
              linkedServiceName: {
                referenceName: functionLinkedServiceName
                type: 'LinkedServiceReference'
              }
              typeProperties: {
                functionName: '@concat(\'watermarks/\', item().entity_name, \'/commit\')'
                method: 'POST'
                body: {
                  last_successful_load: '@pipeline().parameters.run_date'
                  next_window_start: '@formatDateTime(adddays(pipeline().parameters.run_date, 1), \'yyyy-MM-dd\')'
                }
              }
            }
            {
              name: 'LogEntityEnd'
              type: 'AzureFunctionActivity'
              dependsOn: [
                { activity: 'CommitWatermark', dependencyConditions: ['Succeeded'] }
              ]
              linkedServiceName: {
                referenceName: functionLinkedServiceName
                type: 'LinkedServiceReference'
              }
              typeProperties: {
                functionName: '@concat(\'runs/\', pipeline().RunId, \':\', item().source_table, \'/end\')'
                method: 'POST'
                body: {
                  status: 'success'
                  rows_read: '@activity(\'CopyToLanding\').output.rowsRead'
                  rows_written: '@activity(\'CopyToLanding\').output.rowsCopied'
                }
              }
            }
            {
              name: 'LogEntityFailed'
              type: 'AzureFunctionActivity'
              dependsOn: [
                { activity: 'CopyToLanding', dependencyConditions: ['Failed'] }
              ]
              linkedServiceName: {
                referenceName: functionLinkedServiceName
                type: 'LinkedServiceReference'
              }
              typeProperties: {
                functionName: '@concat(\'runs/\', pipeline().RunId, \':\', item().source_table, \'/end\')'
                method: 'POST'
                body: {
                  status: 'failed'
                  error_message: '@concat(\'CopyToLanding failed: \', coalesce(activity(\'CopyToLanding\').error.message, \'unknown\'))'
                }
              }
            }
          ]
        }
      }
      // ── 4. Run the medallion (bronze->silver->gold) ───────────────────────
      {
        name: 'RunMedallion'
        type: 'DatabricksNotebook'
        dependsOn: [
          { activity: 'ForEachEntity', dependencyConditions: ['Succeeded'] }
        ]
        linkedServiceName: {
          referenceName: databricksLinkedServiceName
          type: 'LinkedServiceReference'
        }
        typeProperties: {
          notebookPath: orchestratorNotebookPath
          baseParameters: {
            pipeline_run_id: '@pipeline().RunId'
          }
        }
      }
      // ── 5. Close the master run-log row ───────────────────────────────────
      {
        name: 'LogRunEnd'
        type: 'AzureFunctionActivity'
        dependsOn: [
          { activity: 'RunMedallion', dependencyConditions: ['Succeeded'] }
        ]
        linkedServiceName: {
          referenceName: functionLinkedServiceName
          type: 'LinkedServiceReference'
        }
        typeProperties: {
          functionName: '@concat(\'runs/\', pipeline().RunId, \'/end\')'
          method: 'POST'
          body: {
            status: 'success'
          }
        }
      }
      // Failure closers — one fires depending on where the run broke.
      {
        name: 'LogRunFailedCopy'
        type: 'AzureFunctionActivity'
        dependsOn: [
          { activity: 'ForEachEntity', dependencyConditions: ['Failed'] }
        ]
        linkedServiceName: {
          referenceName: functionLinkedServiceName
          type: 'LinkedServiceReference'
        }
        typeProperties: {
          functionName: '@concat(\'runs/\', pipeline().RunId, \'/end\')'
          method: 'POST'
          body: {
            status: 'failed'
            error_message: 'one or more entity copies failed (see per-entity run rows)'
          }
        }
      }
      {
        name: 'LogRunFailedMedallion'
        type: 'AzureFunctionActivity'
        dependsOn: [
          { activity: 'RunMedallion', dependencyConditions: ['Failed'] }
        ]
        linkedServiceName: {
          referenceName: functionLinkedServiceName
          type: 'LinkedServiceReference'
        }
        typeProperties: {
          functionName: '@concat(\'runs/\', pipeline().RunId, \'/end\')'
          method: 'POST'
          body: {
            status: 'failed'
            error_message: '@concat(\'RunMedallion failed: \', coalesce(activity(\'RunMedallion\').error.message, \'unknown\'))'
          }
        }
      }
    ]
  }
}
