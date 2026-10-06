"""Runs a Luau script on a fresh server of the TEST place through Open Cloud Luau Execution.

  python3 tools/cloud/run_luau.py tests/cloud/smoke.luau

The script runs on a real Roblox server with the published place loaded (so publish first). Its return
value and logs are printed. Exit code 0 only if the task completed and returned a table with ok = true.

Endpoint (Luau Execution, v2): POST /cloud/v2/universes/{u}/places/{p}/luau-execution-session-tasks,
poll GET on the returned task path, logs at {task}/logs. Not yet exercised against the real API from this
repo (apis.roblox.com was blocked while it was written): check the first run's output carefully.
"""

import json
import pathlib
import sys
import time

from common import API, env, json_request, request


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    script = pathlib.Path(sys.argv[1]).read_text()
    universe = env("ROBLOX_UNIVERSE_ID")
    place = env("ROBLOX_TEST_PLACE_ID")

    task = json_request(
        "POST",
        f"{API}/cloud/v2/universes/{universe}/places/{place}/luau-execution-session-tasks",
        {"script": script, "timeout": "240s"},
    )
    path = task["path"]
    print(f"task {path}")
    for _ in range(150):
        task = request("GET", f"{API}/cloud/v2/{path}")
        if task.get("state") in ("COMPLETE", "FAILED", "CANCELLED"):
            break
        time.sleep(2)

    try:
        logs = request("GET", f"{API}/cloud/v2/{path}/logs")
        for chunk in logs.get("luauExecutionSessionTaskLogs", []):
            for line in chunk.get("messages", []):
                print(f"  | {line}")
    except Exception as err:  # logs are best effort
        print(f"(could not read logs: {err})")

    state = task.get("state")
    print(f"state: {state}")
    if state != "COMPLETE":
        print(json.dumps(task.get("error", task), indent=2))
        sys.exit(1)
    results = task.get("output", {}).get("results", [])
    print(json.dumps(results, indent=2))
    first = results[0] if results else None
    if not (isinstance(first, dict) and first.get("ok") is True):
        sys.exit(1)


if __name__ == "__main__":
    main()
