"""Shared Telegram Bot API helpers for bin/telegram and bin/telegram-connect (stdlib only).

Token: $TELEGRAM_BOT_TOKEN, else <state>/telegram/token (mode 600).
State: $SYLVESTER_STATE, else /workspace/.sylvester, else
~/.config/sylvester-chatwell. API base: $TELEGRAM_API_BASE (tests), else
https://api.telegram.org. The token is part of every request URL, so URLs and
raw exceptions are never printed.
"""
from __future__ import annotations

import json
import os
import secrets
import urllib.error
import urllib.request

TIMEOUT = 40


class NotConnected(Exception):
    """No token, or Telegram rejected it."""


class Unreachable(Exception):
    """Telegram could not be reached."""


class ApiError(Exception):
    """Telegram answered ok:false (other than a rejected token)."""


def state_dir() -> str:
    if os.environ.get("SYLVESTER_STATE"):
        return os.environ["SYLVESTER_STATE"]
    if os.path.isdir("/workspace") and os.access("/workspace", os.W_OK):
        return "/workspace/.sylvester"
    config = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(config, "sylvester-chatwell")


def tg_dir() -> str:
    path = os.path.join(state_dir(), "telegram")
    os.makedirs(path, mode=0o700, exist_ok=True)
    return path


def household_dir() -> str:
    if os.environ.get("SYLVESTER_HOUSEHOLD"):
        return os.environ["SYLVESTER_HOUSEHOLD"]
    if os.path.isdir("/workspace") and os.access("/workspace", os.W_OK):
        return "/workspace/sylvester-household"
    if os.environ.get("SYLVESTER_STATE"):
        return os.path.join(os.environ["SYLVESTER_STATE"], "household")
    config = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(config, "sylvester-chatwell", "household")


def api_base() -> str:
    return os.environ.get("TELEGRAM_API_BASE", "https://api.telegram.org").rstrip("/")


def write_private(path: str, data: bytes) -> None:
    """Atomically write a file readable only by this account."""
    tmp = f"{path}.{secrets.token_hex(4)}.tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "wb") as handle:
        handle.write(data)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def write_json(path: str, value) -> None:
    write_private(path, (json.dumps(value, ensure_ascii=False, indent=1) + "\n").encode())


def read_json(path: str, default):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (FileNotFoundError, ValueError):
        return default


def token_path() -> str:
    return os.path.join(tg_dir(), "token")


def load_token() -> str:
    token = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
    if token:
        return token
    try:
        with open(token_path(), encoding="utf-8") as handle:
            token = handle.read().strip()
    except FileNotFoundError:
        token = ""
    if not token:
        raise NotConnected("not connected")
    return token


def save_token(token: str) -> None:
    write_private(token_path(), (token + "\n").encode())


def _request(url: str, data: bytes | None, headers: dict, timeout: float) -> dict:
    request = urllib.request.Request(url, data=data, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read()
    except urllib.error.HTTPError as error:
        body = error.read()
        if not body:
            if error.code in (401, 404):
                raise NotConnected("token rejected") from None
            raise ApiError(f"HTTP {error.code}") from None
    except (urllib.error.URLError, OSError) as error:
        reason = getattr(error, "reason", error)
        raise Unreachable(f"Telegram unreachable ({type(reason).__name__})") from None
    try:
        reply = json.loads(body)
    except ValueError:
        raise ApiError("invalid reply from Telegram") from None
    if not reply.get("ok"):
        code = reply.get("error_code")
        if code in (401, 404):
            raise NotConnected("token rejected")
        raise ApiError(str(reply.get("description") or f"error {code}")[:200])
    return reply.get("result")


def call(token: str, method: str, params: dict | None = None, timeout: float = TIMEOUT):
    data = json.dumps(params or {}).encode()
    return _request(f"{api_base()}/bot{token}/{method}", data, {"Content-Type": "application/json"}, timeout)


def call_multipart(token: str, method: str, fields: dict, file_field: str, file_path: str):
    boundary = secrets.token_hex(16)
    parts = []
    for key, value in fields.items():
        if value is None:
            continue
        if not isinstance(value, str):
            value = json.dumps(value)
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode())
    name = os.path.basename(file_path).replace('"', "")
    with open(file_path, "rb") as handle:
        content = handle.read()
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{file_field}"; filename="{name}"\r\n'
                 "Content-Type: application/octet-stream\r\n\r\n".encode() + content + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    return _request(f"{api_base()}/bot{token}/{method}", b"".join(parts),
                    {"Content-Type": f"multipart/form-data; boundary={boundary}"}, 120)


def download(token: str, file_path: str, dest: str, max_bytes: int) -> int:
    """Download a file Telegram reported via getFile; returns its size."""
    url = f"{api_base()}/file/bot{token}/{file_path}"
    try:
        with urllib.request.urlopen(url, timeout=120) as response:
            data = response.read(max_bytes + 1)
    except (urllib.error.URLError, OSError) as error:
        reason = getattr(error, "reason", error)
        raise Unreachable(f"download failed ({type(reason).__name__})") from None
    if len(data) > max_bytes:
        raise ApiError("file too large")
    with open(dest, "wb") as handle:
        handle.write(data)
    return len(data)
