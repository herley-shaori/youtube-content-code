# Cloudflare side: the only public entrance to the website. It blocks every request
# until var.public_access is true.

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "main" {
  filter = { name = var.cloudflare_zone_name }
}

locals {
  acm_validation = one(aws_acm_certificate.web.domain_validation_options)
}

# Proves to AWS Certificate Manager that the public name is ours. Not proxied.
resource "cloudflare_dns_record" "acm_validation" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = trimsuffix(local.acm_validation.resource_record_name, ".")
  type    = local.acm_validation.resource_record_type
  content = trimsuffix(local.acm_validation.resource_record_value, ".")
  ttl     = 60
  proxied = false
  comment = "fargate-website certificate validation, managed by Terraform"
}

# A zone has one custom-rules ruleset, so this resource owns all WAF custom rules of
# the zone. Add rules for other hostnames here instead of in a second ruleset.
resource "cloudflare_ruleset" "waf_custom" {
  zone_id     = data.cloudflare_zone.main.zone_id
  name        = "Zone custom rules"
  description = "Managed by Terraform (fargate-website)"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules = [{
    description = "fargate-website: block all traffic until the website is opened"
    expression  = "(http.host eq \"${var.hostname}\")"
    action      = "block"
    enabled     = !var.public_access
  }]
}

# Cloudflare adds the secret header to every request for the website. The load
# balancer forwards only requests that carry it. Like the custom rules above, a zone
# has one ruleset for this phase.
resource "cloudflare_ruleset" "origin_header" {
  zone_id     = data.cloudflare_zone.main.zone_id
  name        = "Zone request header rules"
  description = "Managed by Terraform (fargate-website)"
  kind        = "zone"
  phase       = "http_request_late_transform"

  rules = [{
    description = "fargate-website: prove to the load balancer that the request came through Cloudflare"
    expression  = "(http.host eq \"${var.hostname}\")"
    action      = "rewrite"
    enabled     = true
    action_parameters = {
      headers = {
        (var.origin_header) = {
          operation = "set"
          value     = random_password.origin_secret.result
        }
      }
    }
  }]
}

# Proxied, so visitors reach Cloudflare, never the load balancer directly.
resource "cloudflare_dns_record" "web" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = var.hostname
  type    = "CNAME"
  content = aws_lb.web.dns_name
  ttl     = 1
  proxied = true
  comment = "fargate-website load balancer, managed by Terraform"

  # The name must never be live without the block rule and the secret header.
  depends_on = [cloudflare_ruleset.waf_custom, cloudflare_ruleset.origin_header]
}
