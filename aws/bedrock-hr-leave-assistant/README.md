# HR leave assistant: CI/CD for an Amazon Bedrock app in Jakarta

Companion code for a YouTube tutorial series by Herley Shaori. One small office app,
the HR leave assistant of the fictional **Example Corp**, grows a little in every
episode. This folder currently holds the app itself, ready to run on a laptop.

Video: link not published yet.

## The problem

We want an app that answers employee questions about leave with a model on
Amazon Bedrock, running in the Jakarta Region (`ap-southeast-3`), and we want every
change to reach AWS through an automated, safe pipeline. Several things get in the way:

1. **CodePipeline in Jakarta cannot read GitHub directly.** AWS CodeConnections
   (formerly CodeStar Connections) is not available in `ap-southeast-3`, so the usual
   "GitHub source → CodeBuild → deploy" pipeline does not work there.
2. **The code lives in a public repository.** Long-lived AWS access keys stored as
   CI secrets can leak, and anyone can open a pull request from a fork.
3. **Manual setup does not repeat well.** Clicking through GitHub environments,
   secrets, IAM roles, and Lambda settings is hard to reproduce, review, and clean up.
4. **A public endpoint costs money when abused.** Every question sent to Bedrock is
   billed, and a demo URL can be called by anyone who finds it.

## What this tutorial achieves

- **GitHub Actions as the CI/CD engine.** Pull requests run lint and unit tests with
  no AWS access; pushes to `master` deploy. No CodeBuild or CodePipeline is needed.
- **No access keys.** GitHub Actions signs in to AWS with OpenID Connect (OIDC) and
  receives short-lived credentials for one job. The IAM role trusts only this
  repository's `aws` environment, which only `master` can deploy to, so forks cannot
  assume it.
- **Everything as code with Terraform.** One configuration creates both sides: the
  GitHub environment, its secret and variables, the AWS OIDC provider, the IAM roles,
  the Lambda function, and its Function URL. One `terraform destroy` removes them all,
  while the code stays in this repository.
- **A simple app served by Lambda.** The Lambda function serves the web pages and
  calls Amazon Nova Lite on demand in Jakarta through the Bedrock Converse API.
- **Cost under control.** Small reserved concurrency, input limits, and destroying
  the stack right after recording.

## Episodes

| Episode | Added to the app |
| --- | --- |
| 1. CI/CD basics | Leave policy Q&A with the policy in the system prompt |
| 2. Guardrails as code | Block questions about other employees' salary or personal data |
| 3. Evaluation gate | Reference Q&A dataset; the pipeline fails if answer quality drops |
| 4. Bedrock Agents | "Check my balance" and "request leave" actions backed by DynamoDB |
| 5. Knowledge Base | Move the policy from the prompt to documents in Amazon S3 (RAG) |

Each episode gets a Git tag (for example `hr-leave-assistant-ep1`) so the code
matches the video.

## The app

Sign in with a demo account, then use the menu:

| Menu | What it does |
| --- | --- |
| Home | Annual leave balance and pending requests at a glance |
| Ask HR | Ask a question about the leave policy |
| My leave | Submit a leave request and see its history |
| Leave policy | The policy that the assistant answers from |
| Approvals | HR only: approve or reject pending requests |

Demo accounts (fictional people, demo passwords only):

| Username | Password | Role |
| --- | --- | --- |
| `rina` | `rina-demo` | employee |
| `andi` | `andi-demo` | employee |
| `sari` | `sari-demo` | hr |

Authentication is deliberately simple: the accounts live in `app/store.py`, and the
session is an HMAC-signed, `HttpOnly`, `SameSite=Strict` cookie that expires after
8 hours. Leave data is kept in memory and resets on restart. This is a teaching demo,
not a production identity or HR system.

## Run it on your laptop

Requirements: Python 3.11 or later. No packages to install and no AWS account needed.

```sh
cd aws/bedrock-hr-leave-assistant
python3 run_local.py
```

Open http://127.0.0.1:8765 and sign in with one of the demo accounts. Stop the server
with `Ctrl+C`.

By default the assistant runs in **local mode**: it answers with the most relevant
section of `app/policy.md` and never calls AWS, so it is free. To try the real model,
install `boto3`, sign in to an AWS account with Bedrock access to Amazon Nova Lite in
`ap-southeast-3`, and start the server with `ASSISTANT_MODE=bedrock`. Each question is
then billed by Bedrock.

Run the sanity tests (they never call AWS):

```sh
python3 -m unittest discover -s tests -v
```

## Structure

```text
bedrock-hr-leave-assistant/
├── app/                 # deployed as the Lambda package; handler: handler.lambda_handler
│   ├── handler.py       # routing, sign-in, sessions (Function URL payload 2.0)
│   ├── views.py         # HTML pages
│   ├── store.py         # demo accounts and in-memory leave data
│   ├── assistant.py     # local answers or Amazon Bedrock Converse API
│   ├── prompt.md        # system prompt
│   └── policy.md        # fictional leave policy
├── run_local.py         # runs the handler on http://127.0.0.1:8765
└── tests/               # sanity tests, no AWS calls
```

Coming in episode 1: `terraform/` (GitHub and AWS resources) and the GitHub Actions
workflows.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `ASSISTANT_MODE` | `local` | `bedrock` calls Amazon Bedrock |
| `MODEL_ID` | `amazon.nova-lite-v1:0` | Bedrock model or inference profile |
| `AWS_REGION` | `ap-southeast-3` | Region for Bedrock calls |
| `SESSION_SECRET` | random per start | HMAC key for session cookies; set it in Lambda |
| `COOKIE_SECURE` | `1` (`0` in `run_local.py`) | Adds the `Secure` flag to the session cookie |
| `PORT` | `8765` | Local server port |

## Clean up

Locally, stop the server. Nothing is created in any cloud account.
