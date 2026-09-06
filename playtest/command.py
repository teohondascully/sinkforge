"""Send one input burst to a running playtest seat; no game-state access."""
import argparse
import json
import os
from pathlib import Path
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session_dir", type=Path)
    parser.add_argument("command", help='JSON: {"ticks":60,"keys":["D"],"mouse":[640,360],"buttons":[]}')
    args = parser.parse_args()
    response_path = args.session_dir / "response.json"
    previous = json.loads(response_path.read_text())
    command = json.loads(args.command)
    command["id"] = previous["id"] + 1
    pending = args.session_dir / "command.json.tmp"
    pending.write_text(json.dumps(command))
    os.replace(pending, args.session_dir / "command.json")
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        response = json.loads(response_path.read_text())
        if response["id"] == command["id"]:
            print(json.dumps(response))
            return 1 if response.get("error") or response.get("capture_error", 0) else 0
        time.sleep(0.05)
    raise TimeoutError("No response after 30 seconds; inspect the game's log")


if __name__ == "__main__":
    raise SystemExit(main())
