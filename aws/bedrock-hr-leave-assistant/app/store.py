"""In-memory demo data. It resets on every restart; a later episode moves it to DynamoDB."""
import hmac
from datetime import date, timedelta

ANNUAL_DAYS = 12
MAX_RANGE_DAYS = 100
MAX_REASON_LENGTH = 200
LEAVE_TYPES = ["Annual", "Sick", "Maternity", "Paternity", "Marriage", "Bereavement"]

# Demo accounts for a fictional company. Never put real credentials in this repository.
USERS = {
    "andi": {"name": "Andi Pratama", "role": "employee", "password": "v6xi22xw"},
    "budi": {"name": "Budi Santoso", "role": "employee", "password": "6xb9p1gp"},
    "catur": {"name": "Catur Wibowo", "role": "hr", "password": "fd6woo16"},
}

REQUESTS = [
    {"id": 1, "user": "andi", "type": "Annual", "start": date(2026, 3, 16), "end": date(2026, 3, 17),
     "days": 2, "reason": "Family trip", "status": "Approved"},
    {"id": 2, "user": "andi", "type": "Sick", "start": date(2026, 6, 8), "end": date(2026, 6, 8),
     "days": 1, "reason": "Flu", "status": "Approved"},
    {"id": 3, "user": "budi", "type": "Annual", "start": date(2026, 12, 21), "end": date(2026, 12, 23),
     "days": 3, "reason": "Year-end holiday", "status": "Pending"},
]


def check_password(username, password):
    user = USERS.get(username)
    return user is not None and hmac.compare_digest(user["password"].encode(), password.encode())


def working_days(start, end):
    return sum(1 for i in range((end - start).days + 1) if (start + timedelta(days=i)).weekday() < 5)


def annual_balance(username):
    used = sum(r["days"] for r in REQUESTS
               if r["user"] == username and r["type"] == "Annual" and r["status"] in ("Approved", "Pending"))
    return ANNUAL_DAYS - used


def requests_of(username):
    return [r for r in REQUESTS if r["user"] == username]


def pending_requests():
    return [r for r in REQUESTS if r["status"] == "Pending"]


def add_request(username, leave_type, start, end, reason):
    """Stores a valid request. Returns an error message, or None on success."""
    if leave_type not in LEAVE_TYPES:
        return "Choose a valid leave type."
    if start < date.today():
        return "Leave cannot start in the past."
    if end < start:
        return "The end date must be on or after the start date."
    if (end - start).days > MAX_RANGE_DAYS:
        return f"A single request can cover at most {MAX_RANGE_DAYS} days."
    if len(reason) > MAX_REASON_LENGTH:
        return f"The reason can be at most {MAX_REASON_LENGTH} characters."
    days = working_days(start, end)
    if days == 0:
        return "The selected dates contain no working days."
    if leave_type == "Annual" and days > annual_balance(username):
        return f"You only have {annual_balance(username)} annual leave days left."
    REQUESTS.append({"id": max(r["id"] for r in REQUESTS) + 1, "user": username, "type": leave_type,
                     "start": start, "end": end, "days": days, "reason": reason, "status": "Pending"})
    return None


def decide(request_id, approve):
    for r in REQUESTS:
        if r["id"] == request_id and r["status"] == "Pending":
            r["status"] = "Approved" if approve else "Rejected"
            return True
    return False
