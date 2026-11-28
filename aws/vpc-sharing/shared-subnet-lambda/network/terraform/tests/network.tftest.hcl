# Sanity tests with a mocked provider. They plan only and never call AWS. Run: terraform test

mock_provider "aws" {
  override_data {
    target = data.aws_availability_zones.available
    values = { zone_ids = ["apse3-az3", "apse3-az1", "apse3-az2"] }
  }
}
variables {
  account_id  = "123456789012"
  aws_profile = "x"
  share_with  = ["111111111111"]
}
run "layout" {
  command = plan
  assert {
    condition     = { for k, s in aws_subnet.private : k => s.cidr_block } == { "apse3-az1" = "10.53.8.0/24", "apse3-az2" = "10.53.9.0/24", "apse3-az3" = "10.53.10.0/24" }
    error_message = "unexpected subnets"
  }
  assert {
    condition     = length(aws_ram_resource_association.subnet) == 3 && length(aws_ram_principal_association.receiver) == 1
    error_message = "unexpected share"
  }
}
run "not_shared_yet" {
  command = plan
  variables { share_with = [] }
  assert {
    condition     = length(aws_subnet.private) == 3 && length(aws_ram_resource_share.subnets) == 0 && length(aws_ram_resource_association.subnet) == 0
    error_message = "an empty share_with must build the VPC without a resource share"
  }
}
run "rejects_other_sizes" {
  command = plan
  variables { vpc_cidr = "10.53.0.0/16" }
  expect_failures = [var.vpc_cidr]
}
