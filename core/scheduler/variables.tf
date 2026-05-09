variable "name" {
  type        = string
  description = "Logic App workflow name."
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "target_function_app_name" {
  type        = string
  description = "Function App name to invoke. Used to look up the master key and build the admin URI."
}

variable "target_function_name" {
  type        = string
  description = "Specific function inside the app to invoke (e.g. 'generator')."
}

variable "schedule_hour_utc" {
  type        = number
  description = "UTC hour at which to fire (0-23). 00:30 UTC = 06:00 IST is our default."
  default     = 0
}

variable "schedule_minute_utc" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
