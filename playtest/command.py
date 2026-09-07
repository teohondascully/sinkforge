"""Send one input burst to a running playtest seat; no game-state access."""
import argparse
import json
import os
from pathlib import Path
import time


def _log_timing(session_dir, previous, command, response):
    """The loop measured, one line a burst (D0446): where the wall time goes. `think` is the agent's own
    latency between the last frame's return and this command; `pickup` the seat noticing the file;
    `play` the burst's ticks plus the settle; `capture` the PNG's save and this poll noticing it."""
    now = int(time.time() * 1000)
    sent = int(command.get("sent_at", now))
    received = int(response.get("received_at", sent))
    captured = int(response.get("captured_at", now))
    row = {"id": command["id"], "think_ms": sent - int(previous.get("returned_at", sent)), "pickup_ms": received - sent,
           "play_ms": captured - received, "capture_ms": now - captured, "wall_ms": now - int(previous.get("returned_at", sent)),
           "sim_ticks": int(response.get("tick", 0)) - int(previous.get("tick", 0)), "settled_ticks": response.get("settled_ticks", 0)}
    response["returned_at"] = now
    with (session_dir / "timing.jsonl").open("a") as log:
        log.write(json.dumps(row) + "\n")
    with (session_dir / "response.json").open("w") as f:
        json.dump(response, f)


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
    parser.add_argument("--full", action="store_true", help="print the whole receipt (scripts); without it the line carries only what a player has -- the screenshot and the clock (D0487)")
    args = parser.parse_args()
    response_path = args.session_dir / "response.json"
    previous = json.loads(response_path.read_text())
    command = json.loads(args.command)
    command["id"] = previous["id"] + 1
    command["sent_at"] = int(time.time() * 1000)
    pending = args.session_dir / "command.json.tmp"
    pending.write_text(json.dumps(command))
    os.replace(pending, args.session_dir / "command.json")
    deadline = time.monotonic() + args.timeout
    while time.monotonic() < deadline:
        response = json.loads(response_path.read_text())
        if response["id"] == command["id"]:
            _log_timing(args.session_dir, previous, command, response)
            if args.note is not None:
                with (args.session_dir / "JOURNAL.md").open("a") as journal:
                    journal.write("\n## Burst %d (%.1f s)\n%s\n" % (command["id"], response.get("sim_seconds", -1.0), args.note.strip()))
            # THE PLAYER'S LINE (D0487): a stranger reads this JSON; the receipt's `refusal`, `lesson`, `broke`,
            # `state` are the seat's private evidence and not on any screen, and the agents quoted them
            # ("refusal_at", "dropped_floor") as if the game had said them. Scripts ask for --full.
            shown = response if args.full else {k: response[k] for k in ("id", "screenshot", "sim_seconds", "error", "capture_error") if k in response}
            print(json.dumps(shown))
            return 1 if response.get("error") or response.get("capture_error", 0) else 0
        time.sleep(0.05)
    raise TimeoutError(f"No response after {args.timeout:.0f} seconds; inspect the game's log")


if __name__ == "__main__":
    raise SystemExit(main())
