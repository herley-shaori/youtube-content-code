# CI/CD for LLM apps on Amazon Bedrock: HR assistant use case

Companion code for a YouTube tutorial by Herley Shaori about **how CI/CD should
work for applications built on a large language model (LLM)**, using Amazon Bedrock
in the Jakarta Region (`ap-southeast-3`). The HR leave assistant of the fictional
**Example Corp** is only a wrapper that makes the use case concrete; any Lambda app
that calls Bedrock fits the same pipeline.

This folder holds the application code in `app/` and the infrastructure code in
`terraform/`.

> **Disclaimer:** Example Corp is a fictional company, and all names in this tutorial
> (employees, accounts, and the company) are fictional. Any resemblance to real
> companies or people is coincidental.

Video: link not published yet.

## The problem

Classic CI/CD assumes that passing tests means the software works. An LLM app breaks
that assumption:

1. **Answers vary.** The same question can get different wording on every run, so
   exact-match tests break.
2. **More than code changes behavior.** Editing the prompt, switching the model
   version, or changing guardrails or knowledge data changes the answers as much as
   a code change does.
3. **Quality needs its own tests.** Passing unit tests does not tell you whether the
   answers are correct, safe, and on topic.
4. **Testing costs money.** Every model call made by a pipeline is billed.

So how should a change to an LLM app reach production safely?

## How LLM CI/CD should run

1. **Change:** code, prompt, and model ID are versioned together in Git.
2. **Fast tests:** every change runs unit tests with Bedrock mocked, so they are
   quick and free.
3. **Package:** code, prompt, and model configuration ship as one artifact.
4. **Deploy to staging.**
5. **Evaluate on staging:** a smoke test, an evaluation set, and safety tests call
   the real model.
6. **Quality gate:** promote only when the score holds and, for production, after
   an approval.
7. **Promote to production.**
8. **Monitor real usage** and turn what you find into new test cases.

This tutorial builds steps 1 to 5, with a smoke test as the evaluation on staging.
Steps 6 to 8 are not covered. The code shown in the video will be tagged
`bedrock-hr-assistant-1`.

## Building it on AWS in Jakarta

Implementation choices, and why:

- **GitHub Actions as the CI/CD engine.** AWS CodeConnections (formerly CodeStar
  Connections) is not available in `ap-southeast-3`, so CodePipeline there cannot use
  GitHub as a source. A deployment starts only when a tag such as
  `bedrock-hr-assistant-stg-v1.0` is pushed, and the tagged commit must be on `master`.
- **No access keys.** The code is in a public repository, so long-lived keys are a
  risk. GitHub Actions signs in to AWS with OpenID Connect (OIDC) and receives
  short-lived credentials for one job. The IAM role trusts only this repository's
  `ai-stg` environment, which only deployment tags can use, so forks cannot assume it.
- **Everything as code with Terraform.** One configuration creates all sides: the
  GitHub environment, its secret and variables, the AWS OIDC provider, the IAM roles,
  the Lambda function, its Function URL, and the Cloudflare rules and DNS record.
  Nothing is changed by hand in AWS or Cloudflare. One `terraform destroy` removes
  them all, while the code stays in this repository.
- **Cloudflare is the only way in.** The public hostname is a proxied Cloudflare
  record served by a small Cloudflare Worker. Direct calls to the Function URL get
  `403` because they lack a secret header that only the Worker adds. A WAF rule blocks
  all traffic until `public_access = true`, and a rate limit protects the model. See [terraform/README.md](terraform/README.md).
- **A simple app served by Lambda.** The Lambda function serves the web pages and
  calls Amazon Nova Lite on demand in Jakarta through the Bedrock Converse API.
- **Cost under control.** Small reserved concurrency, input limits, and destroying
  the stack right after recording.

## The app

Sign in with a demo account, then use the menu:

| Menu | What it does |
| --- | --- |
| Home | Annual leave balance and pending requests at a glance |
| Ask HR | Ask a question about the leave policy |
| My leave | Submit a leave request and see its history |
| Leave policy | The policy that the assistant answers from |
| Approvals | HR only: approve or reject pending requests |

Demo accounts (all names are fictional; demo passwords only):

| Username | Password | Role |
| --- | --- | --- |
| `andi` | `v6xi22xw` | employee |
| `budi` | `6xb9p1gp` | employee |
| `catur` | `fd6woo16` | hr |

Authentication is deliberately simple: the accounts live in `app/src/store.py`, and the
session is an HMAC-signed, `HttpOnly`, `SameSite=Strict` cookie that expires after
8 hours. Leave data is kept in memory and resets on restart. This is a teaching demo,
not a production identity or HR system.

## Run it on your laptop

Requirements: Python 3.11 or later. No packages to install and no AWS account needed.

```sh
cd aws/bedrock-cicd/bedrock-hr-assistant/app
python3 run_local.py
```

Open http://127.0.0.1:8765 and sign in with one of the demo accounts. Stop the server
with `Ctrl+C`.

By default the assistant runs in **local mode**: it answers with the most relevant
section of `app/src/policy.md` and never calls AWS, so it is free. To try the real model,
install `boto3`, sign in to an AWS account with Bedrock access to Amazon Nova Lite in
`ap-southeast-3`, and start the server with `ASSISTANT_MODE=bedrock`. Each question is
then billed by Bedrock.

Run the sanity tests from the same `app/` folder (they never call AWS):

```sh
python3 -m unittest discover -s tests -v
```

## Deploy to staging

After applying [the Terraform configuration](terraform/README.md), tag a commit on
`master` and push the tag:

```sh
git tag bedrock-hr-assistant-stg-v1.0
git push origin bedrock-hr-assistant-stg-v1.0
```

The workflow in `.github/workflows/bedrock-hr-assistant-deploy.yml` then checks that the
commit is on `master`, runs the sanity tests in parallel, builds the package, deploys
it, and runs a smoke test that calls the real model once. Pushing to `master` alone
deploys nothing.

## Structure

```text
aws/bedrock-cicd/                  # topic: CI/CD for Amazon Bedrock apps
└── bedrock-hr-assistant/          # this use case
    ├── README.md
    ├── app/                       # application code
    │   ├── src/                   # Lambda package; handler: handler.lambda_handler
    │   │   ├── handler.py         # routing, sign-in, sessions (Function URL payload 2.0)
    │   │   ├── views.py           # HTML pages
    │   │   ├── store.py           # demo accounts and in-memory leave data
    │   │   ├── assistant.py       # local answers or Amazon Bedrock Converse API
    │   │   ├── prompt.md          # system prompt
    │   │   └── policy.md          # fictional leave policy
    │   ├── tests/                 # sanity tests (no AWS calls) and smoke.py (deployed app)
    │   └── run_local.py           # runs src/ on http://127.0.0.1:8765
    └── terraform/                 # infrastructure code (AWS, Cloudflare, GitHub)
```

Only `app/src/` is deployed to Lambda. Tests and the local runner stay out of the
package. The GitHub Actions workflows live in `.github/workflows/` at the repository
root, because GitHub only reads them from there.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `ASSISTANT_MODE` | `local` | `bedrock` calls Amazon Bedrock |
| `MODEL_ID` | `amazon.nova-lite-v1:0` | Bedrock model or inference profile |
| `AWS_REGION` | `ap-southeast-3` | Region for Bedrock calls |
| `SESSION_SECRET` | random per start | HMAC key for session cookies; set it in Lambda |
| `COOKIE_SECURE` | `1` (`0` in `app/run_local.py`) | Adds the `Secure` flag to the session cookie |
| `ORIGIN_SECRET` | empty | Value Cloudflare sends in `x-origin-verify`; set by Terraform. On Lambda an empty value rejects every request |
| `PORT` | `8765` | Local server port |

## Clean up

Locally, stop the server. Running locally creates nothing in any cloud account. If
you applied the Terraform configuration, run `terraform destroy` in `terraform/`.
