# The identity GitHub Actions uses in AWS, and the GitHub environment the workflow
# runs in. The GitHub token comes from the GITHUB_TOKEN environment variable and
# needs admin access to the repository.

# --- AWS: OpenID Connect instead of access keys -----------------------------------

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
  name                 = "${local.name}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600
  permissions_boundary = var.permissions_boundary_arn
}

# The pipeline may push to this one repository and update this one service.
data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "PushImage"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [aws_ecr_repository.web.arn]
  }
  # These two actions do not support resource-level permissions.
  statement {
    sid       = "TaskDefinition"
    actions   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }
  statement {
    sid       = "TagTaskDefinition"
    actions   = ["ecs:TagResource"]
    resources = ["arn:aws:ecs:${var.aws_region}:${var.account_id}:task-definition/${local.name}:*"]
  }
  # A new revision names the execution role, so the pipeline must be allowed to pass it.
  statement {
    sid       = "PassExecutionRole"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.task_execution.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
  statement {
    sid       = "UpdateService"
    actions   = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = [aws_ecs_service.web.arn]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}

# --- GitHub: the environment of the push and deploy jobs --------------------------

locals {
  github_owner = split("/", var.github_repository)[0]
  github_repo  = split("/", var.github_repository)[1]
}

provider "github" {
  owner = local.github_owner
}

# The workflow also checks that the tagged commit is on master, because a tag rule
# can only match the name of the tag.
resource "github_repository_environment" "deploy" {
  repository  = local.github_repo
  environment = var.github_environment

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "tag" {
  repository  = local.github_repo
  environment = github_repository_environment.deploy.environment
  tag_pattern = var.github_deploy_tag_pattern
}

locals {
  # Secrets, because both contain the account ID and the workflow logs of a public
  # repository are public.
  github_secrets = {
    AWS_ROLE_ARN       = aws_iam_role.github_deploy.arn
    ECR_REPOSITORY_URL = aws_ecr_repository.web.repository_url
  }
  github_variables = {
    AWS_REGION     = var.aws_region
    ECS_CLUSTER    = aws_ecs_cluster.main.name
    ECS_SERVICE    = aws_ecs_service.web.name
    TASK_FAMILY    = aws_ecs_task_definition.web.family
    CONTAINER_NAME = local.container_name
  }
}

resource "github_actions_environment_secret" "deploy" {
  for_each    = toset(keys(local.github_secrets))
  repository  = local.github_repo
  environment = github_repository_environment.deploy.environment
  secret_name = each.key
  value       = local.github_secrets[each.key]
}

resource "github_actions_environment_variable" "deploy" {
  for_each      = local.github_variables
  repository    = local.github_repo
  environment   = github_repository_environment.deploy.environment
  variable_name = each.key
  value         = each.value
}
