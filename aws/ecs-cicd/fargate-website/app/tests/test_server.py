"""Sanity tests: start the real server on a free port and call it over HTTP."""

import os
import sys
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path

# The website needs its greeting, and the tests provide one.
os.environ.setdefault("GREETING", "Hello World")

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))
import server  # noqa: E402


class ServerTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.httpd = ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
        cls.base = f"http://127.0.0.1:{cls.httpd.server_port}"
        threading.Thread(target=cls.httpd.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()

    def get(self, path):
        try:
            with urllib.request.urlopen(self.base + path, timeout=5) as response:
                return response.status, response.read().decode(), response.headers
        except urllib.error.HTTPError as error:
            with error:
                return error.code, error.read().decode(), error.headers


class HomePageTest(ServerTestCase):
    def test_shows_hello_world_and_the_version(self):
        status, body, headers = self.get("/")
        self.assertEqual(status, 200)
        self.assertIn("Hello World", body)
        self.assertIn(f"Version {server.VERSION}", body)
        self.assertEqual(headers["Cache-Control"], "no-store")


class HealthCheckTest(ServerTestCase):
    def test_health_answers_200(self):
        status, body, _ = self.get("/health")
        self.assertEqual((status, body), (200, "ok"))


class UnknownPathTest(ServerTestCase):
    def test_unknown_path_answers_404(self):
        status, _, _ = self.get("/admin")
        self.assertEqual(status, 404)


if __name__ == "__main__":
    unittest.main()
