# ---------------------------------------------------------------------------------------------------------------------
# AWS ORGANIZATIONS TAG POLICIES (Cost Allocation & Governance)
# Enforces standard tagging schema across all member accounts in the organization
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_organizations_policy" "tag_policy" {
  name        = "TAG-MandatoryResourceTags"
  description = "Enforces standardized tags (Environment, Project, Owner, CostCenter) across resources"
  type        = "TAG_POLICY"

  content = jsonencode({
    tags = {
      Environment = {
        tag_key = {
          "@@assign" = "Environment"
        }
        tag_value = {
          "@@assign" = [
            "Production",
            "Non-Production",
            "Core",
            "Sandbox"
          ]
        }
        enforced_for = {
          "@@assign" = [
            "ec2:instance",
            "ec2:volume",
            "ec2:vpc",
            "s3:bucket"
          ]
        }
      }
      ManagedBy = {
        tag_key = {
          "@@assign" = "ManagedBy"
        }
        tag_value = {
          "@@assign" = [
            "Terraform",
            "Terragrunt"
          ]
        }
      }
      CostCenter = {
        tag_key = {
          "@@assign" = "CostCenter"
        }
      }
    }
  })
}

resource "aws_organizations_policy_attachment" "root_tag_policy" {
  policy_id = aws_organizations_policy.tag_policy.id
  target_id = aws_organizations_organization.this.roots[0].id
}
