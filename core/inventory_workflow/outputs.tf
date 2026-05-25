output "job_id" {
  value = databricks_job.inventory.id
}

output "job_url" {
  value = databricks_job.inventory.url
}

output "notebook_path" {
  value = var.workspace_notebook_path
}
