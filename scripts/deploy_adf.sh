#!/usr/bin/env bash
# Deploy ADF-internal objects (linked services + datasets) to pipelineiq-adf-dev.
#
# The factory resource + its MI RBAC are Terraform (core/adf/). This script
# publishes the Bicep objects ADF authors (bicep/adf/) via an incremental
# `az deployment group create`. Parameters are sourced from the velora
# Terraform outputs so there is a single source of truth — run `terraform
# apply` on clients/velora first (the factory must exist).
#
# Usage:
#   bash scripts/deploy_adf.sh            # deploy
#   bash scripts/deploy_adf.sh --what-if  # preview the diff, no changes
#
# build_order 6.2 + 6.3 (S18, Tier 6 chunk 1).

set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-pipelineiq-rg-dev}"
SUBSCRIPTION="${SUBSCRIPTION:-ea05f17f-b2bb-40ac-a391-afe41a9f5cbf}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BICEP_MAIN="$REPO_ROOT/bicep/adf/main.bicep"
TF_DIR="$REPO_ROOT/clients/velora"

MODE_FLAG=""
if [[ "${1:-}" == "--what-if" ]]; then
  MODE_FLAG="--what-if"
fi

echo "Ensuring active subscription is Sponsorship..."
az account set --subscription "$SUBSCRIPTION"

echo "Sourcing ADF deployment parameters from Terraform outputs ($TF_DIR)..."
pushd "$TF_DIR" >/dev/null
FACTORY_NAME="$(terraform output -raw adf_name)"
KEY_VAULT_BASE_URL="$(terraform output -raw key_vault_uri)"
ADLS_DFS_ENDPOINT="$(terraform output -raw adls_primary_dfs_endpoint)"
DBX_WORKSPACE_URL="$(terraform output -raw databricks_workspace_url)"
DBX_WORKSPACE_ARM_ID="$(terraform output -raw databricks_workspace_arm_id)"
popd >/dev/null

echo "  factoryName               = $FACTORY_NAME"
echo "  keyVaultBaseUrl           = $KEY_VAULT_BASE_URL"
echo "  adlsDfsEndpoint           = $ADLS_DFS_ENDPOINT"
echo "  databricksWorkspaceUrl    = $DBX_WORKSPACE_URL"
echo "  databricksWorkspaceArmId  = $DBX_WORKSPACE_ARM_ID"

echo "Deploying bicep/adf/main.bicep to $RESOURCE_GROUP (mode=incremental${MODE_FLAG:+, $MODE_FLAG})..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "adf-objects-$(date -u +%Y%m%d%H%M%S)" \
  --template-file "$BICEP_MAIN" \
  --parameters \
    factoryName="$FACTORY_NAME" \
    keyVaultBaseUrl="$KEY_VAULT_BASE_URL" \
    adlsDfsEndpoint="$ADLS_DFS_ENDPOINT" \
    databricksWorkspaceUrl="$DBX_WORKSPACE_URL" \
    databricksWorkspaceResourceId="$DBX_WORKSPACE_ARM_ID" \
  $MODE_FLAG

echo "Done. Linked services + datasets published to $FACTORY_NAME."
