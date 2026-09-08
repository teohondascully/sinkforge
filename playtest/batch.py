"""One command for a stranger batch: N seats, each in its OWN worktree at the pinned head with a clone of the
import cache, tiled across the screen, in FRESH session directories, the supervisor over them (D0501).

    python3 playtest/batch.py start N --root <dir> --mission <template> [--head HEAD] [--seed S] [--model M]
    python3 playtest/batch.py stop --root <dir> --batch <root>/batch_NN-MM.json

`start` allocates stranger numbers past the highest `stranger-<n>` under --root (a session directory is never
reused: a seat refuses one, and the supervisor reads a stale pid as death -- the 82-87 batch was void for
exactly that), writes one mission per seat from the template (the template's session path replaced), adds
a detached worktree per seat under <root>/seat-<n> and clones `.godot/` into it (APFS clonefile, no space:
the recordings are .gdignored so the cache is small), boots each seat from ITS worktree's seat.sh with
TILE=i,N, checks the seat's OWN seat.out for the boot line, starts the supervisor, and writes the batch
manifest. `stop` kills the batch's seats and supervisor and removes its worktrees; session directories stay.
"""
import argparse
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent


def _run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def _next_numbers(root, n):
    top = 0
    for p in root.glob("stranger-*"):
        m = re.match(r"stranger-(\d+)$", p.name)
        if m:
            top = max(top, int(m.group(1)))
    return list(range(top + 1, top + 1 + n))


def _worktree(root, number, head):
    path = root / ("seat-%d" % number)
    if path.exists():
        raise SystemExit("batch: %s exists; a seat's worktree is never reused" % path)
    r = _run(["git", "worktree", "add", "--detach", str(path), head], cwd=REPO)
    if r.returncode != 0:
        raise SystemExit("batch: git worktree add failed: %s" % r.stderr.strip())
    cache = REPO / ".godot"
    if cache.exists():
        r = _run(["cp", "-Rc", str(cache), str(path / ".godot")])   # APFS clone: seconds, no space
        if r.returncode != 0:
            shutil.copytree(cache, path / ".godot")
    return path


def _mission(template, session, number):
    text = Path(template).read_text()
    src = re.search(r"(/\S+/stranger-\d+)", text)
    if not src:
        raise SystemExit("batch: the mission template names no stranger-<n> session path")
    return text.replace(src.group(1), str(session))


def start(args):
    root = Path(args.root).resolve()
    root.mkdir(parents=True, exist_ok=True)
    head = args.head or _run(["git", "rev-parse", "HEAD"], cwd=REPO).stdout.strip()
    numbers = _next_numbers(root, args.n)
    seats = []
    for i, number in enumerate(numbers):
        session = root / ("stranger-%d" % number)
        if session.exists():
            raise SystemExit("batch: %s exists" % session)
        session.mkdir()
        mission = root / ("mission_%d.txt" % number)
        mission.write_text(_mission(args.mission, session, number))
        tree = _worktree(root, number, head)
        env = dict(os.environ, TILE="%d,%d" % (i, args.n))
        cmd = [sys.executable, str(HERE / "stranger.py"), "start", str(session), "--mission", str(mission),
               "--model", args.model, "--seat", str(tree / "playtest" / "seat.sh")]
        if args.seed:
            cmd += ["--seed", str(args.seed)]
        r = subprocess.run(cmd, env=env, capture_output=True, text=True)
        out = (session / "seat.out").read_text() if (session / "seat.out").exists() else ""
        booted = "SINKFORGE_BOOT" in out and "session already used" not in out and r.returncode == 0
        pid = None
        try:
            pid = json.loads((session / "receipt.json").read_text()).get("pid")
        except Exception:
            pass
        seats.append({"number": number, "session": str(session), "mission": str(mission), "worktree": str(tree),
                      "tile": i, "booted": booted, "pid": pid, "start_rc": r.returncode})
        print(json.dumps({"seat": number, "booted": booted, "pid": pid, "tile": i}))
    sup_log = root / ("supervisor_%d-%d.log" % (numbers[0], numbers[-1]))
    sup = subprocess.Popen([sys.executable, str(HERE / "supervisor.py"), *[s["session"] for s in seats],
                            "--interval", "30", "--patience", "150"],
                           stdout=open(sup_log, "w"), stderr=subprocess.STDOUT, start_new_session=True)
    manifest = {"head": head, "seats": seats, "supervisor_pid": sup.pid, "supervisor_log": str(sup_log),
                "started_at": int(time.time())}
    path = root / ("batch_%d-%d.json" % (numbers[0], numbers[-1]))
    path.write_text(json.dumps(manifest, indent=1))
    print(json.dumps({"batch": str(path), "booted": sum(1 for s in seats if s["booted"]), "of": len(seats)}))
    return 0 if all(s["booted"] for s in seats) else 1


def stop(args):
    manifest = json.loads(Path(args.batch).read_text())
    try:
        os.killpg(manifest["supervisor_pid"], signal.SIGTERM)
    except Exception:
        pass
    for s in manifest["seats"]:
        for line in _run(["ps", "-axo", "pid,args"]).stdout.splitlines():
            if "seat.gd" in line and ("--session-dir=%s" % s["session"]) in line:
                try:
                    os.kill(int(line.split()[0]), signal.SIGTERM)
                except Exception:
                    pass
        _run(["git", "worktree", "remove", "--force", s["worktree"]], cwd=REPO)
    _run(["git", "worktree", "prune"], cwd=REPO)
    print(json.dumps({"stopped": [s["number"] for s in manifest["seats"]]}))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("start")
    s.add_argument("n", type=int)
    s.add_argument("--root", required=True)
    s.add_argument("--mission", required=True, help="a mission text naming one stranger-<n> session path to substitute")
    s.add_argument("--head", default="")
    s.add_argument("--seed", type=int, default=0)
    s.add_argument("--model", default="claude-haiku-4-5")
    p = sub.add_parser("stop")
    p.add_argument("--root", required=True)
    p.add_argument("--batch", required=True)
    args = parser.parse_args()
    return start(args) if args.cmd == "start" else stop(args)


if __name__ == "__main__":
    sys.exit(main())
