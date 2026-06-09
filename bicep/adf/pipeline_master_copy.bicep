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

@description('Databricks workspace URL (https://adb-...), for the Jobs REST API. From terraform output databricks_workspace_url.')
param databricksWorkspaceUrl string

@description('Numeric Databricks Job ID of the medallion orchestrator. From terraform output medallion_job_id (core/medallion_workflow).')
param medallionJobId int

@description('ForEach parallelism. Source is serverless 2-vCore — keep modest.')
param foreachBatchCount int = 4

// Azure Databricks login application ID — constant across all tenants; the
// audience the ADF MI requests an AAD token for when calling the Jobs REST API.
var databricksResourceId = '2ff814a6-3304-4ab8-85cb-cd0e6f879c1d'
var runNowUrl = '${databricksWorkspaceUrl}/api/2.1/jobs/run-now'

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
    // Latched out of the Until poll loop — activities inside a control-flow
    // container (Until/ForEach/If) are not referenceable from outside it, so
    // GetMedallionRun's terminal state is copied into these for AssertMedallion.
    variables: {
      medallion_life_cycle: {
        type: 'String'
      }
      medallion_result_state: {
        type: 'String'
      }
      medallion_state_message: {
        type: 'String'
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
      // Option 1 (DECISIONS #78): the medallion is a Terraform-defined
      // Databricks Job (core/medallion_workflow) running on a SINGLE_USER
      // cluster (=> Unity Catalog access). ADF triggers it via the Jobs REST
      // API (MSI auth) and polls to completion, rather than spawning the
      // cluster itself (which lacked SINGLE_USER and failed the UC write).
      {
        name: 'StartMedallion'
        type: 'WebActivity'
        dependsOn: [
          { activity: 'ForEachEntity', dependencyConditions: ['Succeeded'] }
        ]
        typeProperties: {
          url: runNowUrl
          method: 'POST'
          authentication: {
            type: 'MSI'
            resource: databricksResourceId
          }
          body: {
            job_id: medallionJobId
            notebook_params: {
              pipeline_run_id: '@{pipeline().RunId}'
            }
          }
        }
      }
      // Poll runs/get until the run reaches a terminal life-cycle state.
      {
        name: 'PollMedallion'
        type: 'Until'
        dependsOn: [
          { activity: 'StartMedallion', dependencyConditions: ['Succeeded'] }
        ]
        typeProperties: {
          expression: {
            value: '@or(or(equals(variables(\'medallion_life_cycle\'), \'TERMINATED\'), equals(variables(\'medallion_life_cycle\'), \'INTERNAL_ERROR\')), equals(variables(\'medallion_life_cycle\'), \'SKIPPED\'))'
            type: 'Expression'
          }
          timeout: '02:00:00'
          activities: [
            {
              name: 'WaitPoll'
              type: 'Wait'
              typeProperties: {
                waitTimeInSeconds: 20
              }
            }
            {
              name: 'GetMedallionRun'
              type: 'WebActivity'
              dependsOn: [
                { activity: 'WaitPoll', dependencyConditions: ['Succeeded'] }
              ]
              typeProperties: {
                url: '@concat(\'${databricksWorkspaceUrl}/api/2.1/jobs/runs/get?run_id=\', string(activity(\'StartMedallion\').output.run_id))'
                method: 'GET'
                authentication: {
                  type: 'MSI'
                  resource: databricksResourceId
                }
              }
            }
            {
              name: 'LatchLifeCycle'
              type: 'SetVariable'
              dependsOn: [
                { activity: 'GetMedallionRun', dependencyConditions: ['Succeeded'] }
              ]
              typeProperties: {
                variableName: 'medallion_life_cycle'
                value: '@activity(\'GetMedallionRun\').output.state.life_cycle_state'
              }
            }
            {
              name: 'LatchResultState'
              type: 'SetVariable'
              dependsOn: [
                { activity: 'LatchLifeCycle', dependencyConditions: ['Succeeded'] }
              ]
              typeProperties: {
                variableName: 'medallion_result_state'
                value: '@coalesce(activity(\'GetMedallionRun\').output.state.result_state, \'\')'
              }
            }
            {
              name: 'LatchStateMessage'
              type: 'SetVariable'
              dependsOn: [
                { activity: 'LatchResultState', dependencyConditions: ['Succeeded'] }
              ]
              typeProperties: {
                variableName: 'medallion_state_message'
                value: '@coalesce(activity(\'GetMedallionRun\').output.state.state_message, \'\')'
              }
            }
          ]
        }
      }
      // Convert a non-SUCCESS terminal result into an activity failure so the
      // run-log closers below fire correctly.
      {
        name: 'AssertMedallion'
        type: 'IfCondition'
        dependsOn: [
          { activity: 'PollMedallion', dependencyConditions: ['Succeeded'] }
        ]
        typeProperties: {
          expression: {
            value: '@equals(variables(\'medallion_result_state\'), \'SUCCESS\')'
            type: 'Expression'
          }
          ifFalseActivities: [
            {
              name: 'FailMedallion'
              type: 'Fail'
              typeProperties: {
                message: '@concat(\'medallion run failed (\', variables(\'medallion_result_state\'), \'): \', variables(\'medallion_state_message\'))'
                errorCode: 'MedallionFailed'
              }
            }
          ]
        }
      }
      // ── 5. Close the master run-log row ───────────────────────────────────
      {
        name: 'LogRunEnd'
        type: 'AzureFunctionActivity'
        dependsOn: [
          { activity: 'AssertMedallion', dependencyConditions: ['Succeeded'] }
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
          { activity: 'AssertMedallion', dependencyConditions: ['Failed'] }
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
            error_message: '@concat(\'RunMedallion failed (\', variables(\'medallion_result_state\'), \'): \', variables(\'medallion_state_message\'))'
          }
        }
      }
    ]
  }
}
