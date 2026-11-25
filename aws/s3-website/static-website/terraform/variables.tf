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

variable "public_access" {
  description = "False keeps the Cloudflare block rule on. True opens the website to everyone."
  type        = bool
  default     = false
}

variable "cloudflare_api_token" {
  description = "Token with Zone Read, DNS Edit, Zone WAF Edit, Transform Rules Edit and Config Rules Edit on the zone. Pass it as TF_VAR_cloudflare_api_token."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "cloudflare_zone_name" {
  description = "Cloudflare zone that hosts the website, for example example.com."
  type        = string
}

variable "hostname" {
  description = "Public name of the website in that zone, for example s3.example.com. It is also the bucket name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]+[a-z0-9]$", var.hostname))
    error_message = "hostname must be a lowercase DNS name such as s3.example.com."
  }
}
