# Sanity tests with a mocked provider. They plan only and never call AWS. Run: terraform test

mock_provider "aws" {
  override_data {
    target = data.aws_vpc.shared
    values = { id = "vpc-1", owner_id = "111111111111", cidr_block = "10.53.0.0/20" }
  }
  override_data {
    target = data.aws_subnets.shared
    values = { ids = ["subnet-a", "subnet-b"] }
  }
  override_data {
    target = data.aws_iam_policy_document.assume
    values = { json = "{}" }
  }
}
mock_provider "archive" {}
variables {
  account_id  = "123456789012"
  aws_profile = "x"
}
run "function_in_shared_subnets" {
  command = plan
  assert {
    condition     = toset(aws_lambda_function.where_am_i.vpc_config[0].subnet_ids) == toset(["subnet-a", "subnet-b"])
    error_message = "function not in shared subnets"
  }
}
run "refuses_own_vpc" {
  command = plan
  variables { account_id = "111111111111" }
  expect_failures = [data.aws_vpc.shared]
}
