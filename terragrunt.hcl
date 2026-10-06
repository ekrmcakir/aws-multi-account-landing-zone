# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT ROOT CONFIGURATION
# Configures remote state in S3/DynamoDB and provides unified AWS provider generators across all accounts.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  default_region = "eu-central-1"
  project_name   = "enterprise-landing-zone"
}

# Generate AWS provider block per child module
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "${local.default_region}"
  default_tags {
    tags = {
      Project     = "${local.project_name}"
      ManagedBy   = "Terragrunt"
      Environment = path_relative_to_include()
    }
  }
}
EOF
}

# Remote state management configuration
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "company-tfstate-${get_aws_account_id()}-${local.default_region}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.default_region
    encrypt        = true
    dynamodb_table = "company-tfstate-locks"
  }
}
