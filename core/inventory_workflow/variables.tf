variable "name" {
  type        = string
  description = "Databricks Job name."
}

variable "workspace_notebook_path" {
  type        = string
  description = "Databricks workspace path where the notebook lives."
  default     = "/Shared/pipelineiq/source_sim/write_inventory_snapshot"
}

variable "schedule_cron" {
  type        = string
  description = "Quartz cron expression. Default: 00:35 UTC daily (5 min after Function fire at 00:30)."
  default     = "0 35 0 ? * *"
}

variable "schedule_timezone" {
  type    = string
  default = "UTC"
}

variable "node_type_id" {
  type    = string
  default = "Standard_DS3_v2"
}

variable "spark_version" {
  type    = string
  default = "14.3.x-scala2.12"
}

variable "cluster_policy_id" {
  type        = string
  description = "Optional cluster policy ID to bind the job's compute to."
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
