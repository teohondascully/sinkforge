"""One command for a stranger batch: N seats, each running from its OWN copy of the game at the pinned head
with the import cache beside it, tiled across the screen, in FRESH session directories, the supervisor over
them (D0501, D0503).

    python3 playtest/batch.py start N --root <dir> --mission <template> [--seed S] [--model M]
    python3 playtest/batch.py stop --root <dir> --batch <root>/batch_NN-MM.json

`start` refuses a dirty checkout (the copies are of the working tree, so the tree must BE the head), allocates
stranger numbers past the highest `stranger-<n>` under --root (a session directory is never reused: a seat
refuses one, and the supervisor reads a stale pid as death -- batch 82-87 was void for exactly that), writes
one mission per seat from the template, makes each seat a COPY of the game's runtime directories only
(`RUNTIME`, about 3 MB: never docs, history, legacy, recordings) by APFS clonefile, which costs no space
until a file is written and a seat never writes its tree, plus `.godot/` the same way, boots every seat AT
ONCE from its copy's seat.sh with TILE=i,N, checks each seat's OWN seat.out for the boot line (never
`batch.json`, which a first boot wrote), starts the supervisor, and writes the batch manifest. `stop` kills
the batch's seats and supervisor and deletes its copies; session directories stay. Git worktrees were the
first cut (D0501): 589 MB each, most of it docs and history a seat never reads.
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


RUNTIME = ["project.godot", "core", "sim", "view", "shell", "interface", "data", "playtest", "assets", ".godot"]


def _copy_game(root, number):
    """A copy of the game's runtime tree for one seat, by APFS clonefile (cp -c): seconds and no space."""
    path = root / ("seat-%d" % number)
    if path.exists():
        raise SystemExit("batch: %s exists; a seat's copy is never reused" % path)
    path.mkdir()
    for entry in RUNTIME:
        src = REPO / entry
        if not src.exists():
            continue
        r = _run(["cp", "-Rc", str(src), str(path / entry)])
        if r.returncode != 0:
            r = _run(["cp", "-R", str(src), str(path / entry)])
            if r.returncode != 0:
                raise SystemExit("batch: copying %s failed: %s" % (entry, r.stderr.strip()))
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
    if _run(["git", "status", "--porcelain"], cwd=REPO).stdout.strip():
        raise SystemExit("batch: the checkout is dirty; a batch copies the working tree, so commit or stash first")
    head = _run(["git", "rev-parse", "HEAD"], cwd=REPO).stdout.strip()
    numbers = _next_numbers(root, args.n)
    seats = []
    procs = []
    for i, number in enumerate(numbers):
        session = root / ("stranger-%d" % number)
        if session.exists():
            raise SystemExit("batch: %s exists" % session)
        session.mkdir()
        mission = root / ("mission_%d.txt" % number)
        mission.write_text(_mission(args.mission, session, number))
        tree = _copy_game(root, number)
        env = dict(os.environ, TILE="%d,%d" % (i, args.n))
        cmd = [sys.executable, str(HERE / "stranger.py"), "start", str(session), "--mission", str(mission),
               "--model", args.model, "--seat", str(tree / "playtest" / "seat.sh")]
        if args.seed:
            cmd += ["--seed", str(args.seed)]
        procs.append(subprocess.Popen(cmd, env=env, stdout=open(root / ("start_%d.log" % number), "w"), stderr=subprocess.STDOUT))
        seats.append({"number": number, "session": str(session), "mission": str(mission), "copy": str(tree), "tile": i})
    t0 = time.time()
    for s, p in zip(seats, procs):
        rc = p.wait()
        session = Path(s["session"])
        out = (session / "seat.out").read_text() if (session / "seat.out").exists() else ""
        s["booted"] = "SINKFORGE_BOOT" in out and "session already used" not in out and rc == 0
        s["start_rc"] = rc
        try:
            s["pid"] = json.loads((session / "receipt.json").read_text()).get("pid")
        except Exception:
            s["pid"] = None
        print(json.dumps({"seat": s["number"], "booted": s["booted"], "pid": s["pid"], "tile": s["tile"]}))
    boot_s = round(time.time() - t0, 1)
    sup_log = root / ("supervisor_%d-%d.log" % (numbers[0], numbers[-1]))
    sup = subprocess.Popen([sys.executable, str(HERE / "supervisor.py"), *[s["session"] for s in seats],
                            "--interval", "30", "--patience", "150"],
                           stdout=open(sup_log, "w"), stderr=subprocess.STDOUT, start_new_session=True)
    manifest = {"head": head, "seats": seats, "supervisor_pid": sup.pid, "supervisor_log": str(sup_log),
                "started_at": int(time.time()), "boot_wall_s": boot_s}
    path = root / ("batch_%d-%d.json" % (numbers[0], numbers[-1]))
    path.write_text(json.dumps(manifest, indent=1))
    print(json.dumps({"batch": str(path), "booted": sum(1 for s in seats if s["booted"]), "of": len(seats), "boot_wall_s": boot_s}))
    return 0 if all(s["booted"] for s in seats) else 1


def stop(args):
    manifest = json.loads(Path(args.batch).read_text())
    try:
        os.killpg(manifest["supervisor_pid"], signal.SIGTERM)
    except Exception:
        pass
    root = Path(args.root).resolve()
    for s in manifest["seats"]:
        for line in _run(["ps", "-axo", "pid,args"]).stdout.splitlines():
            if "seat.gd" in line and ("--session-dir=%s" % s["session"]) in line:
                try:
                    os.kill(int(line.split()[0]), signal.SIGTERM)
                except Exception:
                    pass
        tree = Path(s.get("copy") or s.get("worktree") or "")
        if s.get("worktree"):
            _run(["git", "worktree", "remove", "--force", str(tree)], cwd=REPO)
        elif tree.is_dir() and tree.parent == root and tree.name.startswith("seat-"):
            shutil.rmtree(tree)          # the batch's own copy under its root, nothing else
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
    s.add_argument("--seed", type=int, default=0)
    s.add_argument("--model", default="claude-haiku-4-5")
    p = sub.add_parser("stop")
    p.add_argument("--root", required=True)
    p.add_argument("--batch", required=True)
    args = parser.parse_args()
    return start(args) if args.cmd == "start" else stop(args)


if __name__ == "__main__":
    sys.exit(main())
