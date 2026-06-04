// AzureDatabricks linked service — chunk 2 notebook orchestration.
//
// MSI auth (decided S18): the factory MI authenticates to the workspace, so
// there is no PAT to store or rotate. The MI is granted "Contributor" on the
// workspace resource in core/adf/main.tf; on the first ADF->Databricks call
// the MI is also surfaced as a workspace user. Declared in chunk 1 so the
// linked service exists; first exercised by the bronze/silver/gold notebook
// activities in chunk 2 (build_order 6.5). build_order 6.2.

@description('Name of the existing Data Factory.')
param factoryName string

@description('Databricks workspace URL, e.g. https://adb-1234567890.12.azuredatabricks.net')
param databricksWorkspaceUrl string

@description('Databricks workspace ARM resource ID.')
param databricksWorkspaceResourceId string

@description('Job-cluster node type for notebook activities.')
param jobClusterNodeType string = 'Standard_DS3_v2'

@description('Databricks Runtime for job clusters (DBR 14.3 LTS).')
param jobClusterSparkVersion string = '14.3.x-scala2.12'

@description('Job-cluster autoscale range (min:max workers).')
param jobClusterWorkers string = '1:2'

resource ls_databricks 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: '${factoryName}/ls_databricks'
  properties: {
    type: 'AzureDatabricks'
    description: 'Bronze/Silver/Gold notebook compute — MSI auth, ephemeral job clusters.'
    typeProperties: {
      domain: databricksWorkspaceUrl
      authentication: 'MSI'
      workspaceResourceId: databricksWorkspaceResourceId
      newClusterNodeType: jobClusterNodeType
      newClusterVersion: jobClusterSparkVersion
      newClusterNumOfWorker: jobClusterWorkers
      newClusterSparkConf: {
        'spark.sql.extensions': 'io.delta.sql.DeltaSparkSessionExtension'
      }
    }
  }
}
