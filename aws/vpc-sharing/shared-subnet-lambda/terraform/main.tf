# App side of the lab, applied in the app account: a Lambda function that runs inside
# subnets owned by another account.
#
# Apply the network side first (../network/terraform). This side creates no VPC and no
# subnet. It only looks up what the network account shared, then places its own security
# group and function there.

provider "aws" {
  profile             = var.aws_profile
  region              = var.aws_region
  allowed_account_ids = [var.account_id]

  dynamic "assume_role" {
    for_each = var.assume_role_name == null ? [] : [var.assume_role_name]
    content {
      role_arn     = "arn:aws:iam::${var.account_id}:role/${assume_role.value}"
      session_name = "terraform-shared-subnet-lambda"
    }
  }

  default_tags {
    tags = {
      "app-name"  = "shared-subnet-lambda"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  name = "shared-subnet-lambda-${var.environment}"
}

# --- Finding what was shared ---------------------------------------------------------------

# The tags that the network account put on the VPC and subnets are not shared, so they
# cannot be used to search here. The address range can.
data "aws_vpc" "shared" {
  filter {
    name   = "cidr-block"
    values = [var.shared_vpc_cidr]
  }

  lifecycle {
    postcondition {
      condition     = self.owner_id != var.account_id
      error_message = "The VPC with this range belongs to this account. This lab expects a VPC shared by another account."
    }
  }
}

# This account sees only the subnets that were shared with it.
data "aws_subnets" "shared" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.shared.id]
  }

  lifecycle {
    postcondition {
      condition     = length(self.ids) > 0
      error_message = "No subnet of the shared VPC is visible. Check the resource share in the network account."
    }
  }
}

data "aws_subnet" "shared" {
  for_each = toset(data.aws_subnets.shared.ids)
  id       = each.value
}

# --- What this account owns inside the shared subnets ---------------------------------------

# The security group lives in the VPC of the network account but belongs to this account.
# No rule in, no rule out: the function calls nothing and nothing calls it over the network.
resource "aws_security_group" "function" {
  name        = local.name
  description = "Function of the shared-subnet-lambda lab. No traffic in or out"
  vpc_id      = data.aws_vpc.shared.id

  tags = { Name = local.name }
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "function" {
  name                 = local.name
  assume_role_policy   = data.aws_iam_policy_document.assume.json
  permissions_boundary = var.permissions_boundary_arn
}

# Lets Lambda create its network interfaces in the subnets and write logs.
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.function.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_cloudwatch_log_group" "function" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 7
}

data "archive_file" "function" {
  type        = "zip"
  source_dir  = "${path.module}/../app/src"
  output_path = "${path.module}/.build/function.zip"
}

resource "aws_lambda_function" "where_am_i" {
  function_name    = local.name
  description      = "Answers with who owns the function and who owns the network it runs in"
  role             = aws_iam_role.function.arn
  runtime          = "python3.13"
  architectures    = ["arm64"]
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.function.output_path
  source_code_hash = data.archive_file.function.output_base64sha256
  timeout          = 5
  memory_size      = 128

  # The one setting this lab is about: the subnets belong to another account.
  vpc_config {
    subnet_ids         = data.aws_subnets.shared.ids
    security_group_ids = [aws_security_group.function.id]
  }

  environment {
    variables = {
      VPC_ID         = data.aws_vpc.shared.id
      VPC_OWNER      = data.aws_vpc.shared.owner_id
      SHARED_SUBNETS = jsonencode({ for id, subnet in data.aws_subnet.shared : id => subnet.cidr_block })
    }
  }

  depends_on = [aws_iam_role_policy_attachment.vpc_access, aws_cloudwatch_log_group.function]
}

# Calls the function once after every change, so the answer shows up in the apply output.
resource "aws_lambda_invocation" "proof" {
  function_name = aws_lambda_function.where_am_i.function_name
  input         = jsonencode({})

  triggers = {
    code    = aws_lambda_function.where_am_i.source_code_hash
    subnets = join(",", sort(data.aws_subnets.shared.ids))
  }
}

# --- The proof -------------------------------------------------------------------------------

# Lambda keeps one network interface per subnet for this function. The function cannot
# see them from the inside, so Terraform reads them from EC2 once the function has run.
data "aws_network_interface" "function" {
  for_each = toset(data.aws_subnets.shared.ids)

  filter {
    name   = "subnet-id"
    values = [each.value]
  }
  filter {
    name   = "group-id"
    values = [aws_security_group.function.id]
  }

  depends_on = [aws_lambda_invocation.proof]
}
