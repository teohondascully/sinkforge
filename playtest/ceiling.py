"""The ceiling run: a scripted perfect opening on a fresh seat, timed per rung (D0456).

    python3 playtest/ceiling.py <session-dir> [--mission-note "..."]

Establishes that the route and the adapter work on this build and how fast the game itself lets the
first three rungs go: ore from the ringed block, ingots from the forge, wood from the tree. It is the
denominator for a stranger's time and nothing more: a script that knows the layout says nothing about
what a stranger can see (the director's rule 10). The seat is pinned like a stranger's (`stranger.py
start` with this file as the mission), the inputs are the same physical bursts, and every rung is read
from the seat's receipts (the pack), never from the objective line. Prints one JSON line per rung and a
summary; exits 1 when a rung does not complete within its budget.
"""
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
PX_PER_M = 25.6                     # play zoom 1.6 over 16 px a metre
BODY_X, FEET_Y = 640, 400           # the body at rest on the spawn pad, screen pixels


def burst(session, command, note):
    r = subprocess.run([sys.executable, str(HERE / "command.py"), str(session), json.dumps(command), "--timeout", "120", "--note", note],
                       capture_output=True, text=True)
    lines = [l for l in r.stdout.strip().splitlines() if l.startswith("{")]
    if not lines:
        raise RuntimeError("no response: %s" % (r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "?"))
    return json.loads(lines[-1])


def pack(resp, item):
    return int(((resp.get("state") or {}).get("pack") or {}).get(item, 0))


def rung(session, name, budget_bursts, step):
    """Run `step(i)` bursts until it returns a response satisfying the rung, within the budget."""
    t0 = None
    for i in range(budget_bursts):
        resp, done = step(i)
        if t0 is None:
            t0 = resp.get("sim_seconds", 0.0)
        if done:
            print(json.dumps({"rung": name, "done": True, "bursts": i + 1, "sim_seconds": resp.get("sim_seconds"), "pack": (resp.get("state") or {}).get("pack")}))
            return resp
    print(json.dumps({"rung": name, "done": False, "bursts": budget_bursts}))
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("session_dir")
    parser.add_argument("--hold", action="store_true", help="leave the seat up at the end (for a look at the BUILD rung)")
    parser.add_argument("--save-to", default="", help="after the third rung, write the session here: the rung-4 mission variant's save (D0462)")
    args = parser.parse_args()
    session = Path(args.session_dir).resolve()
    rc = subprocess.run([sys.executable, str(HERE / "stranger.py"), "start", str(session), "--mission", str(Path(__file__).resolve()), "--model", "script:ceiling"]).returncode
    if rc != 0:
        print("ceiling: the seat did not come up foreground (rc %d)" % rc, file=sys.stderr)
        return 2
    results = {}
    # Rung 1: the ringed block, a metre left of the boot, at the surface.
    ring = [BODY_X - 1.1 * PX_PER_M, FEET_Y + 0.3 * PX_PER_M]

    def mine_ore(i):
        resp = burst(session, {"ticks": 120, "mouse": ring, "buttons": [1], "until": "event"}, "ceiling: hold MINE on the ringed block")
        return resp, pack(resp, "ore") >= 4
    results["ore"] = rung(session, "ore", 6, mine_ore)
    if results["ore"] is None:
        return 1
    # Rung 2: select the ore's slot, walk left to stand beside the forge (dx -3; beside means within a
    # body length: dx -1.5), drop, and stand there while the ingots come.
    slots = list(((results["ore"].get("state") or {}).get("pack") or {}).keys())
    ore_key = str(slots.index("ore") + 1) if "ore" in slots else "1"
    burst(session, {"ticks": 3, "keys": [ore_key]}, "ceiling: select the ore")
    burst(session, {"ticks": 10, "keys": ["A"]}, "ceiling: a step left, beside the forge")

    def smelt(i):
        if i == 0:
            resp = burst(session, {"ticks": 3, "keys": ["Q"]}, "ceiling: drop the ore into the forge")
            return resp, pack(resp, "ingot") >= 2
        resp = burst(session, {"ticks": 90, "until": "event"}, "ceiling: wait beside the forge")
        return resp, pack(resp, "ingot") >= 2
    results["ingots"] = rung(session, "ingots", 8, smelt)
    if results["ingots"] is None:
        return 1
    # Rung 3: the tree at dx -6 m of the spawn (a two-metre trunk above the surface, two cells wide). Walk
    # left until the body's cell is within a reach of the trunk, then aim by cell: the receipts carry the
    # body's terrain cell, and the screen is 6.4 px a cell around the body at rest.
    trunk_cell_x = 130 - 6 * 4 + 2                                # the spawn column's cell 130; the trunk's right cell
    resp = burst(session, {"ticks": 12, "keys": ["A"]}, "ceiling: walk to the tree")
    body_cell = (resp.get("state") or {}).get("cell") or [130, 75]
    while body_cell[0] - trunk_cell_x > 8:
        resp = burst(session, {"ticks": 4, "keys": ["A"]}, "ceiling: a step nearer the tree")
        body_cell = (resp.get("state") or {}).get("cell") or body_cell
    px_per_cell = PX_PER_M / 4.0
    trunk = [BODY_X + (trunk_cell_x + 0.5 - (body_cell[0] + 0.5)) * px_per_cell, FEET_Y - 3.5 * px_per_cell]

    def wood(i):
        resp = burst(session, {"ticks": 120, "mouse": trunk, "buttons": [1], "until": "event"}, "ceiling: hold MINE on the trunk")
        if pack(resp, "wood") >= 1:
            return resp, True
        if resp.get("refusal") == "air":                        # a cell off the trunk: try one cell left
            trunk[0] -= px_per_cell
        return resp, False
    results["wood"] = rung(session, "wood", 12, wood)
    if args.save_to and results["wood"] is not None:
        burst(session, {"ticks": 3, "keys": ["D"]}, "ceiling: face the pad")
        r = burst(session, {"save": str(Path(args.save_to).resolve())}, "ceiling: the rung-4 save")
        print(json.dumps({"saved": r.get("saved"), "path": r.get("path"), "tick": r.get("tick")}))
    if not args.hold:
        burst(session, {"quit": True}, "ceiling: done")
    done = {k: v is not None for k, v in results.items()}
    print(json.dumps({"ceiling": done, "sim_seconds": {k: (v or {}).get("sim_seconds") for k, v in results.items()}}))
    return 0 if all(done.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
