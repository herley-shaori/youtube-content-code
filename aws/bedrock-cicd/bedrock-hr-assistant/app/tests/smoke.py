"""Smoke test of a deployed app. Calls the real model once, so each run is billed.

It checks that the model answered, not what it said: wording varies between runs.
Run with FUNCTION_URL and ORIGIN_SECRET set: python3 tests/smoke.py
"""
import http.client
import os
import sys
from pathlib import Path
from urllib.parse import urlencode, urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import store  # noqa: E402

HOST = urlsplit(os.environ["FUNCTION_URL"]).hostname
SECRET = os.environ["ORIGIN_SECRET"]
USER = "andi"


def request(method, path, form=None, headers=None):
    # http.client does not follow redirects, so the sign-in cookie stays readable.
    connection = http.client.HTTPSConnection(HOST, timeout=60)
    body = urlencode(form) if form else None
    all_headers = {"Content-Type": "application/x-www-form-urlencoded", **(headers or {})}
    connection.request(method, path, body, all_headers)
    response = connection.getresponse()
    response.read()
    return response


def expect(step, actual, wanted):
    if actual != wanted:
        sys.exit(f"FAILED: {step}: expected {wanted}, got {actual}")
    print(f"ok: {step}")


origin = {"x-origin-verify": SECRET}
expect("direct call without the secret is rejected", request("GET", "/login").status, 403)

signed_in = request("POST", "/login", {"username": USER, "password": store.USERS[USER]["password"]}, origin)
expect("sign in", signed_in.status, 303)
cookie = signed_in.getheader("Set-Cookie", "").split(";")[0]
if not cookie.startswith("session="):
    sys.exit("FAILED: sign in did not return a session cookie")

question = {"question": "How many days of annual leave do I get?"}
expect("the model answers", request("POST", "/ask", question, {**origin, "Cookie": cookie}).status, 200)
