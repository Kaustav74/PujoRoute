"""Local development-only CORS proxy for running the Flutter web build.

Forwards requests to the FreeLLMAPI server so the browser does not hit CORS.
Hardened so it is safe to leave running on a dev machine:
  * binds to 127.0.0.1 only (not reachable from the LAN)
  * only allows localhost origins
  * only forwards a small allow-list of API paths
  * caps request size and never echoes internal exception details

Usage:  python cors_proxy.py   (env: CORS_PROXY_PORT, UPSTREAM_BASE_URL)
"""
import os
import re
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

UPSTREAM = os.environ.get("UPSTREAM_BASE_URL", "https://my-freellmapi-server.onrender.com").rstrip("/")
PORT = int(os.environ.get("CORS_PROXY_PORT", "8081"))
MAX_BODY = 64 * 1024
ALLOWED_PATHS = {"/v1/chat/completions", "/v1/models", "/health"}
LOCAL_ORIGIN = re.compile(r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$")


class CORSProxy(BaseHTTPRequestHandler):
    def _cors(self):
        origin = self.headers.get("Origin", "")
        if LOCAL_ORIGIN.match(origin):
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")

    def _reject(self, code, msg):
        self.send_response(code)
        self._cors()
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(msg.encode("utf-8"))

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.end_headers()

    def _forward(self, data=None):
        path = self.path.split("?", 1)[0]
        if path not in ALLOWED_PATHS:
            return self._reject(404, "Not found")
        headers = {"Authorization": self.headers.get("Authorization", "")}
        if data is not None:
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(UPSTREAM + path, data=data, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=60) as response:
                body = response.read()
                self.send_response(response.getcode())
                self._cors()
                self.send_header("Content-Type", response.getheader("Content-Type") or "application/json")
                self.end_headers()
                self.wfile.write(body)
        except urllib.error.HTTPError as e:
            self._reject(e.code, "Upstream error")
        except Exception:
            self._reject(502, "Upstream unavailable")

    def do_GET(self):
        self._forward()

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
        except ValueError:
            return self._reject(400, "Bad request")
        if length < 0 or length > MAX_BODY:
            return self._reject(413, "Payload too large")
        self._forward(self.rfile.read(length))


if __name__ == "__main__":
    print(f"Starting local CORS proxy on http://127.0.0.1:{PORT} -> {UPSTREAM}")
    HTTPServer(("127.0.0.1", PORT), CORSProxy).serve_forever()
