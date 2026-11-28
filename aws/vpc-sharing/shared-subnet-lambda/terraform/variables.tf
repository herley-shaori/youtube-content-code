variable "account_id" {
  description = "AWS account that runs the function (the app account). Terraform refuses to touch any other account."
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

variable "shared_vpc_cidr" {
  description = "Address range of the VPC that the network account shares. It must match vpc_cidr of the network side."
  type        = string
  default     = "10.53.0.0/20"
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary for the IAM role this lab creates. Null means none. Set it when your account only lets you create roles that carry a boundary."
  type        = string
  default     = null
}
