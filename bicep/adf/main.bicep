// ADF-internal objects for pipelineiq-adf-dev — chunk 1 (linked services +
// datasets). The factory resource + its MI RBAC are Terraform
// (PipelineIQ-IaC/core/adf/); this template only publishes the objects ADF
// authors. Deployed via scripts/deploy_adf.sh (az deployment group create).
//
// Chunk 2 (S19) adds the master copy pipeline + Databricks notebook
// activities + diagnostic settings on top of these.
//
// build_order 6.2 (linked services) + 6.3 (datasets).

targetScope = 'resourceGroup'

@description('Name of the existing Data Factory (Terraform-managed).')
param factoryName string

@description('Key Vault base URI, e.g. https://pipelineiq-kv-dev.vault.azure.net/')
param keyVaultBaseUrl string

@description('ADLS Gen2 DFS endpoint, e.g. https://pipelineiqadlsdev.dfs.core.windows.net')
param adlsDfsEndpoint string

@description('Databricks workspace URL, e.g. https://adb-123.12.azuredatabricks.net')
param databricksWorkspaceUrl string

@description('Databricks workspace ARM resource ID.')
param databricksWorkspaceResourceId string

@description('Function App base URL, e.g. https://pipelineiq-functions-dev.azurewebsites.net (chunk 2).')
param functionAppUrl string

// ── Linked services ────────────────────────────────────────────────────────

module lsKeyVault 'linkedservice_keyvault.bicep' = {
  name: 'ls_keyvault'
  params: {
    factoryName: factoryName
    keyVaultBaseUrl: keyVaultBaseUrl
  }
}

// SQL linked service resolves its connection string through the KV linked
// service, so it must be published after it.
module lsAzureSql 'linkedservice_azuresql.bicep' = {
  name: 'ls_azuresql_velora'
  params: {
    factoryName: factoryName
  }
  dependsOn: [
    lsKeyVault
  ]
}

module lsAdls 'linkedservice_adls.bicep' = {
  name: 'ls_adls'
  params: {
    factoryName: factoryName
    adlsDfsEndpoint: adlsDfsEndpoint
  }
}

module lsDatabricks 'linkedservice_databricks.bicep' = {
  name: 'ls_databricks'
  params: {
    factoryName: factoryName
    databricksWorkspaceUrl: databricksWorkspaceUrl
    databricksWorkspaceResourceId: databricksWorkspaceResourceId
  }
}

// ── Datasets (parameterised, one pair for all entity_registry rows) ─────────

module dsSqlSource 'dataset_sql_source.bicep' = {
  name: 'ds_sql_source'
  params: {
    factoryName: factoryName
  }
  dependsOn: [
    lsAzureSql
  ]
}

module dsAdlsSink 'dataset_adls_sink.bicep' = {
  name: 'ds_adls_sink'
  params: {
    factoryName: factoryName
  }
  dependsOn: [
    lsAdls
  ]
}

// ── Chunk 2: Function linked service + master copy pipeline + daily trigger ──

module lsFunction 'linkedservice_function.bicep' = {
  name: 'ls_function'
  params: {
    factoryName: factoryName
    functionAppUrl: functionAppUrl
  }
  dependsOn: [
    lsKeyVault
  ]
}

module plMasterCopy 'pipeline_master_copy.bicep' = {
  name: 'pl_master_copy'
  params: {
    factoryName: factoryName
  }
  dependsOn: [
    dsSqlSource
    dsAdlsSink
    lsFunction
    lsDatabricks
  ]
}

// Created Stopped — started only at cutover (build_order 6.11).
module trgDaily 'trigger_daily.bicep' = {
  name: 'trg_daily_0040'
  params: {
    factoryName: factoryName
  }
  dependsOn: [
    plMasterCopy
  ]
}
