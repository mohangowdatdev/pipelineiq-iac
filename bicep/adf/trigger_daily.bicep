// Daily schedule trigger — trg_daily_0040 (chunk 2).
//
// Fires pl_master_copy at 00:40 UTC daily (10 min after the Function generator
// fire at 00:30, 5 min after the Databricks inventory Job at 00:35) so the
// source DB is fully written before the copy starts. run_date = yesterday.
//
// Created in the STOPPED state. Enable (start) only at cutover (build_order
// 6.11) after a clean manual copy smoke. Until then export_velora_to_landing.py
// remains the production landing-extract path.

@description('Name of the existing Data Factory.')
param factoryName string

@description('Pipeline this trigger runs.')
param pipelineName string = 'pl_master_copy'

@description('Anchor start time (UTC). The trigger is created Stopped, so this is just a valid recurrence anchor.')
param startTime string = '2026-06-08T00:40:00Z'

resource trg_daily_0040 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: '${factoryName}/trg_daily_0040'
  properties: {
    type: 'ScheduleTrigger'
    description: 'Daily 00:40 UTC fire of pl_master_copy (run_date=yesterday). Deploys Stopped; start at cutover.'
    // No runtimeState here: ARM/Bicep deploys triggers in the Stopped state by
    // default (the property is read-only in the type). At cutover (build_order
    // 6.11) enable with: az datafactory trigger start -g <rg> --factory-name
    // pipelineiq-adf-dev -n trg_daily_0040.
    pipelines: [
      {
        pipelineReference: {
          referenceName: pipelineName
          type: 'PipelineReference'
        }
        parameters: {
          run_date: '@formatDateTime(adddays(utcnow(), -1), \'yyyy-MM-dd\')'
        }
      }
    ]
    typeProperties: {
      recurrence: {
        frequency: 'Day'
        interval: 1
        startTime: startTime
        timeZone: 'UTC'
        schedule: {
          hours: [
            0
          ]
          minutes: [
            40
          ]
        }
      }
    }
  }
}
