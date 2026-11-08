output "function_name" {
  value = aws_lambda_function.app.function_name
}

output "github_deploy_role_arn" {
  description = "Goes into the GitHub environment secret AWS_ROLE_ARN."
  value       = aws_iam_role.github_deploy.arn
}

output "app_url" {
  value = "https://${var.hostname}"
}
