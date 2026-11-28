"""Sanity tests for the handler. They never call AWS. Run: python3 -m unittest discover tests"""
import json
import os
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import handler  # noqa: E402

SUBNETS = {"subnet-aaa": "10.53.8.0/24", "subnet-bbb": "10.53.9.0/24"}
ENVIRONMENT = {
    "VPC_ID": "vpc-123",
    "VPC_CIDR": "10.53.0.0/20",
    "VPC_OWNER": "111111111111",
    "SHARED_SUBNETS": json.dumps(SUBNETS),
}


def invoke(address, function_account):
    context = SimpleNamespace(invoked_function_arn=f"arn:aws:lambda:ap-southeast-3:{function_account}:function:demo")
    with mock.patch.dict(os.environ, ENVIRONMENT), mock.patch.object(handler, "private_ip", return_value=address):
        return handler.lambda_handler({}, context)


class HandlerTest(unittest.TestCase):
    def test_reports_the_shared_subnet_that_holds_its_address(self):
        answer = invoke("10.53.9.25", "000000000000")
        self.assertEqual(answer["subnet_id"], "subnet-bbb")
        self.assertEqual(answer["subnet_cidr"], "10.53.9.0/24")
        self.assertTrue(answer["runs_in_a_shared_subnet"])

    def test_shows_only_the_last_four_digits_of_each_account(self):
        answer = invoke("10.53.8.7", "000000000000")
        self.assertEqual(answer["vpc_owner"], "********1111")
        self.assertEqual(answer["function_owner"], "********0000")

    def test_is_not_shared_when_the_function_owns_the_vpc(self):
        self.assertFalse(invoke("10.53.8.7", "111111111111")["runs_in_a_shared_subnet"])

    def test_is_not_shared_when_the_address_is_outside_the_subnets(self):
        answer = invoke("172.31.5.10", "000000000000")
        self.assertIsNone(answer["subnet_id"])
        self.assertFalse(answer["runs_in_a_shared_subnet"])

    def test_private_ip_asks_the_system_without_sending_anything(self):
        with mock.patch.dict(os.environ, ENVIRONMENT):
            self.assertRegex(handler.private_ip(), r"^\d+\.\d+\.\d+\.\d+$")


if __name__ == "__main__":
    unittest.main()
