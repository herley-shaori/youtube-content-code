"""Answers with who owns the function and who owns the network it runs in.

The function calls no AWS API and needs no internet access. Terraform gives it the shared
VPC and subnets as environment variables.

It does not report its own IP address. Inside Lambda, the function only sees an internal
address (169.254.x.x). The address in the shared subnet belongs to a network interface
that Lambda manages outside the function, so Terraform reads it from EC2 instead
(output function_network_interfaces).
"""
import json
import os


def masked(account_id):
    """Only the last four digits, so the answer can be shown on screen."""
    return "********" + account_id[-4:]


def lambda_handler(event, context):
    subnets = json.loads(os.environ["SHARED_SUBNETS"])
    vpc_owner = os.environ["VPC_OWNER"]
    function_owner = context.invoked_function_arn.split(":")[4]
    return {
        "vpc_id": os.environ["VPC_ID"],
        "vpc_owner": masked(vpc_owner),
        "function_owner": masked(function_owner),
        "subnets": subnets,
        "runs_in_a_shared_subnet": bool(subnets) and vpc_owner != function_owner,
    }
