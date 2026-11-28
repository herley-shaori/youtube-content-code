output "function_name" {
  value = aws_lambda_function.where_am_i.function_name
}

output "shared_vpc_id" {
  value = data.aws_vpc.shared.id
}

output "function_answer" {
  description = "What the function said about where it runs. Account IDs show only their last four digits."
  value       = jsondecode(aws_lambda_invocation.proof.result)
}
