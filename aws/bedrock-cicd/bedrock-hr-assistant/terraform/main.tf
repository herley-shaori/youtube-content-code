# AWS side of part 1: the identity GitHub Actions uses to deploy, and the Lambda app
# it deploys to. Run from a laptop with a profile that can assume the deploy role.

provider "aws" {
  profile             = var.aws_profile
  region              = var.aws_region
  allowed_account_ids = [var.account_id]

  dynamic "assume_role" {
    for_each = var.assume_role_name == null ? [] : [var.assume_role_name]
    content {
      role_arn     = "arn:aws:iam::${var.account_id}:role/${assume_role.value}"
      session_name = "terraform-bedrock-hr-assistant"
    }
  }

  default_tags {
    tags = {
      "app-name"  = "bedrock-hr-assistant"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  function_name = "bedrock-hr-assistant-${var.environment}"
  model_arn     = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.model_id}"
}

# --- GitHub Actions: OpenID Connect instead of access keys -----------------------

# An account has only one provider per URL. Set create_github_oidc_provider = false
# when the account already has one.
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_github_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# Only jobs that run in this repository's GitHub environment can assume the role.
# Pull requests and forks never run in that environment.
data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name                 = "${local.function_name}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600
}

# The pipeline may only replace the code of this one function.
data "aws_iam_policy_document" "github_deploy" {
  statement {
    actions   = ["lambda:UpdateFunctionCode", "lambda:GetFunction", "lambda:GetFunctionConfiguration"]
    resources = [aws_lambda_function.app.arn]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}

# --- Lambda app -------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.function_name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

# Write its own logs and call one model, nothing else.
data "aws_iam_policy_document" "lambda" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.app.arn}:*"]
  }
  statement {
    actions   = ["bedrock:InvokeModel"]
    resources = [local.model_arn]
  }
}

resource "aws_iam_role_policy" "lambda" {
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 7
}

resource "random_password" "session_secret" {
  length  = 48
  special = false
}

# Shared with Cloudflare, which adds it to every request it forwards to the app.
resource "random_password" "origin_secret" {
  length  = 48
  special = false
}

# Terraform uploads the first version of the code. After that the pipeline owns it.
data "archive_file" "app" {
  type        = "zip"
  source_dir  = "${path.module}/../app/src"
  excludes    = ["__pycache__"]
  output_path = "${path.module}/build/app.zip"
}

resource "aws_lambda_function" "app" {
  function_name                  = local.function_name
  role                           = aws_iam_role.lambda.arn
  runtime                        = "python3.13"
  architectures                  = ["arm64"]
  handler                        = "handler.lambda_handler"
  filename                       = data.archive_file.app.output_path
  source_code_hash               = data.archive_file.app.output_base64sha256
  memory_size                    = 256
  timeout                        = 30
  reserved_concurrent_executions = var.reserved_concurrency

  environment {
    variables = {
      ASSISTANT_MODE = "bedrock"
      MODEL_ID       = var.model_id
      SESSION_SECRET = random_password.session_secret.result
      ORIGIN_SECRET  = random_password.origin_secret.result
    }
  }

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }

  depends_on = [aws_cloudwatch_log_group.app, aws_iam_role_policy.lambda]
}

# The URL has no AWS auth because Cloudflare cannot sign requests. The app itself
# rejects every request without the origin secret header with 403.
resource "aws_lambda_function_url" "app" {
  function_name      = aws_lambda_function.app.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "url" {
  statement_id           = "FunctionUrlPublic"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.app.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "url_invoke" {
  statement_id             = "FunctionUrlInvoke"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.app.function_name
  principal                = "*"
  invoked_via_function_url = true
}
