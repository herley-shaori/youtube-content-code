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

variable "desired_count" {
  description = "Number of tasks the service keeps running."
  type        = number
  default     = 2
}

variable "initial_image_tag" {
  description = "Image tag of the first task definition. Tasks cannot start until the pipeline has pushed this tag."
  type        = string
  default     = "v1.0"
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary for the IAM roles this lab creates. Null means none. Set it when your account only lets you create roles that carry a boundary."
  type        = string
  default     = null
}

variable "create_github_oidc_provider" {
  description = "False when the account already has the GitHub OIDC provider."
  type        = bool
  default     = true
}

variable "github_repository" {
  description = "owner/name of the repository whose workflow deploys the website."
  type        = string
  default     = "herley-shaori/youtube-content-code"
}

variable "github_environment" {
  description = "GitHub environment the push and deploy jobs run in."
  type        = string
  default     = "app-stg"
}

variable "github_deploy_tag_pattern" {
  description = "Only tags matching this pattern can deploy to the GitHub environment."
  type        = string
  default     = "fargate-website-stg-v*"
}

variable "public_access" {
  description = "False keeps the Cloudflare block rule on. True opens the website to everyone."
  type        = bool
  default     = false
}

variable "origin_header" {
  description = "Request header that carries the origin secret from Cloudflare to the load balancer."
  type        = string
  default     = "x-origin-verify"
}

variable "cloudflare_api_token" {
  description = "Token with Zone Read, DNS Edit, Zone WAF Edit and Transform Rules Edit on the zone. Pass it as TF_VAR_cloudflare_api_token."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "cloudflare_zone_name" {
  description = "Cloudflare zone that hosts the website, for example example.com."
  type        = string
}

variable "hostname" {
  description = "Public name of the website in that zone, for example hello.example.com."
  type        = string
}
