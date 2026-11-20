"""Read YouTube/Google cookies from the local Chrome/Edge profile.

Used by Echo Music Desktop's 'Importa dal browser (automatico)' action so the
user does not need to copy cookies manually. Only cookies for Google/YouTube
hosts are returned, as a `name=value; ...` header on stdout.
"""
import argparse
import base64
import json
import os
import shutil
import sqlite3
import sys
import tempfile

from Crypto.Cipher import AES
from win32crypt import CryptUnprotectData

ALLOWED = ("youtube.com", "google.com", "gstatic.com", "googleusercontent.com", "googleapis.com", "g.co")


def local_state_path(browser):
    root = os.environ["LOCALAPPDATA"]
    if browser == "edge":
        return os.path.join(root, "Microsoft", "Edge", "User Data", "Local State")
    if browser == "chrome":
        return os.path.join(root, "Google", "Chrome", "User Data", "Local State")
    raise ValueError("browser must be edge or chrome")


def cookie_db_path(browser, profile):
    root = os.environ["LOCALAPPDATA"]
    if browser == "edge":
        base = os.path.join(root, "Microsoft", "Edge", "User Data")
    else:
        base = os.path.join(root, "Google", "Chrome", "User Data")
    return os.path.join(base, profile, "Network", "Cookies")


def aes_key(state_path):
    with open(state_path, "r", encoding="utf-8") as f:
        state = json.load(f)
    raw = base64.b64decode(state["os_crypt"]["encrypted_key"])
    if raw[:5] != b"DPAPI":
        raise ValueError("unsupported encrypted_key format")
    return CryptUnprotectData(raw[5:], None, None, None, 0)[1]


def decrypt(value, key):
    if not value:
        return ""
    if value[:3] in (b"v10", b"v11"):
        nonce = value[3:15]
        ciphertext = value[15:]
        return AES.new(key, AES.MODE_GCM, nonce=nonce).decrypt(ciphertext).decode("utf-8", "replace")
    return CryptUnprotectData(value, None, None, None, 0)[1].decode("utf-8", "replace")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--browser", default="edge", choices=["edge", "chrome"])
    parser.add_argument("--profile", default="Default")
    args = parser.parse_args()

    state = local_state_path(args.browser)
    db = cookie_db_path(args.browser, args.profile)
    if not os.path.isfile(state) or not os.path.isfile(db):
        print("Browser profile not found", file=sys.stderr)
        return 2

    key = aes_key(state)
    tmpdir = tempfile.mkdtemp(prefix="echo-cookies-")
    try:
        copy = os.path.join(tmpdir, "Cookies")
        shutil.copy2(db, copy)
        for suffix in ("-wal", "-shm"):
            if os.path.isfile(db + suffix):
                shutil.copy2(db + suffix, copy + suffix)
        con = sqlite3.connect(copy)
        rows = con.execute(
            "SELECT name, encrypted_value, host_key FROM cookies WHERE host_key LIKE '%youtube.com' "
            "OR host_key LIKE '%google.com' OR host_key LIKE '%gstatic.com' "
            "OR host_key LIKE '%googleusercontent.com' OR host_key LIKE '%googleapis.com' OR host_key='g.co'"
        ).fetchall()
        con.close()

        pairs = []
        seen = set()
        for name, encrypted, host in rows:
            try:
                value = decrypt(encrypted, key)
            except Exception:
                continue
            if value and name not in seen:
                seen.add(name)
                pairs.append(f"{name}={value}")
        print("; ".join(pairs))
        return 0
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
