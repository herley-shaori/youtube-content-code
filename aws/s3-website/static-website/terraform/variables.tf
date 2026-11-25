variable "account_id" {
  description = "AWS account to deploy to. Terraform refuses to touch any other account."
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
