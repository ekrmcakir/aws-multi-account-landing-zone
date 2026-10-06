# Common settings for Spoke Workload VPCs
terraform {
  source = "${get_repo_root()}/modules/spoke-vpc"
}

inputs = {
  availability_zones = ["eu-central-1a", "eu-central-1b"]
  enable_flow_logs   = true
}
