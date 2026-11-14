# YouTube Tutorial Companion Code

This repository holds the companion code for **Herley Shaori**'s YouTube tutorials on
AWS, Azure, and Google Cloud: application code, scripts, Terraform configurations,
and other technical examples. After watching a video, open the matching tutorial
folder to study and try the code.

## Tutorials

| Tutorial | Technology | Code and guide | Video |
| --- | --- | --- | --- |
| OAuth 2.0 implicit flow with Cognito and API Gateway | AWS, Terraform, Python | [Open tutorial](aws/oauth2-implicit-cognito-aws-apigw/) | Not published yet |
| CI/CD for LLM apps on Amazon Bedrock (HR assistant use case) | AWS, Amazon Bedrock, Lambda, Python | [Open tutorial](aws/bedrock-cicd/bedrock-hr-assistant/) | [Watch on YouTube](https://youtu.be/vIbt29DjLuE) |

Video links are added once each video is published. Every folder has its own README
that covers prerequisites, configuration, how to run it, and how to clean up any
resources it creates.

## Start here

```sh
git clone https://github.com/herley-shaori/youtube-content-code.git
cd youtube-content-code
```

1. Pick a tutorial from the table above or from the link in the video description.
2. Read the README in that tutorial folder.
3. Prepare the dependencies and configuration it lists.
4. Run commands from inside the tutorial folder, not from the repository root.

Tutorials are independent. You do not need to install the dependencies of the whole
repository or run every example at once.

## Repository structure

```text
.
├── README.md
├── .githooks/                        # credential checks before each commit
├── .github/workflows/                # credential scanning in GitHub Actions
├── templates/
│   └── tutorial/
│       └── README.md                 # README template for new tutorials
├── aws/
│   ├── oauth2-implicit-cognito-aws-apigw/  # older single-folder tutorial
│   └── bedrock-cicd/                 # topic
│       └── bedrock-hr-assistant/     # use case
│           ├── app/                  # application code
│           └── terraform/            # infrastructure code
├── azure/
└── gcp/
```

New tutorials follow `<cloud>/<topic>/<use-case>/`:

- `<cloud>` is `aws/`, `azure/`, or `gcp/`.
- `<topic>` groups the use cases of one subject, for example `bedrock-cicd`.
- `<use-case>` is the app or scenario being built, for example `bedrock-hr-assistant`.

Inside a use case, keep the application code in `app/` and the infrastructure code in
`terraform/`, so it is always clear which code runs where. Add `scripts/` only when
needed. All folder names use `kebab-case`.

## Adding a tutorial

1. Create `<cloud>/<topic>/<use-case>/`, reusing the topic folder if it already exists.
2. Copy the [README template](templates/tutorial/README.md) into it, fill in every
   relevant section, and remove the sections you do not need.
3. Add the code, dependency versions, and configuration examples without credentials.
4. Add the real video URL to the tutorial README and to the table above. If the video
   is not out yet, say that the link is not published yet.
5. Describe the expected result, the limits of the example, and how to clean up the
   resources it creates.
6. Put a direct link to the tutorial folder in the YouTube description so viewers do
   not have to search for the code.

To keep the code matching a specific video, link to the commit or tag that was
current when the video was published. Tags use the format `<use-case>-<N>`, for
example `bedrock-hr-assistant-1`.

## Configuration and resources

- Use your own credentials through the authentication mechanism of the technology.
  Never store tokens, passwords, `.env` files, or Terraform state in Git.
- Keep configuration examples as `.env.example` or `terraform.tfvars.example` with
  placeholder values and an explanation of each variable.
- Replace account IDs, subscription IDs, tenant IDs, project IDs, IP addresses, and
  email addresses with placeholders before committing.
- Cloud examples can create billable resources. Read the configuration and the plan
  output before deploying, and follow the clean-up steps when you are done.
- Every example is learning material. Each tutorial README explains the limits to
  consider before adapting it for other uses.

## Credential checks

This repository is public. Every push and pull request is scanned by
[Gitleaks](https://github.com/gitleaks/gitleaks) in GitHub Actions, and GitHub secret
scanning with push protection is enabled. To check before committing on your own
machine, install Gitleaks and enable this repository's hooks:

```sh
brew install gitleaks
git config core.hooksPath .githooks
```

The `pre-commit` hook rejects `.env` files, Terraform state, `.tfvars` files, private
keys, and cloud credential files, then scans the change with Gitleaks. On top of the
default Gitleaks rules, [`.gitleaks.toml`](.gitleaks.toml) also rejects AWS account
IDs, Azure subscription and tenant IDs, and GCP project IDs. Use variables, data
sources such as `aws_caller_identity`, or placeholders such as `123456789012`. To scan
the whole history manually, run `gitleaks git .` from the repository root.
