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


def invoke(function_account, subnets=SUBNETS):
    environment = {"VPC_ID": "vpc-123", "VPC_OWNER": "111111111111", "SHARED_SUBNETS": json.dumps(subnets)}
    context = SimpleNamespace(invoked_function_arn=f"arn:aws:lambda:ap-southeast-3:{function_account}:function:demo")
    with mock.patch.dict(os.environ, environment):
        return handler.lambda_handler({}, context)


class HandlerTest(unittest.TestCase):
    def test_reports_the_shared_subnets_it_was_placed_in(self):
        answer = invoke("000000000000")
        self.assertEqual(answer["subnets"], SUBNETS)
        self.assertTrue(answer["runs_in_a_shared_subnet"])

    def test_shows_only_the_last_four_digits_of_each_account(self):
        answer = invoke("000000000000")
        self.assertEqual(answer["vpc_owner"], "********1111")
        self.assertEqual(answer["function_owner"], "********0000")

    def test_is_not_shared_when_the_function_owns_the_vpc(self):
        self.assertFalse(invoke("111111111111")["runs_in_a_shared_subnet"])

    def test_is_not_shared_without_subnets(self):
        self.assertFalse(invoke("000000000000", subnets={})["runs_in_a_shared_subnet"])


if __name__ == "__main__":
    unittest.main()
