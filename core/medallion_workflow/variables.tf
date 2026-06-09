variable "name" {
  type        = string
  description = "Databricks Job name."
}

variable "workspace_notebook_path" {
  type        = string
  description = "Databricks workspace path of the medallion orchestrator notebook."
  default     = "/Shared/pipelineiq/orchestrate_medallion"
}

variable "node_type_id" {
  type    = string
  default = "Standard_DS3_v2"
}

variable "spark_version" {
  type    = string
  default = "14.3.x-scala2.12"
}

variable "num_workers" {
  type        = number
  description = "Worker count. Mirrors scripts/catchup_medallion.py (4) — silver inventory is the long pole."
  default     = 4
}

variable "timeout_seconds" {
  type        = number
  description = "Per-run timeout for the full bronze->silver->gold chain."
  default     = 7200
}

variable "tags" {
  type    = map(string)
  default = {}
}
