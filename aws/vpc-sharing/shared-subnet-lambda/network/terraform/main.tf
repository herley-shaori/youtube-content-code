# Owner side of the lab, applied in the network account: one VPC, three private subnets,
# and an AWS RAM resource share that lends those subnets to other accounts.
#
# The VPC stays here. Only the subnets are shared, and the accounts that receive them can
# place their own resources inside but cannot change the network.

provider "aws" {
  profile             = var.aws_profile
  region              = var.aws_region
  allowed_account_ids = [var.account_id]

  dynamic "assume_role" {
    for_each = var.assume_role_name == null ? [] : [var.assume_role_name]
    content {
      role_arn     = "arn:aws:iam::${var.account_id}:role/${assume_role.value}"
      session_name = "terraform-shared-subnet-network"
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

# Availability zone names (ap-southeast-3a) can point to different zones in different
# accounts. Zone IDs (apse3-az1) mean the same zone everywhere, so the lab uses IDs.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name     = "shared-subnet-lambda-${var.environment}"
  zone_ids = slice(sort(data.aws_availability_zones.available.zone_ids), 0, 3)

  # The /20 is cut into /24 subnets. Numbers 8, 9 and 10 are the private ones:
  # 10.53.8.0/24, 10.53.9.0/24 and 10.53.10.0/24 with the default range.
  # With nobody to share with, the VPC is built alone and no resource share exists.
  shared = length(var.share_with) > 0

  private_subnets = {
    for index, zone_id in local.zone_ids : zone_id => cidrsubnet(var.vpc_cidr, 4, 8 + index)
  }
}

resource "aws_vpc" "shared" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = local.name }
}

# No internet gateway and no NAT gateway: the only route is the local one that AWS adds
# to every route table. The lab costs nothing while it runs.
resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id               = aws_vpc.shared.id
  cidr_block           = each.value
  availability_zone_id = each.key

  tags = { Name = "${local.name}-private-${each.key}" }
}

# The security group that AWS creates with the VPC allows nothing. Accounts that receive
# the subnets cannot use it anyway; they create their own.
resource "aws_default_security_group" "locked" {
  vpc_id = aws_vpc.shared.id

  tags = { Name = "${local.name}-default-locked" }
}

# --- AWS RAM: what is shared, and with whom ----------------------------------------------

# Sharing inside an organization must be turned on once, from the management account:
#   aws ram enable-sharing-with-aws-organization
# After that, accounts in the organization receive the subnets without an invitation.
resource "aws_ram_resource_share" "subnets" {
  count = local.shared ? 1 : 0

  name                      = local.name
  allow_external_principals = false

  tags = { Name = local.name }
}

# What is shared: each subnet. A VPC cannot be shared as a whole.
resource "aws_ram_resource_association" "subnet" {
  for_each = local.shared ? aws_subnet.private : {}

  resource_share_arn = aws_ram_resource_share.subnets[0].arn
  resource_arn       = each.value.arn
}

# With whom: an account, an organizational unit, or the whole organization. With an
# organizational unit, an account that joins it later receives the subnets as well.
resource "aws_ram_principal_association" "receiver" {
  for_each = toset(var.share_with)

  resource_share_arn = aws_ram_resource_share.subnets[0].arn
  principal          = each.value
}
