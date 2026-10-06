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
# CENTRAL INSPECTION VPC
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name}-inspection-vpc"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# SUBNETS
# ---------------------------------------------------------------------------------------------------------------------
# Subnets for Transit Gateway Attachment ENIs
resource "aws_subnet" "tgw" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.tgw_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-subnet-tgw-${var.availability_zones[count.index]}"
    Role = "TGWAttachment"
  })
}

# Subnets for AWS Network Firewall Endpoints
resource "aws_subnet" "firewall" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.firewall_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-subnet-firewall-${var.availability_zones[count.index]}"
    Role = "NetworkFirewallEndpoints"
  })
}

# Subnets for Egress (NAT Gateways & IGW)
resource "aws_subnet" "egress" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.egress_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-subnet-egress-${var.availability_zones[count.index]}"
    Role = "PublicEgressNAT"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# INTERNET GATEWAY & NAT GATEWAYS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-eip-nat-${var.availability_zones[count.index]}"
  })
}

resource "aws_nat_gateway" "this" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.egress[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name}-natgw-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.this]
}

# ---------------------------------------------------------------------------------------------------------------------
# AWS NETWORK FIREWALL
# ---------------------------------------------------------------------------------------------------------------------
# Stateful Rule Group: Egress protocol filtering and domain policy
resource "aws_networkfirewall_rule_group" "stateful_domain_and_ips" {
  capacity = 1000
  name     = "${var.name}-stateful-rules"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = <<EOF
drop tcp any any -> any [22,23,25,445,1433,3389] (msg:"SECURITY ALERT: Blocked insecure outbound management port"; sid:1000001; rev:1;)
pass tls any any -> any 443 (tls.sni; content:".amazonaws.com"; endswith; msg:"Allow AWS API communication"; sid:1000002; rev:1;)
pass tls any any -> any 443 (tls.sni; content:".github.com"; endswith; msg:"Allow GitHub CI/CD repository egress"; sid:1000003; rev:1;)
pass udp any any -> any 53 (msg:"Allow DNS queries"; sid:1000004; rev:1;)
pass tcp any any -> any 53 (msg:"Allow DNS TCP queries"; sid:1000005; rev:1;)
EOF
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-nfw-stateful-rules"
  })
}

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.name}-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:drop"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateful_domain_and_ips.arn
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-nfw-policy"
  })
}

resource "aws_networkfirewall_firewall" "this" {
  name                = "${var.name}-nfw"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = aws_vpc.this.id

  dynamic "subnet_mapping" {
    for_each = aws_subnet.firewall[*].id
    content {
      subnet_id = subnet_mapping.value
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-nfw-cluster"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# TRANSIT GATEWAY ATTACHMENT & STEERING
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ec2_transit_gateway_vpc_attachment" "inspection" {
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.this.id
  subnet_ids         = aws_subnet.tgw[*].id

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-attachment"
  })
}

# Associate inspection attachment to post_inspection route table
resource "aws_ec2_transit_gateway_route_table_association" "inspection" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = var.tgw_post_inspection_route_table_id
}

# Steering routes on TGW Spoke Route Table: Send ALL Spoke traffic to inspection VPC attachment
resource "aws_ec2_transit_gateway_route" "spoke_default_to_inspection" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = var.tgw_spoke_route_table_id
}

resource "aws_ec2_transit_gateway_route" "spoke_rfc1918_to_inspection" {
  destination_cidr_block         = "10.0.0.0/8"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = var.tgw_spoke_route_table_id
}

# ---------------------------------------------------------------------------------------------------------------------
# ROUTE TABLES: TGW, FIREWALL, EGRESS
# ---------------------------------------------------------------------------------------------------------------------
# Helper local to extract endpoint IDs per AZ
locals {
  firewall_status_sync_states = flatten([
    for status in aws_networkfirewall_firewall.this.firewall_status : [
      for state in status.sync_states : {
        az          = state.availability_zone_name
        endpoint_id = state.attachment[0].endpoint_id
      }
    ]
  ])

  firewall_endpoints_by_az = {
    for item in local.firewall_status_sync_states : item.az => item.endpoint_id
  }
}

# 1. TGW Subnet Route Tables (Traffic from TGW sent to Network Firewall Endpoint)
resource "aws_route_table" "tgw" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = lookup(local.firewall_endpoints_by_az, var.availability_zones[count.index], null)
  }

  tags = merge(var.tags, {
    Name = "${var.name}-rt-tgw-${var.availability_zones[count.index]}"
  })
}

resource "aws_route_table_association" "tgw" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.tgw[count.index].id
  route_table_id = aws_route_table.tgw[count.index].id
}

# 2. Firewall Subnet Route Tables (After inspection, send internet traffic to NAT GW and internal traffic to TGW)
resource "aws_route_table" "firewall" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = var.transit_gateway_id
  }

  tags = merge(var.tags, {
    Name = "${var.name}-rt-firewall-${var.availability_zones[count.index]}"
  })
}

resource "aws_route_table_association" "firewall" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.firewall[count.index].id
  route_table_id = aws_route_table.firewall[count.index].id
}

# 3. Egress/NAT Subnet Route Tables (Default to IGW, Return Spoke traffic back to Firewall)
resource "aws_route_table" "egress" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  route {
    cidr_block      = "10.0.0.0/8"
    vpc_endpoint_id = lookup(local.firewall_endpoints_by_az, var.availability_zones[count.index], null)
  }

  tags = merge(var.tags, {
    Name = "${var.name}-rt-egress-${var.availability_zones[count.index]}"
  })
}

resource "aws_route_table_association" "egress" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.egress[count.index].id
  route_table_id = aws_route_table.egress[count.index].id
}
