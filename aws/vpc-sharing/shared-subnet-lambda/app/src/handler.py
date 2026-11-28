"""Answers with where this function runs: its private IP address and the subnet that holds it.

The function calls no AWS API and needs no internet access. Terraform gives it the shared
subnets as environment variables, and it works out the rest from its own network interface.
"""
import ipaddress
import json
import os
import socket


def private_ip():
    """The address of the network interface that Lambda placed in the shared subnet."""
    # Connecting a UDP socket sends nothing. It only asks the system which local address
    # it would use to reach the VPC, and that is the address we want.
    target = str(ipaddress.ip_network(os.environ["VPC_CIDR"])[2])
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.connect((target, 53))
        return probe.getsockname()[0]


def subnet_of(address, subnets):
    """The (subnet ID, CIDR) pair whose range holds the address, or (None, None)."""
    for subnet_id, cidr in subnets.items():
        if ipaddress.ip_address(address) in ipaddress.ip_network(cidr):
            return subnet_id, cidr
    return None, None


def masked(account_id):
    """Only the last four digits, so the answer can be shown on screen."""
    return "********" + account_id[-4:]


def lambda_handler(event, context):
    address = private_ip()
    subnet_id, subnet_cidr = subnet_of(address, json.loads(os.environ["SHARED_SUBNETS"]))
    vpc_owner = os.environ["VPC_OWNER"]
    function_owner = context.invoked_function_arn.split(":")[4]
    return {
        "private_ip": address,
        "subnet_id": subnet_id,
        "subnet_cidr": subnet_cidr,
        "vpc_id": os.environ["VPC_ID"],
        "vpc_owner": masked(vpc_owner),
        "function_owner": masked(function_owner),
        "runs_in_a_shared_subnet": subnet_id is not None and vpc_owner != function_owner,
    }
