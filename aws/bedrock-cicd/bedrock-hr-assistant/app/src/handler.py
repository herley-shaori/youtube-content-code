"""AWS Lambda entry point (Function URL payload 2.0). run_local.py feeds it the same events on a laptop."""
import base64
import hashlib
import hmac
import os
import secrets
import time
from datetime import date
from urllib.parse import parse_qs

import assistant
import store
import views

# Set SESSION_SECRET in Lambda so sessions survive cold starts; locally a random one is fine.
SECRET = (os.environ.get("SESSION_SECRET") or secrets.token_hex(32)).encode()
SESSION_SECONDS = 8 * 3600
COOKIE_SECURE = os.environ.get("COOKIE_SECURE", "1") != "0"
MAX_BODY_BYTES = 10_000
# Cloudflare adds this header to every request it forwards, so a direct call to the
# Function URL gets 403. On Lambda a missing secret rejects everything (fail closed).
ORIGIN_HEADER = "x-origin-verify"
ORIGIN_SECRET = os.environ.get("ORIGIN_SECRET", "")
ON_LAMBDA = "AWS_LAMBDA_FUNCTION_NAME" in os.environ
SECURITY_HEADERS = {
    "Content-Type": "text/html; charset=utf-8",
    "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Cache-Control": "no-store",
}


def html(body, status=200, cookies=None):
    return {"statusCode": status, "headers": SECURITY_HEADERS, "cookies": cookies or [], "body": body}


def redirect(location, cookies=None):
    return {"statusCode": 303, "headers": {**SECURITY_HEADERS, "Location": location}, "cookies": cookies or [], "body": ""}


def _sign(value):
    return hmac.new(SECRET, value.encode(), hashlib.sha256).hexdigest()


def _cookie(value, max_age):
    return f"session={value}; Path=/; HttpOnly; SameSite=Strict; Max-Age={max_age}" + ("; Secure" if COOKIE_SECURE else "")


def session_cookie(username):
    value = f"{username}.{int(time.time()) + SESSION_SECONDS}"
    return _cookie(f"{value}.{_sign(value)}", SESSION_SECONDS)


def current_user(event):
    for cookie in event.get("cookies") or []:
        name, _, value = cookie.strip().partition("=")
        if name != "session":
            continue
        username, _, rest = value.partition(".")
        expires, _, signature = rest.partition(".")
        if (hmac.compare_digest(_sign(f"{username}.{expires}"), signature)
                and expires.isdigit() and int(expires) > time.time() and username in store.USERS):
            return username
    return None


def _form(event):
    body = event.get("body") or ""
    if event.get("isBase64Encoded"):
        body = base64.b64decode(body).decode("utf-8", "replace")
    if len(body) > MAX_BODY_BYTES:
        return {}
    return {k: v[0].strip() for k, v in parse_qs(body).items()}


def login(form):
    username = form.get("username", "").lower()
    if store.check_password(username, form.get("password", "")):
        return redirect("/home", [session_cookie(username)])
    return html(views.login_page(store.USERS, "Wrong username or password.", username), 401)


def home(user, me, form):
    waiting = len(store.pending_requests())
    mine = sum(1 for r in store.requests_of(user) if r["status"] == "Pending")
    return html(views.home_page(me, store.annual_balance(user), mine, waiting))


def ask_form(user, me, form):
    return html(views.ask_page(me, assistant.mode()))


def ask(user, me, form):
    question = form.get("question", "")
    if not question or len(question) > assistant.MAX_QUESTION_LENGTH:
        error = f"Write a question of 1 to {assistant.MAX_QUESTION_LENGTH} characters."
        return html(views.ask_page(me, assistant.mode(), question[:assistant.MAX_QUESTION_LENGTH], error=error), 400)
    try:
        answer = assistant.answer(question)
    except Exception as exc:  # Show a friendly message; the details go to CloudWatch Logs.
        print(f"assistant error: {exc!r}")
        return html(views.ask_page(me, assistant.mode(), question, error="The assistant is unavailable. Try again later."), 502)
    return html(views.ask_page(me, assistant.mode(), question, answer))


def _leave(user, me, error=None, form=None, status=200):
    page = views.leave_page(me, store.annual_balance(user), store.requests_of(user), store.LEAVE_TYPES, error, form)
    return html(page, status)


def leave_form(user, me, form):
    return _leave(user, me)


def request_leave(user, me, form):
    try:
        start, end = date.fromisoformat(form.get("start", "")), date.fromisoformat(form.get("end", ""))
    except ValueError:
        return _leave(user, me, "Enter valid dates.", form, 400)
    error = store.add_request(user, form.get("type", ""), start, end, form.get("reason", ""))
    if error:
        return _leave(user, me, error, form, 400)
    return redirect("/leave")


def policy(user, me, form):
    return html(views.policy_page(me, assistant.POLICY))


def approvals(user, me, form):
    return html(views.approvals_page(me, store.pending_requests(), store.USERS))


def decide(user, me, form):
    request_id = form.get("id", "")
    if request_id.isdigit():
        store.decide(int(request_id), form.get("action") == "approve")
    return redirect("/approvals")


def logout(user, me, form):
    return redirect("/login", [_cookie("", 0)])


ROUTES = {
    ("GET", "/"): lambda user, me, form: redirect("/home"),
    ("GET", "/home"): home,
    ("GET", "/ask"): ask_form,
    ("POST", "/ask"): ask,
    ("GET", "/leave"): leave_form,
    ("POST", "/leave"): request_leave,
    ("GET", "/policy"): policy,
    ("GET", "/approvals"): approvals,
    ("POST", "/approvals"): decide,
    ("POST", "/logout"): logout,
}
HR_ONLY = {"/approvals"}


def from_cloudflare(event):
    if not ORIGIN_SECRET:
        return not ON_LAMBDA
    sent = (event.get("headers") or {}).get(ORIGIN_HEADER, "")
    return hmac.compare_digest(sent.encode(), ORIGIN_SECRET.encode())


def lambda_handler(event, context):
    if not from_cloudflare(event):
        return {"statusCode": 403, "headers": {**SECURITY_HEADERS, "Content-Type": "text/plain"}, "body": "Forbidden"}
    method =event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path = event.get("rawPath") or "/"
    form = _form(event) if method == "POST" else {}
    user = current_user(event)

    if path == "/login":
        if user:
            return redirect("/home")
        return login(form) if method == "POST" else html(views.login_page(store.USERS))
    if user is None:
        return redirect("/login")

    me = store.USERS[user]
    route = ROUTES.get((method, path))
    if route is None:
        return html(views.message_page(me, "Not found", "This page does not exist."), 404)
    if path in HR_ONLY and me["role"] != "hr":
        return html(views.message_page(me, "Not allowed", "Only HR can open this page."), 403)
    return route(user, me, form)
