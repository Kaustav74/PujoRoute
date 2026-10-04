from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.request

class CORSProxy(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.end_headers()

    def do_GET(self):
        req = urllib.request.Request(
            "https://my-freellmapi-server.onrender.com" + self.path,
            headers={
                "Authorization": self.headers.get('Authorization', '')
            }
        )
        try:
            with urllib.request.urlopen(req) as response:
                body = response.read()
                self.send_response(response.getcode())
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Content-Type', response.getheader('Content-Type'))
                self.end_headers()
                self.wfile.write(body)
        except Exception as e:
            self.send_response(500)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(str(e).encode('utf-8'))

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)
        
        req = urllib.request.Request(
            "https://my-freellmapi-server.onrender.com" + self.path,
            data=post_data,
            headers={
                "Content-Type": "application/json",
                "Authorization": self.headers.get('Authorization', '')
            }
        )
        try:
            with urllib.request.urlopen(req) as response:
                body = response.read()
                self.send_response(response.getcode())
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Content-Type', response.getheader('Content-Type'))
                self.end_headers()
                self.wfile.write(body)
        except Exception as e:
            self.send_response(500)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(str(e).encode('utf-8'))

print("Starting full CORS proxy on 8081...")
HTTPServer(('', 8081), CORSProxy).serve_forever()
