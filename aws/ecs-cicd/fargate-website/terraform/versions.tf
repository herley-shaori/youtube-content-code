terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }
}
