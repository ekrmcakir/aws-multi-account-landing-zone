terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# AWS ORGANIZATIONS ROOT & SERVICE ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_organizations_organization" "this" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "ram.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com"
  ]
  feature_set = var.organization_feature_set
  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY"
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# TOP-LEVEL ORGANIZATIONAL UNITS (OUs)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_organizations_organizational_unit" "core" {
  name      = "Core"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.this.roots[0].id
}

# ---------------------------------------------------------------------------------------------------------------------
# WORKLOAD NESTED OUs
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_organizations_organizational_unit" "workload_prod" {
  name      = "Production"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "workload_nonprod" {
  name      = "Non-Production"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

# ---------------------------------------------------------------------------------------------------------------------
# MEMBER ACCOUNTS CREATION
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_organizations_account" "core_accounts" {
  for_each  = var.core_accounts
  name      = each.key
  email     = each.value.email
  parent_id = aws_organizations_organizational_unit.core.id
  role_name = each.value.role_name

  close_on_deletion = false

  lifecycle {
    ignore_changes = [role_name]
  }
}

resource "aws_organizations_account" "workload_accounts" {
  for_each = var.workload_accounts
  name     = each.key
  email    = each.value.email
  parent_id = each.value.sub_ou == "Production" ? (
    aws_organizations_organizational_unit.workload_prod.id
  ) : aws_organizations_organizational_unit.workload_nonprod.id
  role_name = "LandingZoneAdminRole"

  close_on_deletion = false

  lifecycle {
    ignore_changes = [role_name]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SERVICE CONTROL POLICIES (SCPs)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_organizations_policy" "deny_root" {
  name        = "SCP-DenyRootAccountUsage"
  description = "Denies all direct actions attempted by the AWS root account credentials."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/deny_root_account_usage.json")
}

resource "aws_organizations_policy" "prevent_leave_org" {
  name        = "SCP-PreventLeavingOrganization"
  description = "Prevents any member account from detaching or leaving the AWS Organization."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/prevent_leaving_organization.json")
}

resource "aws_organizations_policy" "deny_unauthorized_regions" {
  name        = "SCP-DenyUnauthorizedRegions"
  description = "Enforces geolocation sovereignty by restricting AWS API operations outside approved regions."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/deny_unauthorized_regions.json")
}

resource "aws_organizations_policy" "protect_security_services" {
  name        = "SCP-ProtectSecurityBaselines"
  description = "Prevents modification or teardown of CloudTrail, GuardDuty, Config, and VPC Flow Logs."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/protect_security_services.json")
}

resource "aws_organizations_policy" "enforce_s3_guardrails" {
  name        = "SCP-EnforceS3EncryptionAndBlockPublic"
  description = "Restricts altering public access block and mandates KMS/AES-256 SSE encryption on object writes."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/enforce_s3_encryption_and_block_public.json")
}

resource "aws_organizations_policy" "protect_iam_roles" {
  name        = "SCP-ProtectSecurityRoles"
  description = "Locks down administrative and security audit cross-account IAM roles against tampering."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/deny_modifying_security_roles.json")
}

# ---------------------------------------------------------------------------------------------------------------------
# SCP POLICY ATTACHMENTS
# ---------------------------------------------------------------------------------------------------------------------
# Universal Root Level Attachments (Applied to all OUs & accounts)
resource "aws_organizations_policy_attachment" "root_deny_root" {
  policy_id = aws_organizations_policy.deny_root.id
  target_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy_attachment" "root_prevent_leave" {
  policy_id = aws_organizations_policy.prevent_leave_org.id
  target_id = aws_organizations_organization.this.roots[0].id
}

# Core OU Attachments
resource "aws_organizations_policy_attachment" "core_regions" {
  policy_id = aws_organizations_policy.deny_unauthorized_regions.id
  target_id = aws_organizations_organizational_unit.core.id
}

resource "aws_organizations_policy_attachment" "core_protect_roles" {
  policy_id = aws_organizations_policy.protect_iam_roles.id
  target_id = aws_organizations_organizational_unit.core.id
}

# Workloads OU Attachments
resource "aws_organizations_policy_attachment" "workloads_regions" {
  policy_id = aws_organizations_policy.deny_unauthorized_regions.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "workloads_security_services" {
  policy_id = aws_organizations_policy.protect_security_services.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "workloads_s3" {
  policy_id = aws_organizations_policy.enforce_s3_guardrails.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "workloads_protect_roles" {
  policy_id = aws_organizations_policy.protect_iam_roles.id
  target_id = aws_organizations_organizational_unit.workloads.id
}
