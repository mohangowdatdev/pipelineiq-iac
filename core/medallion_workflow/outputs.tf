output "job_id" {
  description = "Numeric Databricks Job ID — passed to ADF as medallionJobId so pl_master_copy can run-now it."
  value       = databricks_job.medallion.id
}

output "job_url" {
  value = databricks_job.medallion.url
}

output "notebook_path" {
  value = var.workspace_notebook_path
}
