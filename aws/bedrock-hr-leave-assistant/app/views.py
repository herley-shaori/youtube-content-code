"""HTML pages. Every value that comes from a user goes through e() before it reaches the page."""
from html import escape as e

CSS = """
*{box-sizing:border-box}body{margin:0;font:15px/1.6 system-ui,sans-serif;color:#1f2933;background:#f4f6f8}
header{display:flex;flex-wrap:wrap;align-items:center;gap:16px;padding:12px 24px;background:#1f3a5f;color:#fff}
header strong{margin-right:auto}nav{display:flex;flex-wrap:wrap;align-items:center;gap:4px}
nav a{color:#dbe7f5;text-decoration:none;padding:6px 10px;border-radius:6px}nav a.active,nav a:hover{background:#2f5285;color:#fff}
.who{margin:0 8px;font-size:13px;color:#b8cbe3}main{max-width:880px;margin:24px auto;padding:0 16px}
.card{background:#fff;border:1px solid #dde3ea;border-radius:10px;padding:20px;margin-bottom:16px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px}.stat{font-size:32px;font-weight:600}
label{display:block;margin:12px 0 4px;font-weight:500}input,select,textarea{width:100%;padding:8px;border:1px solid #c5ced8;border-radius:6px;font:inherit}
button{margin-top:14px;padding:8px 16px;border:0;border-radius:6px;background:#1f3a5f;color:#fff;font:inherit;cursor:pointer}
button.link{margin:0;padding:6px 10px;background:none;color:#dbe7f5}button.reject{background:#b42318}
table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:8px;border-bottom:1px solid #e5e9ee;vertical-align:top}
.badge{padding:2px 8px;border-radius:10px;font-size:12px;background:#e5e9ee}.Approved{background:#d1fadf;color:#05603a}
.Pending{background:#fef0c7;color:#93370d}.Rejected{background:#fee4e2;color:#912018}
.error{padding:10px;border-radius:6px;background:#fee4e2;color:#912018}.note{font-size:13px;color:#52606d}
.answer{white-space:pre-wrap;background:#eef4fb;border-radius:6px;padding:12px}
footer{max-width:880px;margin:0 auto 24px;padding:0 16px;font-size:12px;color:#52606d}
"""

FOOTER = "Example Corp is a fictional company, and all names in this app are fictional. Any resemblance to real companies or people is coincidental."

NAV = [("/home", "Home"), ("/ask", "Ask HR"), ("/leave", "My leave"), ("/policy", "Leave policy")]


def layout(title, body, me=None, active=""):
    nav = ""
    if me:
        items = NAV + ([("/approvals", "Approvals")] if me["role"] == "hr" else [])
        links = "".join(f'<a href="{href}"{" class=active" if href == active else ""}>{label}</a>' for href, label in items)
        nav = (f'<nav>{links}<span class="who">{e(me["name"])} ({e(me["role"])})</span>'
               '<form method="post" action="/logout"><button class="link">Sign out</button></form></nav>')
    return (f'<!doctype html><html lang="en"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<title>{e(title)} | Example Corp HR</title><style>{CSS}</style></head>'
            f'<body><header><strong>Example Corp HR</strong>{nav}</header><main><h1>{e(title)}</h1>{body}</main><footer>{FOOTER}</footer></body></html>')


def _error(message):
    return f'<p class="error">{e(message)}</p>' if message else ""


def _status(status):
    return f'<span class="badge {e(status)}">{e(status)}</span>'


def login_page(users, error=None, username=""):
    rows = "".join(f"<tr><td>{e(k)}</td><td>{e(u['password'])}</td><td>{e(u['role'])}</td></tr>" for k, u in users.items())
    body = f"""<div class="card">{_error(error)}
<form method="post" action="/login">
<label for="username">Username</label><input id="username" name="username" value="{e(username)}" required autofocus>
<label for="password">Password</label><input id="password" name="password" type="password" required>
<button>Sign in</button></form></div>
<div class="card"><p class="note">Demo accounts for this tutorial. Example Corp and all names are fictional.</p>
<table><tr><th>Username</th><th>Password</th><th>Role</th></tr>{rows}</table></div>"""
    return layout("Sign in", body)


def home_page(me, balance, my_pending, approvals_waiting):
    hr_card = (f'<div class="card"><div>Requests waiting for you</div><div class="stat">{approvals_waiting}</div>'
               f'<a href="/approvals">Review requests</a></div>') if me["role"] == "hr" else ""
    body = f"""<p>Welcome back, {e(me['name'])}.</p><div class="grid">
<div class="card"><div>Annual leave left</div><div class="stat">{balance}</div><a href="/leave">Request leave</a></div>
<div class="card"><div>Your pending requests</div><div class="stat">{my_pending}</div><a href="/leave">View history</a></div>
{hr_card}</div>
<div class="card"><strong>Have a question about leave?</strong> <a href="/ask">Ask the HR assistant</a>
or read the <a href="/policy">leave policy</a>.</div>"""
    return layout("Home", body, me, "/home")


def ask_page(me, mode, question="", answer=None, error=None):
    source = "Amazon Bedrock" if mode == "bedrock" else "local demo mode, Amazon Bedrock is not called"
    result = (f'<h2>Answer</h2><p class="answer">{e(answer)}</p><p class="note">Source: {source}.</p>') if answer else ""
    body = f"""<div class="card">{_error(error)}
<form method="post" action="/ask"><label for="question">Your question about leave</label>
<textarea id="question" name="question" rows="3" maxlength="500" required
placeholder="How many days of annual leave do I get?">{e(question)}</textarea>
<button>Ask</button></form>{result}</div>"""
    return layout("Ask HR", body, me, "/ask")


def _requests_table(requests, show_user=None, actions=False):
    if not requests:
        return '<p class="note">No requests yet.</p>'
    head = ("<th>Employee</th>" if show_user else "") + "<th>Type</th><th>Dates</th><th>Days</th><th>Reason</th><th>Status</th>"
    rows = ""
    for r in requests:
        who = f"<td>{e(show_user[r['user']]['name'])}</td>" if show_user else ""
        status = _status(r["status"])
        if actions:
            status = (f'<form method="post" action="/approvals"><input type="hidden" name="id" value="{r["id"]}">'
                      '<button name="action" value="approve">Approve</button> '
                      '<button class="reject" name="action" value="reject">Reject</button></form>')
        rows += (f"<tr>{who}<td>{e(r['type'])}</td><td>{r['start']:%d %b %Y} to {r['end']:%d %b %Y}</td>"
                 f"<td>{r['days']}</td><td>{e(r['reason'])}</td><td>{status}</td></tr>")
    return f"<table><tr>{head}</tr>{rows}</table>"


def leave_page(me, balance, requests, leave_types, error=None, form=None):
    form = form or {}
    options = "".join(f'<option{" selected" if t == form.get("type") else ""}>{e(t)}</option>' for t in leave_types)
    body = f"""<div class="card"><div>Annual leave left this year</div><div class="stat">{balance} days</div>
<p class="note">Only annual leave reduces this balance. Weekends are not counted.</p></div>
<div class="card"><h2>New request</h2>{_error(error)}
<form method="post" action="/leave">
<label for="type">Leave type</label><select id="type" name="type">{options}</select>
<div class="grid"><div><label for="start">First day</label><input id="start" name="start" type="date" value="{e(form.get('start', ''))}" required></div>
<div><label for="end">Last day</label><input id="end" name="end" type="date" value="{e(form.get('end', ''))}" required></div></div>
<label for="reason">Reason (optional)</label><input id="reason" name="reason" maxlength="200" value="{e(form.get('reason', ''))}">
<button>Submit request</button></form></div>
<div class="card"><h2>History</h2>{_requests_table(requests)}</div>
<p class="note">Demo data is kept in memory and resets when the app restarts.</p>"""
    return layout("My leave", body, me, "/leave")


def policy_page(me, policy_markdown):
    parts = []
    for block in policy_markdown.strip().split("\n\n"):
        if block.startswith("## "):
            parts.append(f"<h2>{e(block[3:])}</h2>")
        elif not block.startswith("# "):
            parts.append(f"<p>{e(block)}</p>")
    return layout("Leave policy", f'<div class="card">{"".join(parts)}</div>', me, "/policy")


def approvals_page(me, pending, users):
    body = f'<div class="card"><h2>Waiting for approval</h2>{_requests_table(pending, show_user=users, actions=True)}</div>'
    return layout("Approvals", body, me, "/approvals")


def message_page(me, title, text):
    return layout(title, f'<div class="card"><p>{e(text)}</p><a href="/home">Back to home</a></div>', me)
