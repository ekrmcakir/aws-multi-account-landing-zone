# Common settings for AWS Organizations management
terraform {
  source = "${get_repo_root()}/modules/aws-organizations"
}

inputs = {
  organization_feature_set = "ALL"
  allowed_regions          = ["eu-central-1", "eu-west-1", "us-east-1"]
}
