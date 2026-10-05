variable "name" {
  description = "Name identifier for the spoke VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the Spoke VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "app_subnet_cidrs" {
  description = "Subnet CIDRs for application workloads"
  type        = list(string)
}

variable "data_subnet_cidrs" {
  description = "Subnet CIDRs for database and storage tiers"
  type        = list(string)
  default     = []
}

variable "tgw_subnet_cidrs" {
  description = "Subnet CIDRs dedicated for TGW cross-VPC ENIs"
  type        = list(string)
}

variable "transit_gateway_id" {
  description = "ID of the shared central Transit Gateway"
  type        = string
}

variable "tgw_spoke_route_table_id" {
  description = "TGW route table ID to associate this spoke attachment with"
  type        = string
}

variable "tgw_post_inspection_route_table_id" {
  description = "TGW route table ID to propagate this spoke VPC's CIDR into"
  type        = string
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC Flow Logs for security auditing"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
