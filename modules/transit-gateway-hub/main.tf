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
# CENTRAL TRANSIT GATEWAY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ec2_transit_gateway" "this" {
  description                     = "Central Hub Transit Gateway for Enterprise Landing Zone"
  amazon_side_asn                 = var.amazon_side_asn
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(var.tags, {
    Name = "${var.name}-core"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# SEGMENTED ROUTE TABLES
# ---------------------------------------------------------------------------------------------------------------------
# 1. Spoke Route Table: Associated with all workload spokes (Dev, Prod, Shared Services).
# Sends ALL traffic (RFC1918 + 0.0.0.0/0) to the Inspection VPC attachment.
resource "aws_ec2_transit_gateway_route_table" "spokes" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-rt-spokes-inbound"
    Role = "SpokeTrafficIngress"
  })
}

# 2. Post-Inspection Route Table: Associated with the Inspection VPC attachment.
# Directs inspected packets onward to target Spoke VPCs.
resource "aws_ec2_transit_gateway_route_table" "post_inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-rt-post-inspection"
    Role = "FirewallEgressForwarding"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# AWS RAM RESOURCE SHARE (Multi-Account Distribution)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ram_resource_share" "tgw" {
  name                      = "share-${var.name}"
  allow_external_principals = false

  tags = merge(var.tags, {
    Name = "ram-share-${var.name}"
  })
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "org" {
  count              = var.organization_arn != "" ? 1 : 0
  principal          = var.organization_arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}
