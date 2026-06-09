# ------------------------------------------------------------
# Medallion orchestration — bronze -> silver -> gold.
#
# Created S20 to fix the RunMedallion failure (DECISIONS #78). The ADF
# master pipeline (pl_master_copy) originally ran the medallion via a
# DatabricksNotebook activity over the ls_databricks (MSI) linked service.
# That cluster was spawned WITHOUT data_security_mode=SINGLE_USER, so it
# had no Unity Catalog access and the bronze notebook's UC-catalog write
# failed instantly.
#
# Option 1 fix: define the medallion as a Terraform Databricks Job here
# (same pattern as core/inventory_workflow). The databricks.workspace
# provider authenticates via azure-cli, so the job is created by — and
# runs as — `mohan.gowda`, the identity that already holds the UC grants
# used by scripts/catchup_medallion.py. The SINGLE_USER cluster therefore
# gets UC access for free. ADF no longer spawns the cluster; it only
# triggers this job via the Jobs REST API (jobs/run-now) and polls.
#
# No schedule: this job is on-demand only. The daily fire comes from the
# ADF trigger (trg_daily_0040 -> pl_master_copy -> run-now), so a Quartz
# schedule here would double-run the medallion.
#
# The orchestrator notebook is uploaded out-of-band via
# `scripts/catchup_medallion.py --upload-orchestrator` (PipelineIQ-Architecture),
# same pattern as the bronze/silver/gold + inventory notebooks. This module
# owns the Job definition only.
# ------------------------------------------------------------

resource "databricks_job" "medallion" {
  provider = databricks.workspace

  name = var.name

  # On-demand only — triggered by ADF run-now. No schedule block.

  task {
    task_key = "orchestrate_medallion"

    notebook_task {
      notebook_path = var.workspace_notebook_path
      base_parameters = {
        # ADF overrides this per run via run-now notebook_params. The default
        # lets a manual run-now (no params) still execute end-to-end.
        pipeline_run_id = ""
      }
    }

    new_cluster {
      spark_version      = var.spark_version
      node_type_id       = var.node_type_id
      data_security_mode = "SINGLE_USER"
      num_workers        = var.num_workers

      spark_conf = {
        "spark.sql.extensions" = "io.delta.sql.DeltaSparkSessionExtension"
      }

      # Note: deliberately NOT bound to the `${name_prefix}-jobs-policy`
      # cluster policy — that policy fixes autotermination_minutes=30, which
      # automated (job) clusters reject (they terminate on completion anyway).
      # Same reasoning as core/inventory_workflow.

      custom_tags = var.tags
    }

    # Generous: silver.inventory_snapshot (7M+ rows) is the long pole;
    # the whole bronze->silver->gold chain runs sequentially in one notebook.
    timeout_seconds           = var.timeout_seconds
    max_retries               = 0
    min_retry_interval_millis = 0
  }

  # Prevent an overlapping run if a manual smoke and the ADF trigger collide.
  max_concurrent_runs = 1
}
