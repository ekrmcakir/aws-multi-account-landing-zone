include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = "${get_terragrunt_dir()}/../_env/spoke-vpc.hcl"
}

dependency "network_hub" {
  config_path = "../account-network-hub"
  mock_outputs = {
    transit_gateway_id             = "tgw-mock-12345678"
    spoke_route_table_id           = "tgw-rtb-mock-spoke"
    post_inspection_route_table_id = "tgw-rtb-mock-inspection"
  }
}

inputs = {
  name             = "workload-prod"
  vpc_cidr         = "10.1.0.0/16"
  app_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
  data_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
  tgw_subnet_cidrs = ["10.1.100.0/24", "10.1.101.0/24"]

  transit_gateway_id             = dependency.network_hub.outputs.transit_gateway_id
  tgw_spoke_route_table_id       = dependency.network_hub.outputs.spoke_route_table_id
  tgw_post_inspection_route_table_id = dependency.network_hub.outputs.post_inspection_route_table_id

  tags = {
    Environment = "Production"
    Account     = "WorkloadProd"
    Compliance  = "PCI-DSS-HIPAA"
  }
}
