output "vpc_id" {
  description = "The ID of the Spoke VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "The CIDR block of the Spoke VPC"
  value       = aws_vpc.this.cidr_block
}

output "app_subnet_ids" {
  description = "IDs of the application tier subnets"
  value       = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  description = "IDs of the database tier subnets"
  value       = aws_subnet.data[*].id
}

output "tgw_attachment_id" {
  description = "Transit Gateway Attachment ID for this spoke"
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
}
