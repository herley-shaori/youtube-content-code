output "vpc_id" {
  value = aws_vpc.shared.id
}

output "vpc_cidr" {
  description = "The app side finds the shared VPC by this range."
  value       = aws_vpc.shared.cidr_block
}

output "shared_subnets" {
  description = "Subnet ID and address range per availability zone ID."
  value       = { for zone_id, subnet in aws_subnet.private : zone_id => { id = subnet.id, cidr = subnet.cidr_block } }
}

output "route_table_id" {
  description = "The route table of the shared subnets. Only this account can change it."
  value       = aws_vpc.shared.main_route_table_id
}

output "resource_share_arn" {
  value = aws_ram_resource_share.subnets.arn
}
