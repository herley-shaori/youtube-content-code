"""Hello World website for the ECS update lab: / shows the version, /health is for the load balancer."""

import os
import signal
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# Set at image build time from the Git tag, for example v1.0.
VERSION = os.environ.get("APP_VERSION", "dev")

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Hello World</title>
<style>
  body {{ margin: 0; min-height: 100vh; display: grid; place-items: center;
         font-family: system-ui, sans-serif; background: #e6f4ea; color: #202124; }}
  main {{ text-align: center; }}
  h1 {{ font-size: 4rem; margin: 0 0 1rem; }}
  p {{ font-size: 2rem; margin: 0; color: #188038; font-weight: 600; }}
  small {{ display: block; margin-top: 1.5rem; font-size: 1.25rem; color: #5f6368; }}
</style>
</head>
<body>
<main>
  <h1>Hello World</h1>
  <p>Version {version}</p>
  <small>Updated from Amazon ECR by the pipeline</small>
</main>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/":
            self._send(200, PAGE.format(version=VERSION), "text/html; charset=utf-8")
        elif self.path == "/health":
            self._send(200, "ok", "text/plain")
        else:
            self._send(404, "not found", "text/plain")

    def _send(self, status, body, content_type):
        data = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        # Visitors must always see the version that is running now.
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        # Health checks arrive every few seconds and would fill the log.
        if self.path != "/health":
            super().log_message(fmt, *args)


def main():
    # Python runs as PID 1 in the container, where SIGTERM is ignored unless handled.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), Handler).serve_forever()


if __name__ == "__main__":
    main()
