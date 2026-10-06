#!/usr/bin/env bash
set -euo pipefail

echo "=========================================================="
echo " AWS Multi-Account Landing Zone Architecture Validator"
echo "=========================================================="

echo "[1/5] Checking Terraform formatting..."
terraform fmt -check -recursive

echo "[2/5] Running SCP Policy syntax & guardrail tests..."
python3 tests/test_scp_policies.py

echo "[3/5] Running Transit Gateway deterministic routing simulator..."
python3 tests/test_tgw_routing_simulator.py

echo "[4/5] Running Architecture Intent & Purpose compliance suite..."
python3 tests/test_landing_zone_intent.py -v

echo "[5/5] Validating Terraform module schemas..."
MODULES=("aws-organizations" "transit-gateway-hub" "central-network-firewall" "spoke-vpc")

PLUGIN_DIR="/Users/ekremcakir/.gemini/antigravity-ide/scratch/aws-zero-egress-privatelink/terraform/.terraform/providers"

for m in "${MODULES[@]}"; do
  echo "  --> Validating module: $m"
  cd "modules/$m"
  if [ -d "$PLUGIN_DIR" ]; then
    terraform init -backend=false -plugin-dir="$PLUGIN_DIR" > /dev/null
  else
    terraform init -backend=false > /dev/null
  fi
  terraform validate
  rm -rf .terraform .terraform.lock.hcl
  cd ../..
done

echo "=========================================================="
echo " SUCCESS: All Landing Zone validations and tests passed!"
echo "=========================================================="
