#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------------------------------------
# Multi-Account Terragrunt Execution Orchestrator
# Runs plan/apply across accounts in strict dependency order:
# 1. Management Account (Organizations, OUs, SCPs)
# 2. Network Hub (Transit Gateway & Central Firewall)
# 3. Workload Spokes (Prod, Dev, Shared Services)
# ---------------------------------------------------------------------------------------------------------------------

set -euo pipefail

ACTION="${1:-plan}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Executing Terragrunt order for action: $ACTION"

ORDERED_ACCOUNTS=(
  "account-management"
  "account-network-hub"
  "account-shared-services"
  "account-workload-dev"
  "account-workload-prod"
)

for acc in "${ORDERED_ACCOUNTS[@]}"; do
  echo "--------------------------------------------------------"
  echo "==> Processing Account: $acc ($ACTION)"
  echo "--------------------------------------------------------"
  cd "$ROOT_DIR/environments/$acc"
  if command -v terragrunt &> /dev/null; then
    terragrunt "$ACTION" --terragrunt-non-interactive
  else
    echo "Terragrunt not installed locally. Dry-run mode for $acc"
  fi
done

echo "==> Multi-Account orchestration finished successfully!"
