# PipelineIQ — Infrastructure as Code

**Terraform + Bicep for every Azure resource in the PipelineIQ platform.**

This repo is the single source of truth for infrastructure. Any resource not defined here is either legacy (to be migrated) or drift (to be reconciled or destroyed). Nothing gets clicked into the Azure portal.

For the project overview, architecture rationale, and decision log, see the companion repo:
**[`pipelineiq-architecture`](https://github.com/mohangowdat-sail/pipelineiq-architecture)**.

---

## What lives here

- **Reusable Terraform modules** for every Azure service PipelineIQ uses
- **Per-client composition roots** wiring those modules together for a specific tenant
- **Bicep templates** for ADF-internal objects (linked services, datasets, pipelines) where Bicep is more natural than Terraform
- **Bootstrap scripts** for state backend and module scaffolding

Architectural decisions live in the Architecture repo. This repo encodes them — it does not debate them.

---

## Layout

```
core/                     Reusable core modules. Stable — changes require a
                          DECISIONS.md entry in the Architecture repo.
  keyvault/               RBAC-auth Key Vault with inline role grants
  log_analytics/          Workspace (PerGB2018, 30-day retention)
  adls/                   ADLS Gen2 + filesystems (landing/bronze/silver/gold/quarantine)
  (future: postgres/, databricks/, openai/, functions/, container_apps/, ...)

source_connectors/        One module per source-system type. Clients compose these.
  azure_sql/              Used by Velora — ADF linked service + parameterised dataset
  blob_storage/           Stub — future file-drop clients
  http_api/               Stub — future REST API clients
  eventhub/               Stub — future streaming clients

clients/                  Composition roots. One folder per client.
  velora/                 Velora Retail. backend.tf + providers.tf + main.tf +
                          variables.tf + terraform.tfvars (gitignored).

pipelineiq_app/           PipelineIQ platform's own infrastructure — the pieces
                          of the SaaS platform itself, not the client-data side.
                          FastAPI Container App, Azure Functions, Static Web Apps.

bicep/                    Bicep modules.
  adf/                    ADF linked services, datasets, pipelines.

scripts/                  Plan/apply wrappers, auth helpers, module scaffolds.
```

---

## Prerequisites

- **Terraform ≥ 1.6** (pinned via `.terraform-version` — we're on 1.14.8)
- **Azure CLI** logged in to the target subscription
- **State backend already bootstrapped** — run `scripts/bootstrap_state.sh` in the Architecture repo first

Current state backend (shared across all clients):

| Resource | Value |
|---|---|
| Resource group | `pipelineiq-rg-dev` |
| Storage account | `pipelineiqtfstate` |
| Container | `tfstate` |
| State key per client | `{client}.tfstate` (e.g. `velora.tfstate`) |

---

## Getting started

```bash
# Clone next to the Architecture repo
git clone https://github.com/mohangowdat-sail/pipelineiq-iac.git
cd pipelineiq-iac/clients/velora

# Configure
cp terraform.tfvars.example terraform.tfvars
# Fill in subscription_id and tenant_id (terraform.tfvars is gitignored)

# Standard flow
terraform fmt -recursive
terraform init              # Once per workspace
terraform validate
terraform plan -out=tfplan  # Always save the plan
terraform apply tfplan      # Apply the exact plan you reviewed
```

**Never `terraform apply` without a saved plan. Never edit state directly.**

---

## Current provisioning status

Live dependency-ordered tracker in the Architecture repo: [`docs/build_order.md`](https://github.com/mohangowdat-sail/pipelineiq-architecture/blob/main/docs/build_order.md).

| Tier | Scope | Status |
|---|---|---|
| 0 | Local developer environment | Done (except msodbc install — blocked) |
| 1 | Azure subscription + state backend | Done |
| 2 | Core platform (Key Vault, Log Analytics, ADLS Gen2) | Plan ready, apply pending |
| 3 | Source connector (Azure SQL — Velora) | Pending |
| 4 | Control plane (PostgreSQL + Functions) | Pending |
| 5 | Compute + lakehouse (Databricks + Unity Catalog) | Pending |
| 6 | Orchestration (ADF, Bicep) | Pending |
| 7 | AI + RCA (Azure OpenAI + Container Apps + FastAPI) | Pending |
| 8 | Dashboard + webhooks (Static Web Apps, Event Grid → Slack) | Pending |

---

## Module stability

| Module | Status | Rule |
|---|---|---|
| `core/` | Stable once applied | Changes require an entry in Architecture's `DECISIONS.md` |
| `source_connectors/azure_sql/` | Stable | Velora source — change with care |
| `source_connectors/*/` (stubs) | Unbuilt | Scaffold only — build when a new client needs them |
| `clients/velora/` | Config | Safe to update variables and module versions |
| `pipelineiq_app/` | In progress | Built alongside Phases 2–6 |
| `bicep/adf/` | In progress | Built alongside Phase 2 |

---

## Design conventions

- **Submodule pattern.** Every service gets its own folder under `core/` with `main.tf` + `variables.tf` + `outputs.tf`. Client compositions import submodules and wire them together. Flat module files don't scale past one client. See Architecture DECISIONS #29.
- **Single-RG dev topology.** State backend and workload resources share `pipelineiq-rg-dev`. The RG is created by `bootstrap_state.sh` and referenced as a `data "azurerm_resource_group"` source, sidestepping the chicken/egg of Terraform managing the RG that holds its own state. See Architecture DECISIONS #28.
- **Inline RBAC grants.** Each core module optionally grants the running principal the data-plane role at creation time (Key Vault Secrets Officer, Storage Blob Data Owner, etc.). Closes the bootstrap gap where the first apply creates the resource but fails on sub-resources because the principal has no data-plane permission yet. Controlled by a `grant_current_user_*` bool. See Architecture DECISIONS #30.
- **Provider pinned.** `azurerm ~> 4.0` via `.terraform.lock.hcl`. Every developer gets the same provider binary. See Architecture DECISIONS #27.
- **Region strategy.** All resources in **Central India** except Azure OpenAI, which lives in **South India** (Central India does not host Azure OpenAI). Cross-region call is async RCA, latency immaterial. See Architecture DECISIONS #10 and #25.

---

## Naming convention

All Azure resources: `pipelineiq-{component}-{environment}`
Examples: `pipelineiq-kv-dev`, `pipelineiq-adls-dev`, `pipelineiq-sql-dev`.

Required tags on every resource:

```hcl
tags = {
  project     = "pipelineiq"
  environment = var.environment
  owner       = "data-engineering"
  managed_by  = "terraform"
}
```

---

## Adding a new client

A new client is always `clients/{client_name}/` + fill in variables + `terraform apply`. The `core/` and `source_connectors/` modules do not change.

```bash
cp -r clients/velora clients/acme
cd clients/acme
# Edit main.tf — update name_prefix, pick source connector modules to wire
# Edit terraform.tfvars — fill in acme-specific values
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

The multi-tenant story is documented as-we-build rather than pre-abstracted. See Architecture DECISIONS #7.

---

## Companion repo

**[`pipelineiq-architecture`](https://github.com/mohangowdat-sail/pipelineiq-architecture)** — the project's spec, docs, and application code. Read that first if you're new to PipelineIQ.

---

*PipelineIQ is an independent portfolio project. Velora Retail Group is a synthetic dataset, not a real company.*
