# ------------------------------------------------------------
# Logic App Consumption — daily HTTP POST to a Function App admin endpoint.
#
# Why this exists: Flex Consumption timer triggers do not reliably fire when
# the function host has scaled to zero (same class of bug as Y1 Linux had —
# DECISIONS #50 migration didn't fix the timer, only HTTP/manual invokes).
# Verified 2026-05-09: 2 consecutive scheduled fires (May 8 + May 9 at
# 00:30 UTC) silently no-op'd despite a healthy function + correct cron.
#
# Solution: take scheduling out of the Function platform entirely. Logic
# App Consumption is Microsoft's managed cron — 99.9% SLA, no scale-to-zero
# concern, ~Rs.0/mo at one fire/day (well under the 4,000-action free grant).
# ------------------------------------------------------------

data "azurerm_function_app_host_keys" "target" {
  name                = var.target_function_app_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_logic_app_workflow" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

resource "azurerm_logic_app_trigger_recurrence" "daily" {
  name         = "daily-fire"
  logic_app_id = azurerm_logic_app_workflow.this.id

  frequency = "Day"
  interval  = 1
  time_zone = "UTC"

  schedule {
    at_these_hours   = [var.schedule_hour_utc]
    at_these_minutes = [var.schedule_minute_utc]
  }
}

resource "azurerm_logic_app_action_http" "invoke_function" {
  name         = "invoke-${var.target_function_name}"
  logic_app_id = azurerm_logic_app_workflow.this.id

  method = "POST"
  uri    = "https://${var.target_function_app_name}.azurewebsites.net/admin/functions/${var.target_function_name}"

  headers = {
    "Content-Type"    = "application/json"
    "x-functions-key" = data.azurerm_function_app_host_keys.target.primary_key
  }

  body = jsonencode({ input = "logic-app-cron" })

  depends_on = [azurerm_logic_app_trigger_recurrence.daily]
}
