"""Builds the place with Rojo and publishes it to the TEST place (or LIVE with --live).

  python3 tools/cloud/publish.py            # TEST, published version (servers pick it up)
  python3 tools/cloud/publish.py --saved    # TEST, saved version only
  python3 tools/cloud/publish.py --live --confirm-live   # LIVE: only after the owner says "ship it"

Prints the new version number. Endpoint: POST /universes/v1/{universe}/places/{place}/versions.
"""

import argparse
import subprocess
import sys

from common import API, ROOT, env, request


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--saved", action="store_true", help="save without publishing")
    parser.add_argument("--live", action="store_true", help="publish to the LIVE place")
    parser.add_argument("--confirm-live", action="store_true", help="required together with --live")
    args = parser.parse_args()

    if args.live and not args.confirm_live:
        sys.exit("Refusing to publish LIVE without --confirm-live (needs the owner's go-ahead).")
    universe = env("ROBLOX_LIVE_UNIVERSE_ID" if args.live else "ROBLOX_UNIVERSE_ID")
    place = env("ROBLOX_LIVE_PLACE_ID" if args.live else "ROBLOX_TEST_PLACE_ID")

    out = ROOT / "build" / "CritterExpress.rbxl"
    out.parent.mkdir(exist_ok=True)
    subprocess.run(["rojo", "build", str(ROOT / "default.project.json"), "-o", str(out)], check=True)

    version_type = "Saved" if args.saved else "Published"
    url = f"{API}/universes/v1/{universe}/places/{place}/versions?versionType={version_type}"
    result = request("POST", url, out.read_bytes(), {"Content-Type": "application/octet-stream"})
    print(f"{'LIVE' if args.live else 'TEST'} place {place}: version {result.get('versionNumber')} ({version_type})")


if __name__ == "__main__":
    main()
