# Cloudflare side: the only public entrance to the website. It blocks every request
# until var.public_access is true.

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "main" {
  filter = { name = var.cloudflare_zone_name }
}

# The addresses Cloudflare calls origins from. The bucket policy accepts only these.
data "cloudflare_ip_ranges" "cloudflare" {}

locals {
  for_this_website = "(http.host eq \"${var.hostname}\")"
}

# ponytail: a zone has one ruleset per phase, so each of the three rulesets below owns
# its whole phase in the zone. Labs that share a zone must share these resources.
resource "cloudflare_ruleset" "waf_custom" {
  zone_id     = data.cloudflare_zone.main.zone_id
  name        = "Zone custom rules"
  description = "Managed by Terraform (static-website)"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules = [{
    description = "static-website: block all traffic until the website is opened"
    expression  = local.for_this_website
    action      = "block"
    enabled     = !var.public_access
  }]
}

# Cloudflare adds the secret to every request for the website. The bucket policy
# refuses requests without it.
resource "cloudflare_ruleset" "origin_secret" {
  zone_id     = data.cloudflare_zone.main.zone_id
  name        = "Zone request header rules"
  description = "Managed by Terraform (static-website)"
  kind        = "zone"
  phase       = "http_request_late_transform"

  rules = [{
    description = "static-website: prove to the bucket that the request came through this zone"
    expression  = local.for_this_website
    action      = "rewrite"
    enabled     = true
    action_parameters = {
      headers = {
        referer = {
          operation = "set"
          value     = random_password.origin_secret.result
        }
      }
    }
  }]
}

# The S3 website endpoint has no HTTPS, so Cloudflare must call it over HTTP. Visitors
# still use HTTPS up to Cloudflare.
resource "cloudflare_ruleset" "origin_http" {
  zone_id     = data.cloudflare_zone.main.zone_id
  name        = "Zone configuration rules"
  description = "Managed by Terraform (static-website)"
  kind        = "zone"
  phase       = "http_config_settings"

  rules = [{
    description = "static-website: reach the S3 website endpoint over HTTP"
    expression  = local.for_this_website
    action      = "set_config"
    enabled     = true
    action_parameters = {
      ssl = "flexible"
    }
  }]
}

# Proxied, so visitors reach Cloudflare, never the bucket directly.
resource "cloudflare_dns_record" "website" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = var.hostname
  type    = "CNAME"
  content = aws_s3_bucket_website_configuration.website.website_endpoint
  ttl     = 1
  proxied = true
  comment = "static-website S3 website endpoint, managed by Terraform"

  # The name must never be live without the block rule and the secret.
  depends_on = [
    cloudflare_ruleset.waf_custom,
    cloudflare_ruleset.origin_secret,
    cloudflare_ruleset.origin_http,
    aws_s3_bucket_policy.website,
  ]
}
