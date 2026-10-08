# 💰 FinOps & Cost Optimization Guide

## Architecture Cost Efficiency Analysis

In a traditional multi-account topology with 5+ accounts each running dual-AZ NAT Gateways:
- **Decentralized NAT Gateway Cost:**
  - 5 accounts × 2 AZs × $0.045/hr × 730 hrs ≈ **$657 / month base charge** (excluding traffic processing fees).
- **Centralized Hub Architecture Cost:**
  - 1 Central Hub × 2 AZs × $0.045/hr × 730 hrs ≈ **$65.70 / month base charge**.
  - **Net Infrastructure Savings:** **~90% reduction** in idle NAT Gateway charges across the organization.

## Cost Monitoring & Tagging Enforcement
With the deployed `TAG-MandatoryResourceTags` Tag Policy, all compute, storage, and VPC assets must report:
1. `CostCenter` for departmental chargeback.
2. `Environment` (`Production`, `Non-Production`, `Sandbox`) for budget boundary alerts in AWS Cost Explorer.
3. `ManagedBy: Terragrunt` for identifying orphaned, manually created resources.
