"""Runs the Lambda handler on http://127.0.0.1:8765 by turning each request into a Function URL event.

Only the Python standard library is used. Amazon Bedrock is not called unless ASSISTANT_MODE=bedrock.
"""
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

os.environ.setdefault("COOKIE_SECURE", "0")  # Local HTTP has no TLS, so the cookie cannot be Secure.
sys.path.insert(0, str(Path(__file__).parent / "app"))
import handler  # noqa: E402

PORT = int(os.environ.get("PORT", "8765"))


class FunctionUrlAdapter(BaseHTTPRequestHandler):
    def _handle(self):
        path, _, query = self.path.partition("?")
        length = min(int(self.headers.get("Content-Length") or 0), handler.MAX_BODY_BYTES + 1)
        event = {
            "rawPath": path,
            "rawQueryString": query,
            "headers": {k.lower(): v for k, v in self.headers.items()},
            "cookies": [c for c in self.headers.get("Cookie", "").split(";") if c.strip()],
            "body": self.rfile.read(length).decode("utf-8", "replace") if length else "",
            "isBase64Encoded": False,
            "requestContext": {"http": {"method": self.command}},
        }
        response = handler.lambda_handler(event, None)
        self.send_response(response["statusCode"])
        for name, value in response.get("headers", {}).items():
            self.send_header(name, value)
        for cookie in response.get("cookies", []):
            self.send_header("Set-Cookie", cookie)
        self.end_headers()
        self.wfile.write(response.get("body", "").encode())

    do_GET = do_POST = _handle


if __name__ == "__main__":
    print(f"Example Corp HR running on http://127.0.0.1:{PORT} (assistant mode: {handler.assistant.mode()})")
    HTTPServer(("127.0.0.1", PORT), FunctionUrlAdapter).serve_forever()
