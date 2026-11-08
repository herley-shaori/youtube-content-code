# Terraform: bedrock-hr-assistant

Infrastructure for part 1, in the Jakarta Region (`ap-southeast-3`). Everything in AWS
and Cloudflare is created here, never by hand, so one `terraform destroy` removes it
all.

## What it creates

| Side | Resources |
| --- | --- |
| AWS | IAM OIDC provider for GitHub Actions (optional), deploy role for GitHub Actions, Lambda role, log group (7 days), Lambda function built from `../app/src`, Function URL |
| Cloudflare | WAF custom rule that blocks the app hostname, proxied CNAME from the hostname to the Function URL |
| GitHub | Environment `ai-stg` that only tags matching `bedrock-hr-assistant-stg-v*` can use, secrets `AWS_ROLE_ARN`, `FUNCTION_URL`, `ORIGIN_SECRET`, variables `AWS_REGION`, `FUNCTION_NAME` |

## How the app is protected

Visitors may only reach the app through Cloudflare:

1. **Cloudflare blocks everything for now.** The WAF custom rule blocks every request
   for the hostname, and the DNS record is proxied, so the Function URL host is never
   exposed through DNS.
2. **The Function URL rejects direct calls.** Cloudflare cannot sign AWS requests, so
   the URL uses `authorization_type = "NONE"`. Instead, the app requires the header
   `x-origin-verify` with a random secret that only Terraform, Lambda, and (later)
   Cloudflare know. Any request without it gets `403 Forbidden` before any app code
   runs. If the secret is missing on Lambda, the app rejects everything.
3. **Small blast radius.** Reserved concurrency (default 2) caps parallel runs and the
   Bedrock bill. The Lambda role can only write its own logs and call one model. The
   deploy role can only replace the code of this one function, and only jobs in the
   repository's GitHub environment can assume it.

Opening the app later takes two more Cloudflare rules, added here when needed: a
request header transform rule that adds `x-origin-verify`, and an origin rule that
sets the `Host` header to the Function URL host. Then the block rule is removed.

## Run it

Requirements: Terraform 1.10 or later, an AWS profile that can reach the target
account, and a Cloudflare API token with **Zone DNS Edit** and **Zone WAF Edit** on the
zone. A GitHub token with admin access to the repository.

```sh
cp terraform.tfvars.example terraform.tfvars   # fill in your values
export TF_VAR_cloudflare_api_token="..."       # never put it in a file in the repo
export GITHUB_TOKEN="$(gh auth token)"
terraform init
terraform plan
terraform apply
```

Notes:

- Requests rejected by the app still run the function and are billed. Set
  `reserved_concurrency = 0` while the app is not in use, so AWS throttles every call
  before the function runs. Set it back to `2` before you deploy or record, otherwise
  the smoke test fails.
- An AWS account can hold only one GitHub OIDC provider. Set
  `create_github_oidc_provider = false` if yours already has one.
- A Cloudflare zone has only one ruleset for WAF custom rules. If your zone already
  has custom rules, import that ruleset first or add the rule there, otherwise
  `apply` fails.
- Terraform creates the first version of the code. After that the pipeline deploys
  new code, and Terraform ignores code changes.
- `terraform.tfvars`, the state, and `build/` stay on your machine. The state holds
  the session and origin secrets, so never commit or share it.

## Clean up

```sh
terraform destroy
```

This removes the AWS, Cloudflare and GitHub resources. The code stays in this repository and
can be applied again. A GitHub OIDC provider that you did not create here is left as
it is.
