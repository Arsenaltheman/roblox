"""Uploads game audio (and optionally critter models) to Roblox and records the asset ids.

  python3 tools/cloud/upload_assets.py             # audio: assets/audio/game/*.ogg and voice/*.ogg
  python3 tools/cloud/upload_assets.py --models    # also assets/critters/*.fbx (asset-upload spike)
  python3 tools/cloud/upload_assets.py --dry-run   # list what would be uploaded

Ids go to assets/ids/{audio,voice,models}.json (with a hash of each file, so unchanged files are skipped
next time) and src/shared/Config/AssetIds.luau is regenerated. Commit both afterwards.
Roblox limits audio uploads per month, so only new or changed files are sent.
Endpoint: POST /assets/v1/assets (multipart), then poll GET /assets/v1/operations/{id}.
"""

import argparse
import hashlib
import json
import pathlib
import time

from common import API, ROOT, ApiError, creator, load_ids, multipart, request, save_ids

AUDIO = ROOT / "assets" / "audio" / "game"
MODELS = ROOT / "assets" / "critters"


def wait_for_operation(path: str) -> str:
    for _ in range(60):
        op = request("GET", f"{API}/assets/v1/{path}")
        if op.get("done"):
            if "error" in op:
                raise RuntimeError(f"upload failed: {op['error']}")
            return str(op["response"]["assetId"])
        time.sleep(2)
    raise TimeoutError(f"operation {path} did not finish")


def upload(file: pathlib.Path, asset_type: str, content_type: str, display_name: str) -> str:
    meta = {
        "assetType": asset_type,
        "displayName": display_name[:50],
        "description": "Critter Express",
        "creationContext": {"creator": creator()},
    }
    body, ctype = multipart({"request": json.dumps(meta)}, {"fileContent": (file.name, file.read_bytes(), content_type)})
    result = request("POST", f"{API}/assets/v1/assets", body, {"Content-Type": ctype})
    return wait_for_operation(result["path"])


def sync(table: str, files: list[pathlib.Path], asset_type: str, content_type: str, dry_run: bool) -> None:
    ids = load_ids(table)
    for file in files:
        key = file.stem
        digest = hashlib.sha256(file.read_bytes()).hexdigest()
        known = ids.get(key)
        if known and known.get("sha256") == digest and known.get("id"):
            continue
        if dry_run:
            print(f"would upload {table}/{key}")
            continue
        try:
            asset_id = upload(file, asset_type, content_type, f"CE {key}")
        except (ApiError, RuntimeError, TimeoutError) as err:
            print(f"FAILED {table}/{key}: {err}")
            continue
        ids[key] = {"id": asset_id, "sha256": digest}
        save_ids(table, ids)  # saved after every file, so a crash loses nothing
        print(f"{table}/{key} -> {asset_id}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--models", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    sync("audio", sorted(AUDIO.glob("*.ogg")), "Audio", "audio/ogg", args.dry_run)
    sync("voice", sorted((AUDIO / "voice").glob("*.ogg")), "Audio", "audio/ogg", args.dry_run)
    if args.models:
        sync("models", sorted(MODELS.glob("*.fbx")), "Model", "model/fbx", args.dry_run)


if __name__ == "__main__":
    main()
