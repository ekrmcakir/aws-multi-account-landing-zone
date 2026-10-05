variable "name" {
  description = "Base name for Transit Gateway resources"
  type        = string
  default     = "hub-tgw"
}

variable "amazon_side_asn" {
  description = "Private Autonomous System Number (ASN) for the Amazon side of BGP session"
  type        = number
  default     = 64512
}

variable "organization_arn" {
  description = "ARN of the AWS Organization to share the Transit Gateway with via RAM"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default = {
    Environment = "Core"
    ManagedBy   = "Terraform"
    Component   = "TransitGatewayHub"
  }
}
