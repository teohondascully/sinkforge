"""Watch stranger seats; declare a stuck or dead one HARNESS_INVALID and stand a fresh one up (D0455).

    python3 playtest/supervisor.py <session-dir> [<session-dir> ...] [--interval 30] [--patience 150]

Every `interval` seconds each seat is checked: the process named in its `receipt.json` (verified to be a
seat whose arguments name this very session directory) must be alive, and a command written to
`command.json` must be answered within `patience` seconds. A seat that fails either test is finished:
its `HARNESS_INVALID.json` names the reason, the last frame and the unanswered command; `seat.out` and
every frame stay where they are; only the owned process is terminated; and a replacement seat is booted
into a NEW directory (`<session-dir>-r<n>`) pinned with the same mission through `stranger.py start`. No
command or response file is ever reused or rewritten. The old run is void from that moment (rule 3); the
new directory is for a new stranger, not the one whose seat died.
"""
import argparse
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path


def _load(path):
    try:
        return json.loads(Path(path).read_text())
    except Exception:
        return None


def _owned_pid(session):
    """The seat's pid, only if that pid is a Godot seat whose arguments name this session directory."""
    receipt = _load(session / "receipt.json")
    if not receipt or "pid" not in receipt:
        return None
    pid = int(receipt["pid"])
    out = subprocess.run(["ps", "-o", "command=", "-p", str(pid)], capture_output=True, text=True).stdout
    if "seat.gd" in out and ("--session-dir=%s" % session) in out:
        return pid
    return None


def _check(session, patience):
    """Returns (reason or None)."""
    if not (session / "receipt.json").exists():
        return None                          # not booted yet: not ours to judge
    if (session / "HARNESS_INVALID.json").exists():
        return None                          # already finished
    if (_load(session / "response.json") or {}).get("quit"):
        return None                          # quit cleanly: the process is meant to be gone
    if _owned_pid(session) is None:
        return "process death: the seat's pid is gone or is not this session's seat"
    command = _load(session / "command.json") or {}
    response = _load(session / "response.json") or {}
    asked = int(command.get("id", -1))
    answered = int(response.get("id", -1))
    if asked > answered:
        sent = int(command.get("sent_at", 0)) / 1000.0
        waited = time.time() - sent if sent else 0.0
        if waited > patience:
            return "stale response id: command %d unanswered for %.0f s (last answer %d)" % (asked, waited, answered)
    return None


def _finish(session, reason, relaunch):
    pid = _owned_pid(session)
    frames = sorted(session.glob("frame_*.png"))
    record = {"reason": reason, "at": int(time.time()), "pid": pid, "last_frame": str(frames[-1]) if frames else None,
              "last_command": _load(session / "command.json"), "last_response_id": (_load(session / "response.json") or {}).get("id")}
    (session / "HARNESS_INVALID.json").write_text(json.dumps(record, indent=1))
    if pid is not None:
        os.kill(pid, signal.SIGTERM)
        time.sleep(2)
        if _owned_pid(session) is not None:
            os.kill(pid, signal.SIGKILL)
    print("supervisor: %s HARNESS_INVALID -- %s" % (session, reason), flush=True)
    if not relaunch:
        return None
    manifest = _load(session / "batch.json") or {}
    mission = manifest.get("mission")
    if not mission or not Path(mission).exists():
        print("supervisor: no mission in batch.json; no relaunch", flush=True)
        return None
    n = 1
    while (Path(str(session) + "-r%d" % n)).exists():
        n += 1
    fresh = Path(str(session) + "-r%d" % n)
    rc = subprocess.run([sys.executable, str(Path(__file__).with_name("stranger.py")), "start", str(fresh), "--mission", mission,
                         "--model", manifest.get("model", "claude-haiku-4-5")]).returncode
    print("supervisor: fresh seat at %s (rc %d); a NEW stranger must be sent there" % (fresh, rc), flush=True)
    return fresh


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("sessions", nargs="+")
    parser.add_argument("--interval", type=float, default=30.0)
    parser.add_argument("--patience", type=float, default=150.0)
    parser.add_argument("--no-relaunch", action="store_true")
    parser.add_argument("--once", action="store_true", help="one pass, then exit (for tests)")
    args = parser.parse_args()
    sessions = [Path(s).resolve() for s in args.sessions]
    live = set(sessions)
    while live:
        for session in list(live):
            reason = _check(session, args.patience)
            if reason:
                _finish(session, reason, not args.no_relaunch)
                live.discard(session)
                continue
            response = _load(session / "response.json") or {}
            if response.get("quit"):
                print("supervisor: %s quit cleanly at tick %s" % (session, response.get("tick")), flush=True)
                live.discard(session)
        if args.once:
            break
        time.sleep(args.interval)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
