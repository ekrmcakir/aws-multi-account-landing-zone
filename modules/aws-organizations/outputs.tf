output "organization_id" {
  description = "The unique identifier of the AWS Organization"
  value       = aws_organizations_organization.this.id
}

output "organization_arn" {
  description = "The ARN of the AWS Organization"
  value       = aws_organizations_organization.this.arn
}

output "root_id" {
  description = "The identifier of the Root Organizational Unit"
  value       = aws_organizations_organization.this.roots[0].id
}

output "ou_core_id" {
  description = "Identifier of the Core OU"
  value       = aws_organizations_organizational_unit.core.id
}

output "ou_workloads_id" {
  description = "Identifier of the Workloads OU"
  value       = aws_organizations_organizational_unit.workloads.id
}

output "ou_workload_prod_id" {
  description = "Identifier of the Production sub-OU"
  value       = aws_organizations_organizational_unit.workload_prod.id
}

output "ou_workload_nonprod_id" {
  description = "Identifier of the Non-Production sub-OU"
  value       = aws_organizations_organizational_unit.workload_nonprod.id
}

output "core_account_ids" {
  description = "Map of Core account names to their 12-digit AWS account IDs"
  value       = { for k, v in aws_organizations_account.core_accounts : k => v.id }
}

output "workload_account_ids" {
  description = "Map of Workload account names to their 12-digit AWS account IDs"
  value       = { for k, v in aws_organizations_account.workload_accounts : k => v.id }
}

output "scp_policy_ids" {
  description = "Map of applied Service Control Policies to their IDs"
  value = {
    deny_root                  = aws_organizations_policy.deny_root.id
    prevent_leave_org          = aws_organizations_policy.prevent_leave_org.id
    deny_unauthorized_regions  = aws_organizations_policy.deny_unauthorized_regions.id
    protect_security_services  = aws_organizations_policy.protect_security_services.id
    enforce_s3_guardrails      = aws_organizations_policy.enforce_s3_guardrails.id
    protect_iam_roles          = aws_organizations_policy.protect_iam_roles.id
  }
}
