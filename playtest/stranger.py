"""A stranger run's bookkeeping: pin it before it plays, classify it after (D0454).

    python3 playtest/stranger.py start <session-dir> --mission <file> [--model haiku] [--seat playtest/seat.sh]
    python3 playtest/stranger.py validate <session-dir> [--json]

`start` writes `batch.json` (build SHA and dirty flag, the mission file and its hash, the model, the
session directory, the launch time) and boots the seat through the launcher; the seat's own `receipt.json`
adds the seed line, engine, platform, launcher, frame cap and process priority once it is up.

`validate` never reads the agent's report. It reads the receipts the seat wrote and the inputs the agent
sent, and says VALID or VOID with every reason found. A VOID run keeps its artifacts and counts toward
nothing (the director's rule 3). First-rung success is read independently of the objective line (rule 6):
four ore in the pack at some burst, every input a physical burst, no inventory injected, no semantic
target command, the run valid.
"""
import argparse
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

PHYSICAL_KEYS = {"ticks", "keys", "mouse", "buttons", "moves", "settle", "until", "id", "sent_at", "quit"}
STALL_FACTOR = 10.0
KNOWN_INVARIANTS = ("ambiguous floor selection",)   # reported, not voiding: fires on every dug notch


def _git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True).stdout.strip()


def start(args):
    session = Path(args.session_dir).resolve()
    session.mkdir(parents=True, exist_ok=True)
    mission = Path(args.mission).resolve()
    text = mission.read_text()
    manifest = {
        "build": _git("rev-parse", "HEAD"),
        "build_dirty": bool(_git("status", "--porcelain", "--untracked-files=no")),
        "branch": _git("rev-parse", "--abbrev-ref", "HEAD"),
        "mission": str(mission),
        "mission_sha256": hashlib.sha256(text.encode()).hexdigest(),
        "model": args.model,
        "session_dir": str(session),
        "seat_launcher": args.seat,
        "started_at": int(time.time()),
    }
    (session / "batch.json").write_text(json.dumps(manifest, indent=1))
    env = dict(os.environ)
    if args.seed:
        env["SEED"] = str(args.seed)
        manifest["seed_requested"] = args.seed
    rc = subprocess.run(["bash", args.seat, str(session)], env=env).returncode
    if rc != 0:
        manifest["seat_boot"] = "FAILED rc=%d" % rc
        (session / "batch.json").write_text(json.dumps(manifest, indent=1))
        print("stranger: HARNESS_INVALID -- the seat did not boot (rc %d); read %s/seat.out" % (rc, session), file=sys.stderr)
        return 1
    receipt = json.loads((session / "receipt.json").read_text())
    boot = ""
    out = session / "seat.out"
    if out.exists():
        m = re.search(r"SINKFORGE_BOOT (site=\S+ seed=\S+ start=\S+)", out.read_text())
        boot = m.group(1) if m else ""
    manifest.update({"seat_boot": "ok", "boot": boot, "priority": receipt.get("priority"), "nice": receipt.get("nice"),
                     "launcher": receipt.get("launcher"), "engine": receipt.get("engine", {}).get("string"),
                     "platform": receipt.get("platform"), "max_fps": receipt.get("max_fps")})
    (session / "batch.json").write_text(json.dumps(manifest, indent=1))
    print(json.dumps({k: manifest[k] for k in ("build", "build_dirty", "boot", "priority", "launcher", "mission_sha256")}))
    return 0 if manifest["priority"] == "foreground" else 2


def _load(path):
    try:
        return json.loads(Path(path).read_text())
    except Exception:
        return None


def validate(session):
    session = Path(session)
    void = []
    notes = []
    manifest = _load(session / "batch.json") or {}
    receipt = _load(session / "receipt.json")
    invalid = _load(session / "HARNESS_INVALID.json")
    if invalid:
        void.append("HARNESS_INVALID by the supervisor: %s" % invalid.get("reason"))
    if receipt is None:
        void.append("no receipt.json: the seat never booted")
    elif receipt.get("priority") != "foreground":
        void.append("seat at %s priority (nice %s): HARNESS_INVALID" % (receipt.get("priority"), receipt.get("nice")))
    inputs = sorted(glob.glob(str(session / "input_*.json")))
    observations = {int(os.path.basename(p)[12:16]): _load(p) for p in sorted(glob.glob(str(session / "observation_*.json")))}
    response = _load(session / "response.json")
    last_command = _load(session / "command.json") or {}
    if response is None:
        void.append("no response.json")
    else:
        answered = int(response.get("id", -1))
        asked = int(last_command.get("id", answered))
        if asked > answered and not last_command.get("quit"):
            void.append("stale response id: command %d never answered (last answer %d)" % (asked, answered))
        if asked > answered and last_command.get("quit"):
            void.append("the quit at id %d was never answered: process death or a hang (last answer %d)" % (asked, answered))
        if not response.get("quit") and not last_command.get("quit"):
            notes.append("no quit was sent: the seat may still be running")
    for i, o in observations.items():
        if o is None:
            void.append("observation %d unreadable" % i)
            continue
        if o.get("capture_error", 0):
            void.append("capture error %s at burst %d" % (o["capture_error"], i))
        if o.get("still") is False:
            void.append("non-settling frame at burst %d (settled %s ticks)" % (i, o.get("settled_ticks")))
    timing = session / "timing.jsonl"
    if timing.exists():
        for line in timing.read_text().splitlines():
            try:
                r = json.loads(line)
            except Exception:
                continue
            sim_ms = (int(r.get("sim_ticks", 0)) + int(r.get("settled_ticks", 0))) / 60.0 * 1000.0
            if sim_ms > 0 and r.get("play_ms", 0) > STALL_FACTOR * sim_ms + 500:
                void.append("stall at burst %d: %d ms of wall for %.0f ms of sim" % (r.get("id"), r["play_ms"], sim_ms))
    for p in inputs:
        c = _load(p) or {}
        extra = set(c) - PHYSICAL_KEYS
        if extra:
            void.append("%s carries non-physical keys %s" % (os.path.basename(p), sorted(extra)))
    if (session / "save.json").exists():
        void.append("save.json was written: unexpected save access")
    seat_out = session / "seat.out"
    invariants = 0
    script_errors = 0
    if seat_out.exists():
        text = seat_out.read_text()
        script_errors = text.count("SCRIPT ERROR")
        for m in re.finditer(r"ERROR: Invariants: ([^\n]*)", text):
            invariants += 1
            if not any(k in m.group(1) for k in KNOWN_INVARIANTS):
                void.append("unexpected invariant: %s" % m.group(1)[:120])
        if script_errors:
            void.append("%d SCRIPT ERROR line(s) in seat.out" % script_errors)
    else:
        notes.append("no seat.out (a direct launch without --log-file)")
    if invariants:
        notes.append("%d known invariant report(s) (%s)" % (invariants, ", ".join(KNOWN_INVARIANTS)))
    # First-rung success, read from the seat's own receipts: the pack, never the agent's words.
    ore_at = None
    for i in sorted(observations):
        o = observations[i] or {}
        pack = (o.get("state") or {}).get("pack") or {}
        if int(pack.get("ore", 0)) >= 4:
            ore_at = (i, o.get("sim_seconds"))
            break
    first_rung = "unknown (no state in the receipts)" if not any((o or {}).get("state") for o in observations.values()) else (
        "yes at burst %d (%.1f s)" % ore_at if ore_at else "no")
    verdict = "VOID" if void else "VALID"
    return {"session": str(session), "verdict": verdict, "void_reasons": void, "notes": notes, "bursts": len(inputs),
            "first_rung_four_ore": first_rung if verdict == "VALID" or ore_at else ("void; would have read: " + first_rung),
            "build": manifest.get("build"), "boot": manifest.get("boot"), "mission_sha256": manifest.get("mission_sha256"),
            "model": manifest.get("model")}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("start")
    s.add_argument("session_dir")
    s.add_argument("--mission", required=True)
    s.add_argument("--model", default="claude-haiku-4-5")
    s.add_argument("--seat", default=str(Path(__file__).with_name("seat.sh")))
    s.add_argument("--seed", type=int, default=0, help="boot another world (the holdout run); 0 keeps the shipped seed")
    v = sub.add_parser("validate")
    v.add_argument("session_dir")
    v.add_argument("--json", action="store_true")
    args = parser.parse_args()
    if args.cmd == "start":
        return start(args)
    result = validate(args.session_dir)
    if args.json:
        print(json.dumps(result, indent=1))
    else:
        print("%s  %s  (%d bursts; first rung by the pack: %s)" % (result["verdict"], result["session"], result["bursts"], result["first_rung_four_ore"]))
        for r in result["void_reasons"]:
            print("  VOID  " + r)
        for n in result["notes"]:
            print("  note  " + n)
    return 0 if result["verdict"] == "VALID" else 1


if __name__ == "__main__":
    raise SystemExit(main())
