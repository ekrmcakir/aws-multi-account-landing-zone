variable "organization_feature_set" {
  description = "The feature set of the organization. Must be ALL to enable SCPs."
  type        = string
  default     = "ALL"
}

variable "core_ous" {
  description = "List of core organizational units to create"
  type        = list(string)
  default     = ["Core", "Workloads", "Sandbox"]
}

variable "workload_sub_ous" {
  description = "Sub-organizational units under the Workloads OU"
  type        = list(string)
  default     = ["Production", "Non-Production"]
}

variable "core_accounts" {
  description = "Map of core baseline accounts to provision or attach"
  type = map(object({
    email     = string
    role_name = optional(string, "LandingZoneAdminRole")
  }))
  default = {
    "network-hub" = {
      email = "aws-network-hub@company.internal"
    }
    "security-tooling" = {
      email = "aws-security-tooling@company.internal"
    }
    "log-archive" = {
      email = "aws-log-archive@company.internal"
    }
    "shared-services" = {
      email = "aws-shared-services@company.internal"
    }
  }
}

variable "workload_accounts" {
  description = "Map of workload accounts categorized by sub-OU"
  type = map(object({
    email  = string
    sub_ou = string # "Production" or "Non-Production"
  }))
  default = {
    "workload-prod" = {
      email  = "aws-workload-prod@company.internal"
      sub_ou = "Production"
    }
    "workload-dev" = {
      email  = "aws-workload-dev@company.internal"
      sub_ou = "Non-Production"
    }
  }
}

variable "allowed_regions" {
  description = "List of approved AWS regions allowed by the SCP guardrails"
  type        = list(string)
  default     = ["eu-central-1", "eu-west-1", "us-east-1"]
}
