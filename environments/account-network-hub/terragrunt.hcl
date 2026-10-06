include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/modules/transit-gateway-hub"
}

inputs = {
  name            = "central-hub"
  amazon_side_asn = 64512
  tags = {
    Environment = "Core"
    Account     = "NetworkHub"
    Role        = "CentralTransitGateway"
  }
}
