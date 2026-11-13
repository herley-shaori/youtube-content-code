# Terraform: bedrock-hr-assistant

Infrastructure for this use case, in the Jakarta Region (`ap-southeast-3`). Everything in AWS
and Cloudflare is created here, never by hand, so one `terraform destroy` removes it
all.

## What it creates

| Side | Resources |
| --- | --- |
| AWS | IAM OIDC provider for GitHub Actions (optional), deploy role for GitHub Actions, Lambda role, log group (7 days), Lambda function built from `../app/src`, Function URL |
| Cloudflare | Proxied DNS record, Worker that forwards requests to the Function URL, WAF custom rule that blocks the hostname until `public_access = true`, rate limit on `/ask` |
| GitHub | Environment `ai-stg` that only tags matching `bedrock-hr-assistant-stg-v*` can use, secrets `AWS_ROLE_ARN`, `FUNCTION_URL`, `ORIGIN_SECRET`, variables `AWS_REGION`, `FUNCTION_NAME` |

## How the app is protected

Visitors may only reach the app through Cloudflare:

1. **Cloudflare is the only front door.** The DNS record is proxied, so the Function
   URL host is never exposed through DNS. With `public_access = false` (the default) a
   WAF custom rule blocks every request for the hostname.
2. **The Function URL rejects direct calls.** Cloudflare cannot sign AWS requests, so
   the URL uses `authorization_type = "NONE"`. Instead, the app requires the header
   `x-origin-verify` with a random secret that only Terraform, Lambda, and the
   Cloudflare Worker know. Any request without it gets `403 Forbidden` before any app code
   runs. If the secret is missing on Lambda, the app rejects everything.
3. **Small blast radius.** Reserved concurrency (default 2) caps parallel runs and the
   Bedrock bill. The Lambda role can only write its own logs and call one model. The
   deploy role can only replace the code of this one function, and only jobs in the
   repository's GitHub environment can assume it.

A Function URL only answers to its own host name, and the Cloudflare Free plan cannot
change the `Host` header with a rule, so `worker.js` forwards each request with the
right host and the secret header. The Workers free tier allows 100,000 requests per day.

With `public_access = true`, anyone can sign in with the demo accounts and ask the
model, which is billed. A rate limit allows 3 questions per 10 seconds for each client,
but a distributed attack can still reach the model, capped only by reserved
concurrency. Open the app only while you need it.

## Run it

Requirements: Terraform 1.10 or later, an AWS profile that can reach the target
account, and a Cloudflare API token with **Zone Read**, **DNS Edit**, **Zone WAF Edit**, and
**Workers Routes Edit** on the zone, plus **Workers Scripts Edit** on the account. A GitHub token with admin access to the repository.

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
