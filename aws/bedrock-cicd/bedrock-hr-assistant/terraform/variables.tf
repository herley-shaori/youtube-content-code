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

variable "model_id" {
  type    = string
  default = "amazon.nova-lite-v1:0"
}

variable "reserved_concurrency" {
  description = "Upper limit of concurrent runs, which also caps the Bedrock bill."
  type        = number
  default     = 2
}

variable "create_github_oidc_provider" {
  description = "False when the account already has the GitHub OIDC provider."
  type        = bool
  default     = true
}

variable "github_repository" {
  description = "owner/name of the repository whose workflow deploys the app."
  type        = string
  default     = "herley-shaori/youtube-content-code"
}

variable "github_environment" {
  description = "GitHub environment the deploy job runs in."
  type        = string
  default     = "ai-stg"
}

variable "cloudflare_api_token" {
  description = "Token with DNS Edit and Zone WAF Edit on the zone. Pass it as TF_VAR_cloudflare_api_token."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "cloudflare_zone_name" {
  description = "Cloudflare zone that hosts the app, for example example.com."
  type        = string
}

variable "hostname" {
  description = "Public name of the app in that zone, for example hr-assistant.example.com."
  type        = string
}
