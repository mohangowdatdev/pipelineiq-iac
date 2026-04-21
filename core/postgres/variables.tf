variable "name" {
  description = "PostgreSQL Flexible Server name (globally unique DNS label)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,61}[a-z0-9]$", var.name))
    error_message = "Name must be 3-63 chars, start with lowercase letter, end alphanumeric, lowercase letters/digits/hyphens only."
  }
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku_name" {
  description = "Compute SKU. B2s = 2 vCore burstable, per PLANNING.md + DECISIONS #13."
  type        = string
  default     = "B_Standard_B2s"
}

variable "postgres_version" {
  description = "Major version. 16 is current stable as of 2026-04."
  type        = string
  default     = "16"
}

variable "storage_mb" {
  description = "Storage size. 32768 MB = 32 GB (smallest tier on P1 storage)."
  type        = number
  default     = 32768
}

variable "storage_tier" {
  description = "Storage IOPS tier. P4 = 120 IOPS, sufficient for control plane + pgvector at this volume."
  type        = string
  default     = "P4"
}

variable "admin_login" {
  description = "Password-auth admin login. Used only for bootstrap; AAD admin is the preferred path."
  type        = string
  default     = "pipelineiqadmin"
}

variable "public_network_access_enabled" {
  description = "Keep true for dev; restrict via Private Endpoint in prod."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "allowed_extensions" {
  description = "Server-level extension allowlist (values must be lowercase per Azure PG Flex Server API). CREATE EXTENSION still required in SQL. vector = pgvector."
  type        = list(string)
  default     = ["vector", "pg_trgm", "uuid-ossp"]
}

variable "grant_current_user_aad_admin" {
  description = "Make the running principal an AAD admin on the server. Required for pgvector bootstrap as current user."
  type        = bool
  default     = true
}

variable "current_user_principal_name" {
  description = "UPN of the running user (e.g. user@tenant.onmicrosoft.com). Required when grant_current_user_aad_admin is true."
  type        = string
  default     = null
}

variable "current_ip" {
  description = "Public IPv4 to whitelist for local tooling (psql/DBeaver). null skips the rule."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
