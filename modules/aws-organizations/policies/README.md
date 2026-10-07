# 🛡️ Service Control Policies (SCPs) Reference Guide

This directory contains the foundational Service Control Policies deployed across the AWS Organization to establish preventive security guardrails.

## Policy Catalog

| Policy File | Target Attachment | Primary Objective | Bypass Prevention |
| :--- | :--- | :--- | :--- |
| `deny_root_account_usage.json` | Root OU | Blocks all actions executed with AWS Account root credentials | Root IAM ARN matching |
| `deny_unauthorized_regions.json` | Core, Workloads OUs | Blocks resource provisioning outside approved regions | Geolocation data residency |
| `protect_security_services.json` | Workloads OU | Prevents teardown of CloudTrail, GuardDuty, Config, Flow Logs | Tamper-proof auditing |
| `prevent_leaving_organization.json` | Root OU | Prevents member accounts from detaching | Centralized billing retention |
| `enforce_s3_encryption_and_block_public.json` | Workloads OU | Enforces KMS/SSE encryption and blocks public buckets | S3 exfiltration guardrail |
| `deny_modifying_security_roles.json` | Core, Workloads OUs | Prevents modifying or deleting breakglass audit roles | Role integrity protection |

## Evaluation Precedence
SCPs act as authorization filters. If any policy attached at any level in the hierarchy (Root, OU, or Account) denies an action, the final evaluation is **DENY**, overriding all IAM identity-based policies.
