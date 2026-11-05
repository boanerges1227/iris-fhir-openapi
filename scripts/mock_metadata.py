"""Synthetic FHIR metadata service for dev-only use; contains no patient data."""
import json
import argparse
import ssl
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CAPABILITY = {"resourceType": "CapabilityStatement", "status": "active", "kind": "instance", "fhirVersion": "4.0.1", "format": ["json"], "implementation": {"url": "http://example.invalid/fhir"}, "rest": [{"mode": "server", "resource": [{"type": "Patient", "interaction": [{"code": "read"}, {"code": "search-type"}], "searchParam": [{"name": "birthdate", "type": "date"}]}]}]}


class Handler(BaseHTTPRequestHandler):
    # Return boundary responses by URL so the adapter can test actual HTTP receive behavior.
    def do_GET(self):
        if self.path.startswith('/redirect/'):
            self.send_response(302)
            self.send_header('Location', '/fhir/metadata')
            self.end_headers()
            return
        if self.path.startswith('/private/') and self.headers.get('Authorization') != 'Bearer synthetic-token':
            self.send_response(401)
            self.end_headers()
            return
        if self.path.startswith('/slow/'):
            self.send_response(200)
            self.send_header('Content-Length', '100')
            self.end_headers()
            try:
                for _ in range(100):
                    self.wfile.write(b' ')
                    self.wfile.flush()
                    time.sleep(.05)
            except (BrokenPipeError, ConnectionResetError):
                pass
            return
        body = b'x'  * (10485760 + 1024) if self.path.startswith('/large/') else json.dumps(CAPABILITY).encode()
        if self.path.startswith('/invalid/'):
            body = b'not-json'
        self.send_response(200)
        self.send_header('Content-Type', 'application/fhir+json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    # Do not print authentication request headers.
    def log_message(self, *_):
        pass


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--tls', action='store_true')
    args = parser.parse_args()
    server = ThreadingHTTPServer(('0.0.0.0', 8443 if args.tls else 8091), Handler)
    if args.tls:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain('/workspace/.local/tls-cert.pem', '/workspace/.local/tls-key.pem')
        server.socket = context.wrap_socket(server.socket, server_side=True)
    server.serve_forever()