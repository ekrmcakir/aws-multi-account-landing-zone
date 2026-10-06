# Common settings for Network Hub Transit Gateway and Firewall
terraform {
  source = "${get_repo_root()}/modules/central-network-firewall"
}

inputs = {
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["eu-central-1a", "eu-central-1b"]
  tgw_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
  firewall_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  egress_subnet_cidrs   = ["10.0.21.0/24", "10.0.22.0/24"]
}
