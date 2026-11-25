# First step of the lab: only the bucket that will hold the website files.
# Nothing is public yet.

provider "aws" {
  profile             = var.aws_profile
  region              = var.aws_region
  allowed_account_ids = [var.account_id]

  dynamic "assume_role" {
    for_each = var.assume_role_name == null ? [] : [var.assume_role_name]
    content {
      role_arn     = "arn:aws:iam::${var.account_id}:role/${assume_role.value}"
      session_name = "terraform-static-website"
    }
  }

  default_tags {
    tags = {
      "app-name"  = "static-website"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

resource "aws_s3_bucket" "website" {
  # Bucket names are global, so AWS adds a unique suffix to this prefix.
  bucket_prefix = "static-website-${var.environment}-"
  # Lets terraform destroy remove the bucket together with the lab files.
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
