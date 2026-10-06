include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../_env/organizations.hcl"
}

inputs = {
  core_ous = ["Core", "Workloads", "Sandbox"]
  allowed_regions = [
    "eu-central-1",
    "eu-west-1",
    "us-east-1"
  ]
}
