# Terraform: bedrock-hr-assistant

Infrastructure code for the HR leave assistant. It is added in part 1 of the series
and is not here yet.

One configuration will manage both sides, so one `terraform apply` connects GitHub to
AWS and one `terraform destroy` removes both:

| Side | Resources |
| --- | --- |
| GitHub | Environment `aws` (deployments from `master` only), secret `AWS_ROLE_ARN`, variables for the Region and function name |
| AWS | IAM OIDC provider for GitHub Actions, IAM roles for GitHub Actions and Lambda, Lambda function built from `../app/src`, Function URL |

The Region is Jakarta (`ap-southeast-3`). Account IDs, role ARNs, and state files are
never committed; they stay in your local `terraform.tfvars` and state.
