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
    # A window in the background is throttled by the OS (App Nap): a 2-tick burst took 35 s to answer once.
    # Launch the seat with --always-on-top and give a burst time to come back.
    parser.add_argument("--timeout", type=float, default=120.0, help="seconds to wait for the frame (default 120)")
    # One round-trip per burst (D0439): the journal line rides the command, stamped with the burst's id and
    # game time once the frame is back, so a screen-led agent makes one call and one frame read a burst.
    parser.add_argument("--note", default=None, help="a journal entry for this burst, appended to JOURNAL.md with its id and game time")
    args = parser.parse_args()
    response_path = args.session_dir / "response.json"
    previous = json.loads(response_path.read_text())
    command = json.loads(args.command)
    command["id"] = previous["id"] + 1
    pending = args.session_dir / "command.json.tmp"
    pending.write_text(json.dumps(command))
    os.replace(pending, args.session_dir / "command.json")
    deadline = time.monotonic() + args.timeout
    while time.monotonic() < deadline:
        response = json.loads(response_path.read_text())
        if response["id"] == command["id"]:
            if args.note is not None:
                with (args.session_dir / "JOURNAL.md").open("a") as journal:
                    journal.write("\n## Burst %d (%.1f s)\n%s\n" % (command["id"], response.get("sim_seconds", -1.0), args.note.strip()))
            print(json.dumps(response))
            return 1 if response.get("error") or response.get("capture_error", 0) else 0
        time.sleep(0.05)
    raise TimeoutError(f"No response after {args.timeout:.0f} seconds; inspect the game's log")


if __name__ == "__main__":
    raise SystemExit(main())
