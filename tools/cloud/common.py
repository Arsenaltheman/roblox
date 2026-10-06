"""Shared helpers for the Roblox Open Cloud tools in this folder (Python 3 standard library only).

Configuration comes from environment variables, set in the cloud environment's settings (never in chat
or in the repo):
  ROBLOX_API_KEY         Open Cloud API key (required)
  ROBLOX_UNIVERSE_ID     universe (experience) id of the TEST experience
  ROBLOX_TEST_PLACE_ID   place id of the TEST place
  ROBLOX_LIVE_PLACE_ID   place id of the LIVE place (only for publish.py --live)
  ROBLOX_LIVE_UNIVERSE_ID  universe id of the LIVE experience (only for publish.py --live)
  ROBLOX_GROUP_ID or ROBLOX_USER_ID  who owns uploaded assets (group preferred)
"""

from __future__ import annotations

import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[2]
IDS_DIR = ROOT / "assets" / "ids"
ASSET_IDS_MODULE = ROOT / "src" / "shared" / "Config" / "AssetIds.luau"
API = "https://apis.roblox.com"


def env(name: str, required: bool = True) -> str:
    value = os.environ.get(name, "").strip()
    if required and not value:
        sys.exit(f"Missing environment variable {name}. See docs/STATUS.md (Owner setup).")
    return value


def creator() -> dict:
    group = env("ROBLOX_GROUP_ID", required=False)
    if group:
        return {"groupId": group}
    return {"userId": env("ROBLOX_USER_ID")}


class ApiError(Exception):
    def __init__(self, status: int, body: str):
        super().__init__(f"HTTP {status}: {body[:500]}")
        self.status = status
        self.body = body


def request(method: str, url: str, body: bytes | None = None, headers: dict | None = None, retries: int = 4):
    """Sends a request with the API key. Retries 429 and 5xx with backoff. Returns parsed JSON (or {})."""
    all_headers = {"x-api-key": env("ROBLOX_API_KEY")}
    all_headers.update(headers or {})
    delay = 2.0
    for attempt in range(retries + 1):
        req = urllib.request.Request(url, data=body, method=method, headers=all_headers)
        try:
            with urllib.request.urlopen(req, timeout=120) as response:
                text = response.read().decode("utf-8", "replace")
                return json.loads(text) if text.strip() else {}
        except urllib.error.HTTPError as err:
            text = err.read().decode("utf-8", "replace")
            if (err.code == 429 or err.code >= 500) and attempt < retries:
                retry_after = err.headers.get("Retry-After")
                time.sleep(float(retry_after) if retry_after and retry_after.isdigit() else delay)
                delay *= 2
                continue
            raise ApiError(err.code, text) from None
    raise RuntimeError("unreachable")


def json_request(method: str, url: str, payload: dict) -> dict:
    return request(method, url, json.dumps(payload).encode(), {"Content-Type": "application/json"})


def multipart(fields: dict[str, str], files: dict[str, tuple[str, bytes, str]]) -> tuple[bytes, str]:
    """Encodes form fields and files (name -> (filename, bytes, content type)) as multipart/form-data."""
    boundary = uuid.uuid4().hex
    parts: list[bytes] = []
    for name, value in fields.items():
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    for name, (filename, data, content_type) in files.items():
        head = (
            f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'
            f"Content-Type: {content_type}\r\n\r\n"
        )
        parts.append(head.encode() + data + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def load_ids(name: str) -> dict:
    path = IDS_DIR / f"{name}.json"
    return json.loads(path.read_text()) if path.exists() else {}


def save_ids(name: str, data: dict) -> None:
    IDS_DIR.mkdir(parents=True, exist_ok=True)
    (IDS_DIR / f"{name}.json").write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    write_asset_ids_module()


def _luau_table(entries: dict[str, str | int], quote: bool) -> str:
    if not entries:
        return "{}"
    lines = []
    for key in sorted(entries):
        value = f'"{entries[key]}"' if quote else str(entries[key])
        lines.append(f"\t\t{key} = {value},")
    return "{\n" + "\n".join(lines) + "\n\t}"


def write_asset_ids_module() -> None:
    """Regenerates src/shared/Config/AssetIds.luau from assets/ids/*.json."""
    audio = {k: f"rbxassetid://{v['id']}" for k, v in load_ids("audio").items() if v.get("id")}
    voice = {}
    for k, v in load_ids("voice").items():
        if v.get("id"):
            # Announcer lines ("ann_*") are played by sound key; the rest are species name callouts.
            (audio if k.startswith("ann_") else voice)[k] = f"rbxassetid://{v['id']}"
    models = {k: int(v["id"]) for k, v in load_ids("models").items() if v.get("id")}
    images = {k: f"rbxassetid://{v['id']}" for k, v in load_ids("images").items() if v.get("id")}
    all_products = load_ids("products")
    products = {k: int(v["id"]) for k, v in all_products.items() if v.get("id") and not k.startswith("__")}
    subscription = all_products.get("__subscription", {}).get("id", "")
    group_id = int(all_products.get("__group", {}).get("id", 0) or 0)
    text = f"""--!strict
-- GENERATED by tools/cloud/upload_assets.py and tools/cloud/create_products.py. Do not edit by hand:
-- the source of truth is assets/ids/*.json. Empty until the Roblox upload has run (docs/STATUS.md).

return {{
	-- Sound key -> "rbxassetid://..."
	audio = {_luau_table(audio, True)} :: {{ [string]: string }},
	-- Species id -> voice line "rbxassetid://..."
	voice = {_luau_table(voice, True)} :: {{ [string]: string }},
	-- Species id -> MeshPart asset id (critter models)
	models = {_luau_table(models, False)} :: {{ [string]: number }},
	-- Product key (Config/Products) -> game pass / developer product id
	products = {_luau_table(products, False)} :: {{ [string]: number }},
	-- UI icon name (assets/ui/<name>.png) -> "rbxassetid://..."
	images = {_luau_table(images, True)} :: {{ [string]: string }},
	-- Sheriff's Club subscription id ("" until created) and the group-reward group id (0 = off)
	subscription = "{subscription}",
	groupId = {group_id},
}}
"""
    ASSET_IDS_MODULE.write_text(text)
