import http.server
import socketserver
import random
import string

PORT = 8080

class MyHandler(http.server.BaseHTTPRequestHandler):

    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(bytes("<html><head><script>" + ''.join(random.choices(string.printable, k=random.randint(10,500))) + "</script></head><body></body></html>", "utf-8"))

with socketserver.TCPServer(("", PORT), MyHandler) as httpd:
    print("serving at port", PORT)
    httpd.serve_forever()
