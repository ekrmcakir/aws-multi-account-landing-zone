output "vpc_id" {
  description = "The ID of the Inspection VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "The CIDR block of the Inspection VPC"
  value       = aws_vpc.this.cidr_block
}

output "network_firewall_arn" {
  description = "The ARN of the AWS Network Firewall"
  value       = aws_networkfirewall_firewall.this.arn
}

output "network_firewall_policy_arn" {
  description = "The ARN of the AWS Network Firewall Policy"
  value       = aws_networkfirewall_firewall_policy.this.arn
}

output "tgw_attachment_id" {
  description = "The attachment ID linking the Inspection VPC to Transit Gateway"
  value       = aws_ec2_transit_gateway_vpc_attachment.inspection.id
}

output "nat_gateway_ips" {
  description = "Public Elastic IPs allocated to the NAT Gateways for centralized egress"
  value       = aws_eip.nat[*].public_ip
}
