variable "name" {
  description = "Base name for Network Hub and Firewall resources"
  type        = string
  default     = "network-hub"
}

variable "vpc_cidr" {
  description = "CIDR block for the Central Inspection VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for multi-AZ high availability"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "tgw_subnet_cidrs" {
  description = "Subnet CIDRs for TGW attachment ENIs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "firewall_subnet_cidrs" {
  description = "Subnet CIDRs for AWS Network Firewall endpoints"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "egress_subnet_cidrs" {
  description = "Subnet CIDRs for Public NAT Gateways and IGW"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "transit_gateway_id" {
  description = "Identifier of the Central Transit Gateway"
  type        = string
}

variable "tgw_spoke_route_table_id" {
  description = "Identifier of the TGW Spoke Route Table to install inspection steering routes"
  type        = string
}

variable "tgw_post_inspection_route_table_id" {
  description = "Identifier of the TGW Post-Inspection Route Table to associate inspection attachment"
  type        = string
}

variable "blocked_egress_ports" {
  description = "List of TCP/UDP ports strictly prohibited from public internet egress"
  type        = list(number)
  default     = [22, 23, 25, 445, 1433, 3389]
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Environment = "Core"
    ManagedBy   = "Terraform"
    Component   = "CentralInspectionNetwork"
  }
}
