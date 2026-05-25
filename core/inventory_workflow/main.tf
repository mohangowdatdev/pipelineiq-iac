# ------------------------------------------------------------
# Source-system simulator — daily inventory snapshot.
#
# Replaces the Function-App-based inventory write (DECISIONS #71,
# supersedes #62 + #69). The Function App on FC1 Flex Consumption
# could not reliably push 189K rows through pyodbc; every fire
# 2026-05-14 → 2026-05-24 partial-died at 1-4 chunks. Spark JDBC
# bulk insert on Databricks Jobs Compute moves the same load in
# ~3-4 min wall time with no worker reaper.
#
# Schedule: 00:35 UTC daily (5 min after the Function fire at 00:30,
# so orders/lines/status_log land first; the notebook's
# `verify_order_landed` widget refuses to write if they haven't).
#
# Notebook deployment is handled out-of-band by
# `scripts/run_inventory_smoke.py` (in PipelineIQ-Architecture)
# which uploads to the workspace path referenced below. Same
# pattern as bronze/silver/gold notebooks today.
# ------------------------------------------------------------

resource "databricks_job" "inventory" {
  provider = databricks.workspace

  name = var.name

  schedule {
    quartz_cron_expression = var.schedule_cron
    timezone_id            = var.schedule_timezone
    pause_status           = "UNPAUSED"
  }

  task {
    task_key = "write_inventory_snapshot"

    notebook_task {
      notebook_path = var.workspace_notebook_path
      base_parameters = {
        snapshot_date       = "yesterday_utc"
        force               = "false"
        verify_order_landed = "true"
      }
    }

    new_cluster {
      spark_version      = var.spark_version
      node_type_id       = var.node_type_id
      data_security_mode = "SINGLE_USER"
      num_workers        = 1

      # Note: we do NOT bind to the `${name_prefix}-jobs-policy` cluster
      # policy. That policy fixes `autotermination_minutes=30` which is
      # interactive-cluster shaped; automated (job) clusters reject
      # autotermination because they terminate on job completion anyway.

      custom_tags = var.tags
    }

    timeout_seconds           = 1800
    max_retries               = 2
    min_retry_interval_millis = 60000

    email_notifications {
      no_alert_for_skipped_runs = true
    }
  }

  max_concurrent_runs = 1
}
