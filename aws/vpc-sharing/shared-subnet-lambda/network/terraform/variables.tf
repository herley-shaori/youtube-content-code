variable "account_id" {
  description = "AWS account that owns the VPC (the network account). Terraform refuses to touch any other account."
  type        = string
}

variable "aws_profile" {
  description = "Local AWS CLI profile used by Terraform."
  type        = string
}

variable "assume_role_name" {
  description = "Role to assume in account_id, for example OrganizationAccountAccessRole. Null uses the profile directly."
  type        = string
  default     = null
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-3"
}

variable "environment" {
  description = "Short environment name, used in resource names."
  type        = string
  default     = "stg"
}

variable "vpc_cidr" {
  description = "Address range of the shared VPC. It must be a /20, and must not overlap a network you want to connect later."
  type        = string
  default     = "10.53.0.0/20"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && endswith(var.vpc_cidr, "/20")
    error_message = "vpc_cidr must be a valid /20 range such as 10.53.0.0/20."
  }
}

variable "share_with" {
  description = "Who receives the subnets: account IDs, or the ARN of an organizational unit or of the whole organization. All of them must be in your AWS Organization. Empty means the VPC exists but nothing is shared yet."
  type        = list(string)
  default     = []
}
