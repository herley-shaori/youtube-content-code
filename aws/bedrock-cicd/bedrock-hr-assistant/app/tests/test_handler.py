"""Sanity tests for the handler. They never call AWS. Run: python3 -m unittest discover tests"""
import os
import sys
import unittest
from datetime import date, timedelta
from pathlib import Path
from urllib.parse import urlencode

os.environ["ASSISTANT_MODE"] = "local"
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import handler  # noqa: E402
import store  # noqa: E402


def call(method, path, form=None, cookie=None):
    return handler.lambda_handler({
        "rawPath": path,
        "requestContext": {"http": {"method": method}},
        "cookies": [cookie] if cookie else [],
        "body": urlencode(form or {}),
    }, None)


def sign_in(username):
    response = call("POST", "/login", {"username": username, "password": store.USERS[username]["password"]})
    return response["cookies"][0].split(";")[0]


def next_monday():
    day = date.today() + timedelta(days=14)
    return day + timedelta(days=-day.weekday())


class AuthenticationTest(unittest.TestCase):
    def test_pages_need_sign_in(self):
        self.assertEqual(call("GET", "/home")["headers"]["Location"], "/login")

    def test_wrong_password_is_rejected(self):
        response = call("POST", "/login", {"username": "andi", "password": "wrong"})
        self.assertEqual(response["statusCode"], 401)
        self.assertEqual(response["cookies"], [])

    def test_sign_in_shows_home(self):
        response = call("GET", "/home", cookie=sign_in("andi"))
        self.assertIn("Andi Pratama", response["body"])

    def test_tampered_session_is_rejected(self):
        name, _, value = sign_in("andi").partition("=")
        forged = f"{name}=catur{value[len('andi'):]}"
        self.assertEqual(call("GET", "/home", cookie=forged)["statusCode"], 303)

    def test_employee_cannot_open_approvals(self):
        self.assertEqual(call("GET", "/approvals", cookie=sign_in("andi"))["statusCode"], 403)


class AssistantTest(unittest.TestCase):
    def test_answers_from_policy_without_aws(self):
        response = call("POST", "/ask", {"question": "How many days off for my wedding?"}, sign_in("andi"))
        self.assertIn("Marriage leave", response["body"])

    def test_answers_work_from_home(self):
        response = call("POST", "/ask", {"question": "Can I work from home?"}, sign_in("andi"))
        self.assertIn("Work from home", response["body"])

    def test_rejects_too_long_question(self):
        response = call("POST", "/ask", {"question": "x" * 501}, sign_in("andi"))
        self.assertEqual(response["statusCode"], 400)

    def test_user_input_is_escaped(self):
        response = call("POST", "/ask", {"question": "<script>alert(1)</script>"}, sign_in("andi"))
        self.assertNotIn("<script>alert", response["body"])


class LeaveRequestTest(unittest.TestCase):
    def test_request_reduces_annual_balance(self):
        before = store.annual_balance("budi")
        start = next_monday()
        form = {"type": "Annual", "start": start.isoformat(), "end": (start + timedelta(days=1)).isoformat()}
        self.assertEqual(call("POST", "/leave", form, sign_in("budi"))["statusCode"], 303)
        self.assertEqual(store.annual_balance("budi"), before - 2)

    def test_request_over_balance_is_rejected(self):
        start = next_monday()
        form = {"type": "Annual", "start": start.isoformat(), "end": (start + timedelta(days=30)).isoformat()}
        response = call("POST", "/leave", form, sign_in("andi"))
        self.assertEqual(response["statusCode"], 400)
        self.assertIn("annual leave days left", response["body"])

    def test_hr_can_approve(self):
        request_id = store.pending_requests()[0]["id"]
        call("POST", "/approvals", {"id": request_id, "action": "approve"}, sign_in("catur"))
        self.assertEqual(next(r for r in store.REQUESTS if r["id"] == request_id)["status"], "Approved")


class OriginTest(unittest.TestCase):
    def tearDown(self):
        handler.ORIGIN_SECRET, handler.ON_LAMBDA = "", False

    def test_direct_call_without_cloudflare_header_is_rejected(self):
        handler.ORIGIN_SECRET = "s3cret"
        self.assertEqual(call("GET", "/login")["statusCode"], 403)
        event = {"rawPath": "/login", "headers": {"x-origin-verify": "wrong"}}
        self.assertEqual(handler.lambda_handler(event, None)["statusCode"], 403)

    def test_call_with_cloudflare_header_is_served(self):
        handler.ORIGIN_SECRET = "s3cret"
        event = {"rawPath": "/login", "headers": {"x-origin-verify": "s3cret"}}
        self.assertEqual(handler.lambda_handler(event, None)["statusCode"], 200)

    def test_lambda_without_origin_secret_rejects_everything(self):
        handler.ON_LAMBDA = True
        self.assertEqual(call("GET", "/login")["statusCode"], 403)


if __name__ == "__main__":
    unittest.main()
