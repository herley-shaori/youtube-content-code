# Cloudflare side: the only public entrance to the app. For now it blocks every
# request; opening it is a later step (see README.md).

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "main" {
  filter = { name = var.cloudflare_zone_name }
}

# A zone has one custom-rules ruleset, so this resource owns all WAF custom rules of
# the zone. Add rules for other hostnames here instead of in a second ruleset.
resource "cloudflare_ruleset" "waf_custom" {
  zone_id     = data.cloudflare_zone.main.zone_id
  name        = "Zone custom rules"
  description = "Managed by Terraform (bedrock-hr-assistant)"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules = [{
    description = "bedrock-hr-assistant: block all traffic until the app is opened"
    expression  = "(http.host eq \"${var.hostname}\")"
    action      = "block"
    enabled     = true
  }]
}

# Proxied, so visitors reach Cloudflare, never the Function URL directly.
resource "cloudflare_dns_record" "app" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = var.hostname
  type    = "CNAME"
  content = trimsuffix(trimprefix(aws_lambda_function_url.app.function_url, "https://"), "/")
  ttl     = 1
  proxied = true
  comment = "bedrock-hr-assistant Lambda Function URL, managed by Terraform"

  # The name must never be live without the block rule in front of it.
  depends_on = [cloudflare_ruleset.waf_custom]
}
