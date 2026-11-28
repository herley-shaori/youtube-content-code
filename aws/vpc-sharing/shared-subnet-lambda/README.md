# Sharing VPC subnets across accounts with AWS RAM

One account owns a VPC and lends its subnets to another account of the same AWS
Organization. The other account runs a Lambda function inside those subnets, but it
cannot change the network. The function answers with its private IP address, which
shows that it runs in a network it does not own.

```text
network account                              app account
VPC 10.53.0.0/20
├─ subnet 10.53.8.0/24  ──┐
├─ subnet 10.53.9.0/24  ──┼─ AWS RAM share ─▶  Lambda function + its security group
└─ subnet 10.53.10.0/24 ──┘                    (placed inside the shared subnets)
```

## Video

Not published yet.

## Prerequisites

- Terraform 1.10 or later, Python 3.13, and the AWS CLI.
- Two AWS accounts in one AWS Organization: a **network account** that owns the VPC and
  an **app account** that runs the function. A profile that can reach each of them.
- Sharing inside the organization turned on. Run this once, signed in to the
  **management account**:

  ```bash
  aws ram enable-sharing-with-aws-organization
  ```

## Folder contents

| Path | Runs in | Contents |
| --- | --- | --- |
| `network/terraform/` | Network account | The VPC, three private subnets, and the AWS RAM resource share |
| `terraform/` | App account | The Lambda function, its security group and its role, placed in the shared subnets |
| `app/src/handler.py` | | The function: answers with its private IP address and the subnet that holds it |
| `app/tests/` | | Sanity tests for the function |

## What Terraform creates

| Side | Resources |
| --- | --- |
| Network account | VPC `10.53.0.0/20`, three `/24` private subnets in three availability zones, a locked default security group, one resource share with the subnets and the accounts that receive them |
| App account | Security group without rules, IAM role, log group (7 days), Lambda function attached to the shared subnets |

There is no internet gateway, NAT gateway or load balancer, so the lab has no hourly
cost. The function calls no AWS API and needs no internet access.

## The settings this lab is about

In the network account, a resource share says what is shared and with whom:

```hcl
resource "aws_ram_resource_association" "subnet" {
  for_each           = aws_subnet.private
  resource_share_arn = aws_ram_resource_share.subnets.arn
  resource_arn       = each.value.arn          # a subnet, not the VPC
}

resource "aws_ram_principal_association" "receiver" {
  for_each           = toset(var.share_with)   # an account, or an organizational unit
  resource_share_arn = aws_ram_resource_share.subnets.arn
  principal          = each.value
}
```

In the app account, the function uses subnets it did not create:

```hcl
resource "aws_lambda_function" "where_am_i" {
  vpc_config {
    subnet_ids         = data.aws_subnets.shared.ids          # owned by the network account
    security_group_ids = [aws_security_group.function.id]     # owned by the app account
  }
}
```

## How to run

Apply the network side first, then the app side. Each side has its own state.

```bash
# 1. Network account: the VPC and the share
cd network/terraform
cp terraform.tfvars.example terraform.tfvars   # then fill in your own values
terraform init
terraform plan
terraform apply

# 2. App account: the function
cd ../../terraform
cp terraform.tfvars.example terraform.tfvars   # then fill in your own values
terraform init
terraform plan
terraform apply
```

If the app side says that no VPC matches, the share has not arrived yet. Check
`share_with` in the network side and that sharing is turned on in the organization.

## Expected result

The app side calls the function once and prints its answer:

```text
function_answer = {
  "function_owner"          = "********0000"
  "private_ip"              = "10.53.9.25"
  "runs_in_a_shared_subnet" = true
  "subnet_cidr"             = "10.53.9.0/24"
  "subnet_id"               = "subnet-0123456789abcdef0"
  "vpc_id"                  = "vpc-0123456789abcdef0"
  "vpc_owner"               = "********1111"
}
```

The address is inside `10.53.0.0/20`, and the two owners differ. Call it again with:

```bash
aws lambda invoke --function-name shared-subnet-lambda-stg /dev/stdout
```

Then try to change the network from the **app account**. AWS refuses, because the VPC
belongs to the network account:

```bash
aws ec2 create-subnet --vpc-id "$(terraform output -raw shared_vpc_id)" --cidr-block 10.53.11.0/24
```

## Clean up

Remove the app side first, then the network side. The network account cannot delete a
subnet that still holds a resource of another account.

```bash
cd terraform && terraform destroy
cd ../network/terraform && terraform destroy
```

Removing the function can take a few minutes while Lambda releases its network
interfaces.

## Notes and limitations

- The default subnets of the default VPC cannot be shared.
- Tags of the network account are not shared, so the app side finds the VPC by its
  address range. Availability zones are chosen by zone ID, because a zone name can point
  to a different zone in another account.
- The app account cannot use the default security group of the shared VPC. It creates
  its own.
- When the share is removed, resources that already run in the subnets keep running,
  but the app account can no longer create new ones there.
- If your account only lets you create roles that carry a permissions boundary, set
  `permissions_boundary_arn`. The boundary must allow `ec2:CreateNetworkInterface`,
  `ec2:DescribeNetworkInterfaces` and `ec2:DeleteNetworkInterface`, which Lambda needs
  to attach a function to a subnet.
- Sanity tests: `python3 -m unittest discover tests` in `app/`, and `terraform test` in
  each Terraform folder. None of them calls AWS.
