# AWS side of the lab: the bucket that holds the website files, the page itself, and
# S3 static website hosting. Cloudflare (cloudflare.tf) is the only way in.

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
  # S3 website hosting finds the bucket by the Host header of the request, so the
  # bucket must carry the public name of the website.
  bucket = var.hostname
  # Lets terraform destroy remove the bucket together with the lab files.
  force_destroy = true
}

# All four stay on. The bucket policy below is limited to fixed IP ranges, which S3
# does not count as public.
resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# The website itself: one page, uploaded again whenever the file changes.
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  source       = "${path.module}/../app/index.html"
  etag         = filemd5("${path.module}/../app/index.html")
  content_type = "text/html; charset=utf-8"
}

# Turns the bucket into a web server: / answers with index.html. This endpoint speaks
# HTTP only, so Cloudflare provides HTTPS to visitors.
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }
}

# Shared with Cloudflare, which sends it with every request it forwards.
resource "random_password" "origin_secret" {
  length  = 48
  special = false
}

# Reading a file needs both: a request from Cloudflare's network, and the secret that
# only our own Cloudflare zone sends. Everyone else gets 403.
data "aws_iam_policy_document" "website" {
  statement {
    sid       = "ReadOnlyThroughOurCloudflareZone"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = data.cloudflare_ip_ranges.cloudflare.ipv4_cidrs
    }

    # ponytail: S3 can only check the Referer or User-Agent header, so the secret
    # travels as Referer. Use CloudFront with origin access control outside a lab.
    condition {
      test     = "StringEquals"
      variable = "aws:Referer"
      values   = [random_password.origin_secret.result]
    }
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json

  depends_on = [aws_s3_bucket_public_access_block.website]
}
