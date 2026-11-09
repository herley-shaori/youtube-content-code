# Cloudflare side: the only public entrance to the app. It blocks every request
# until var.public_access is true.

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
    enabled     = !var.public_access
  }]
}

locals {
  function_url_host = trimsuffix(trimprefix(aws_lambda_function_url.app.function_url, "https://"), "/")
}

# A Function URL only answers to its own host name, and the Free plan cannot change
# the Host header with a rule, so a small Worker forwards the requests.
resource "cloudflare_workers_script" "proxy" {
  account_id         = data.cloudflare_zone.main.account.id
  script_name        = "bedrock-hr-assistant-proxy"
  content            = file("${path.module}/worker.js")
  main_module        = "worker.js"
  compatibility_date = "2026-01-01"

  bindings = [
    { name = "FUNCTION_URL_HOST", type = "plain_text", text = local.function_url_host },
    { name = "ORIGIN_HEADER", type = "plain_text", text = var.origin_header },
    { name = "ORIGIN_SECRET", type = "secret_text", text = random_password.origin_secret.result },
  ]
}

resource "cloudflare_workers_route" "proxy" {
  zone_id = data.cloudflare_zone.main.zone_id
  pattern = "${var.hostname}/*"
  script  = cloudflare_workers_script.proxy.script_name
}

# Every question is a billed model call, so this is the path to protect. Like the
# custom rules above, a zone has one ruleset for this phase.
# ponytail: per-IP limit only, a distributed attack is capped by reserved concurrency.
resource "cloudflare_ruleset" "rate_limit" {
  zone_id     = data.cloudflare_zone.main.zone_id
  name        = "Zone rate limiting rules"
  description = "Managed by Terraform (bedrock-hr-assistant)"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [{
    description = "bedrock-hr-assistant: limit questions to the model"
    expression  = "(http.host eq \"${var.hostname}\" and http.request.uri.path eq \"/ask\")"
    action      = "block"
    enabled     = true
    ratelimit = {
      characteristics     = ["cf.colo.id", "ip.src"]
      period              = 10
      requests_per_period = var.ask_requests_per_10s
      mitigation_timeout  = 10
    }
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
