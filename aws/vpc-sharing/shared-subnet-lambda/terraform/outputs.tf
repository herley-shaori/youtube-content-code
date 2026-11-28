output "function_name" {
  value = aws_lambda_function.where_am_i.function_name
}

output "shared_vpc_id" {
  value = data.aws_vpc.shared.id
}

output "function_answer" {
  description = "What the function said about who owns what. Account IDs show only their last four digits."
  value       = jsondecode(aws_lambda_invocation.proof.result)
}

output "function_network_interfaces" {
  description = "Where the function sits in the network: one interface per shared subnet. The subnet and the interface have different owners."
  value = {
    for subnet_id, interface in data.aws_network_interface.function : subnet_id => {
      private_ip      = interface.private_ip
      subnet_cidr     = data.aws_subnet.shared[subnet_id].cidr_block
      subnet_owner    = "********${substr(data.aws_subnet.shared[subnet_id].owner_id, 8, 4)}"
      interface_owner = "********${substr(interface.owner_id, 8, 4)}"
    }
  }
}
