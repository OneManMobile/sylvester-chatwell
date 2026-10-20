"""Shared one-page secret form for Sylvester Chatwell (stdlib only).

Grok Bot hands a secret to the user with "Take over": the Bot opens a page in
its own browser, the user takes control, types the secret and chooses
"I'm done". This module serves that page on 127.0.0.1 behind a random URL
token, never logs requests, and closes after success, MAX_ATTEMPTS failed
attempts or a timeout. Used by bin/nemlig-login and bin/telegram-connect.

A tool supplies:
  render_form(values: dict, error: str) -> str     inner HTML of the form
  submit(fields: dict) -> one of
      ("done", inner_html)                         success; the page closes
      ("fail", error_text, values)                 counts as a failed attempt
      ("invalid", error_text, values)              400, not counted
"""
import html
import json
import os
import secrets
import socket
import threading
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MAX_ATTEMPTS = 5

STYLE = """
* { box-sizing: border-box; }
body { margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
  background: #f7f3ea; color: #1f4e5a; font: 17px/1.45 -apple-system, "Segoe UI", Roboto, sans-serif; }
main { width: min(440px, 92vw); background: #fffdf8; border: 2px solid #b08d3c; outline: 1px solid #b08d3c;
  outline-offset: 5px; padding: 30px 26px; margin: 24px 0; }
.hat { text-align: center; font-size: 34px; }
h1 { font-family: Georgia, serif; text-align: center; margin: 4px 0 10px; font-size: 26px; }
p { margin: 0 0 18px; color: #4b5a5e; }
a { color: #1f4e5a; font-weight: 700; }
label { display: block; font-weight: 600; margin: 14px 0 6px; }
input[type=email], input[type=password], input[type=text] { width: 100%; padding: 12px; font-size: 18px;
  border: 1px solid #c9bb95; border-radius: 6px; background: #fff; color: #1f4e5a; }
.check { display: flex; gap: 10px; align-items: flex-start; margin-top: 18px; font-weight: 600; }
.check input { width: 22px; height: 22px; margin-top: 1px; }
.hint { font-size: 14px; color: #6b6b5e; margin: 6px 0 0 32px; }
button { width: 100%; margin-top: 22px; padding: 14px; font-size: 18px; font-weight: 700; color: #fff;
  background: #1f4e5a; border: 0; border-radius: 6px; }
button:disabled { opacity: .6; }
.error { background: #fbe9e4; color: #8a2f1d; border-radius: 6px; padding: 10px 12px; margin-bottom: 14px; }
"""


def page(t: dict, body: str) -> bytes:
    """A full HTML page around `body`; `t` needs a "title"."""
    return (
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<meta name='viewport' content='width=device-width, initial-scale=1'>"
        "<meta name='referrer' content='no-referrer'>"
        f"<title>{html.escape(t['title'])}</title><style>{STYLE}</style></head>"
        f"<body><main><div class='hat'>🎩</div>{body}</main></body></html>"
    ).encode()


def error_box(error: str) -> str:
    return f"<div class='error' role='alert'>{html.escape(error)}</div>" if error else ""


def submit_script(t: dict) -> str:
    """onsubmit handler: disable the button and show t["working"]."""
    return f"var b=this.querySelector('button');b.disabled=true;b.textContent={json.dumps(t['working'])};"


class SecretServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, t: dict, render_form, submit, values=None):
        super().__init__(address, Handler)
        self.token = secrets.token_urlsafe(18)
        self.t, self.render_form, self.submit = t, render_form, submit
        self.values = values or {}
        self.attempts = 0
        self.done = threading.Event()
        self.lock = threading.Lock()

    def closed_page(self, extra: str = "") -> bytes:
        t = self.t
        lead = f"{html.escape(extra)} " if extra else ""
        return page(t, f"<h1>{html.escape(t['closed_title'])}</h1><p>{lead}{html.escape(t['closed_body'])}</p>")

    def form_page(self, values: dict, error: str = "") -> bytes:
        return page(self.t, self.render_form(values, error))


class Handler(BaseHTTPRequestHandler):
    server: SecretServer

    def log_message(self, *args):  # never log requests (form bodies hold secrets)
        pass

    def send_page(self, code: int, body: bytes) -> None:
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; "
                         "script-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def valid_path(self) -> bool:
        return secrets.compare_digest(self.path.split("?")[0], f"/{self.server.token}")

    def do_GET(self):
        if not self.valid_path():
            self.send_error(404)
            return
        if self.server.done.is_set():
            self.send_page(410, self.server.closed_page())
            return
        self.send_page(200, self.server.form_page(self.server.values))

    def do_POST(self):
        if not self.valid_path():
            self.send_error(404)
            return
        server = self.server
        length = min(int(self.headers.get("Content-Length") or 0), 8192)
        fields = {k: v[0] for k, v in urllib.parse.parse_qs(self.rfile.read(length).decode("utf-8", "replace")).items()}
        with server.lock:  # one attempt at a time
            if server.done.is_set():
                self.send_page(410, server.closed_page())
                return
            result = server.submit(fields)
            fields.clear()
            if result[0] == "done":
                server.done.set()
                self.send_page(200, page(server.t, result[1]))
                return
            kind, error, values = result
            if kind == "invalid":
                self.send_page(400, server.form_page(values, error))
                return
            server.attempts += 1
            if server.attempts >= MAX_ATTEMPTS:
                server.done.set()
                self.send_page(429, server.closed_page(error))
                return
        self.send_page(401, server.form_page(values, error))


def free_port(preferred: int, prog: str) -> int:
    for port in [preferred] + list(range(preferred + 1, preferred + 50)):
        with socket.socket() as probe:
            try:
                probe.bind(("127.0.0.1", port))
                return port
            except OSError:
                continue
    raise SystemExit(f"{prog}: no free local port")


def serve(server: SecretServer, minutes: float) -> None:
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    server.done.wait(timeout=minutes * 60)
    server.done.set()
    # Give the browser a moment to receive the final page, then stop.
    threading.Event().wait(2)
    server.shutdown()


def run(server: SecretServer, minutes: float, foreground: bool) -> int:
    """Print {"url", "expires_in_min", "pid"} and serve (forked into the background unless foreground)."""
    info = {"url": f"http://127.0.0.1:{server.server_address[1]}/{server.token}", "expires_in_min": minutes}
    if foreground:
        print(json.dumps({**info, "pid": os.getpid()}), flush=True)
        serve(server, minutes)
        return 0
    pid = os.fork()
    if pid:
        server.server_close()  # the child owns the listening socket
        print(json.dumps({**info, "pid": pid}), flush=True)
        return 0
    os.setsid()
    devnull = os.open(os.devnull, os.O_RDWR)
    for fd in (0, 1, 2):
        os.dup2(devnull, fd)
    serve(server, minutes)
    os._exit(0)
