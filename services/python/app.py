import json
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer


class Hue(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({"lang": "python", "color": "#FFD43B", "host": socket.gethostname()})
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body.encode())

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print("python hue listening on :8080", flush=True)
    HTTPServer(("0.0.0.0", 8080), Hue).serve_forever()
