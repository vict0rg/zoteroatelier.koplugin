#!/usr/bin/env python3
"""Configure read-only Dropbox OAuth PKCE for the experimental Zotero Atelier module.

Runs locally only. Do NOT paste tokens into chats or commit generated credentials.
Requires Python 3.8+. Uses standard library only.
"""
import base64
import hashlib
import json
import secrets
import stat
import webbrowser
from datetime import datetime
from getpass import getpass
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

DATA_DIR = Path.home() / ".var/app/rocks.koreader.KOReader/config/koreader"
SETTINGS = DATA_DIR / "zotero/dropbox_atelier.lua"


def lua_string(value):
    if any(ord(c) < 32 or ord(c) == 127 for c in value):
        raise ValueError("Invalid control character in configuration.")
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    print("Dropbox app requirements: Scoped access / Full Dropbox; files.content.read only.")
    print("This authorizes reading files throughout your Dropbox. No upload is implemented.")
    key = input("Dropbox App key (NOT App secret): ").strip()
    root = input("Dropbox REMOTE folder holding Zotero attachment-key folders: ").strip().rstrip("/")
    if not key or not root.startswith("/") or root == "/" or ".." in root or "\\" in root:
        raise ValueError("App key and an absolute Dropbox storage path are required.")
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode("ascii")).digest()).decode("ascii").rstrip("=")
    authorization = "https://www.dropbox.com/oauth2/authorize?" + urlencode({
        "client_id": key,
        "response_type": "code",
        "token_access_type": "offline",
        "code_challenge": challenge,
        "code_challenge_method": "S256",
    })
    print("Authorize the Dropbox App using this URL:", authorization)
    webbrowser.open(authorization)
    code = getpass("Paste Dropbox authorization code (hidden): ").strip()
    if not code:
        raise ValueError("Authorization code missing.")

    body = urlencode({
        "code": code,
        "grant_type": "authorization_code",
        "client_id": key,
        "code_verifier": verifier,
    }).encode("utf-8")
    req = Request("https://api.dropbox.com/oauth2/token", data=body,
                  headers={"Content-Type": "application/x-www-form-urlencoded"}, method="POST")
    with urlopen(req, timeout=40) as response:
        data = json.load(response)
    refresh = data.get("refresh_token")
    if not refresh:
        raise RuntimeError("Dropbox did not supply an offline refresh token.")

    text = (
        "return {\n    enabled = true,\n"
        "    app_key = " + lua_string(key) + ",\n"
        "    refresh_token = " + lua_string(refresh) + ",\n"
        "    storage_root = " + lua_string(root) + ",\n}\n"
    )

    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    if SETTINGS.exists():
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        old = SETTINGS.with_name(SETTINGS.name + ".backup-" + stamp)
        # Backups may also contain credentials: protect before writing.
        old.write_bytes(SETTINGS.read_bytes())
        old.chmod(stat.S_IRUSR | stat.S_IWUSR)
        print("Previous credential configuration backed up locally.")
    # Open with restrictive permissions from the outset, avoiding a world-readable window.
    import os
    fd = os.open(SETTINGS, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as file:
        file.write(text)
    SETTINGS.chmod(stat.S_IRUSR | stat.S_IWUSR)
    print("Saved Dropbox credentials locally:", SETTINGS)
    print("Do NOT share this file. Restart KOReader before testing.")


if __name__ == "__main__":
    main()
