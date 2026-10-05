output "transit_gateway_id" {
  description = "The ID of the central Transit Gateway"
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "The ARN of the central Transit Gateway"
  value       = aws_ec2_transit_gateway.this.arn
}

output "spoke_route_table_id" {
  description = "The ID of the TGW route table associated with Spoke VPCs"
  value       = aws_ec2_transit_gateway_route_table.spokes.id
}

output "post_inspection_route_table_id" {
  description = "The ID of the TGW route table associated with the Inspection VPC"
  value       = aws_ec2_transit_gateway_route_table.post_inspection.id
}

output "ram_resource_share_arn" {
  description = "The ARN of the RAM share for Transit Gateway"
  value       = aws_ram_resource_share.tgw.arn
}
