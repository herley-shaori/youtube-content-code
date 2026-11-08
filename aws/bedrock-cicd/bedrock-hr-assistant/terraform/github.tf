# GitHub side: the environment the deploy workflow runs in. The token comes from the
# GITHUB_TOKEN environment variable and needs admin access to the repository.

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
  github_secrets = {
    AWS_ROLE_ARN  = aws_iam_role.github_deploy.arn
    FUNCTION_URL  = aws_lambda_function_url.app.function_url
    ORIGIN_SECRET = random_password.origin_secret.result
  }
  github_variables = {
    AWS_REGION    = var.aws_region
    FUNCTION_NAME = aws_lambda_function.app.function_name
  }
}

# Secrets, because the workflow logs of a public repository are public.
resource "github_actions_environment_secret" "deploy" {
  for_each        = nonsensitive(toset(keys(local.github_secrets)))
  repository      = local.github_repo
  environment     = github_repository_environment.deploy.environment
  secret_name     = each.key
  plaintext_value = local.github_secrets[each.key]
}

resource "github_actions_environment_variable" "deploy" {
  for_each      = local.github_variables
  repository    = local.github_repo
  environment   = github_repository_environment.deploy.environment
  variable_name = each.key
  value         = each.value
}
