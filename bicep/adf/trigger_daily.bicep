// Daily schedule trigger — trg_daily_0100 (chunk 2).
//
// Fires pl_master_copy at 01:00 UTC daily. The upstream chain is: Function
// generator fire 00:30 (writes orders/lines/status, ~2 min) -> Databricks
// inventory Job 00:35 (cluster cold-start + Spark JDBC bulk insert, can finish
// ~00:44) -> THIS copy at 01:00. The 01:00 anchor leaves a comfortable buffer
// after the inventory Job completes (00:40 was too tight — it could start before
// the inventory write to source finished). run_date = yesterday (UTC).
// Renamed from trg_daily_0040 in S20 (cutover timing fix).
//
// Created in the STOPPED state. Started at cutover (build_order 6.11) via
// `az datafactory trigger start ... -n trg_daily_0100`. Until then
// export_velora_to_landing.py remains the production landing-extract path.

@description('Name of the existing Data Factory.')
param factoryName string

@description('Pipeline this trigger runs.')
param pipelineName string = 'pl_master_copy'

@description('Anchor start time (UTC). Trigger created Stopped, so this is just a valid recurrence anchor.')
param startTime string = '2026-06-10T01:00:00Z'

resource trg_daily_0100 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: '${factoryName}/trg_daily_0100'
  properties: {
    type: 'ScheduleTrigger'
    description: 'Daily 01:00 UTC fire of pl_master_copy (run_date=yesterday). Buffered after the 00:30 generator + 00:35 inventory Job. Deploys Stopped; start at cutover.'
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
            1
          ]
          minutes: [
            0
          ]
        }
      }
    }
  }
}
