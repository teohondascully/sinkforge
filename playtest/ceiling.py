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


def rung4(session, hold):
    """The fourth rung from the rung-4 save, by the same physical bursts a stranger sends (D0467): walk to the
    WHITE SQUARE's column (dx +4 of the spawn), bite the roof metre four times (its centre, its bottom row,
    then the two rim columns the body's edges rest on), drop into the adit onto the drill, press the
    drill's slot, step toward the ring at the shaft's mouth and press BUILD on it. Read from the receipts:
    the drill in the pack, then the rung past BUILD."""
    resp = burst(session, {"ticks": 5}, "ceiling r4: look")
    body_cell = (resp.get("state") or {}).get("cell") or [117, 75]
    square_cell_x = 130 + 4 * 4 + 1                                  # the roof metre's second column, dx +4 of the spawn
    px_per_cell = PX_PER_M / 4.0
    ticks = max(1, int(round((square_cell_x - body_cell[0]) * 1.5)))  # a burst of D moves ~0.6 cell a tick
    resp = burst(session, {"ticks": ticks, "keys": ["D"]}, "ceiling r4: walk to the square")
    body_cell = (resp.get("state") or {}).get("cell") or body_cell
    while body_cell[0] < square_cell_x:
        resp = burst(session, {"ticks": 2, "keys": ["D"]}, "ceiling r4: a nudge onto the metre")
        body_cell = (resp.get("state") or {}).get("cell") or body_cell
    bites = [([BODY_X, FEET_Y + 2.4 * px_per_cell], "the centre"), ([BODY_X, FEET_Y + 2.7 * px_per_cell], "the bottom row"),
             ([BODY_X - 2.5 * px_per_cell, FEET_Y + 1.6 * px_per_cell], "the left rim"), ([BODY_X + 2.5 * px_per_cell, FEET_Y + 1.6 * px_per_cell], "the right rim")]

    def drill_pickup(i):
        at, name = bites[min(i, len(bites) - 1)]
        resp = burst(session, {"ticks": 120, "mouse": at, "buttons": [1]}, "ceiling r4: bite %s" % name)
        return resp, pack(resp, "drill") >= 1
    got = rung(session, "drill_in_hand", 6, drill_pickup)
    if got is None:
        return 1
    slots = list((got.get("state") or {}).get("slots") or [])              # the bar's order, not the sorted pack
    burst(session, {"ticks": 3, "keys": [str(slots.index("drill") + 1)]}, "ceiling r4: select the drill")
    burst(session, {"ticks": 8, "keys": ["D"]}, "ceiling r4: a step toward the ring")

    def place(i):
        resp = burst(session, {"ticks": 10, "mouse": [BODY_X + (2.2 - 0.4 * i) * PX_PER_M, FEET_Y + 0.6 * PX_PER_M], "buttons": [2]}, "ceiling r4: BUILD on the ring")
        return resp, (resp.get("state") or {}).get("rung") not in (None, "", "build")
    placed = rung(session, "drill_placed", 5, place)
    if not hold:
        burst(session, {"quit": True}, "ceiling r4: done")
    print(json.dumps({"ceiling_rung4": placed is not None, "sim_seconds": (placed or {}).get("sim_seconds")}))
    return 0 if placed is not None else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("session_dir")
    parser.add_argument("--hold", action="store_true", help="leave the seat up at the end (for a look at the BUILD rung)")
    parser.add_argument("--save-to", default="", help="after the third rung, write the session here: the rung-4 mission variant's save (D0462)")
    parser.add_argument("--save-after", default="wood", choices=["ore", "wood"], help="which rung --save-to follows: 'ore' writes the rung-2 variant (the forge rung's door, D0479) and stops there")
    parser.add_argument("--rung4", default="", help="open this rung-4 save and play the fourth rung only: the drill placed at the shaft's mouth (D0467)")
    args = parser.parse_args()
    session = Path(args.session_dir).resolve()
    start = [sys.executable, str(HERE / "stranger.py"), "start", str(session), "--mission", str(Path(__file__).resolve()), "--model", "script:ceiling"]
    if args.rung4:
        start += ["--load", args.rung4]
    rc = subprocess.run(start).returncode
    if rc != 0:
        print("ceiling: the seat did not come up foreground (rc %d)" % rc, file=sys.stderr)
        return 2
    if args.rung4:
        return rung4(session, args.hold)
    results = {}
    # Rung 1: the ringed block, a metre left of the boot, at the surface.
    ring = [BODY_X - 1.1 * PX_PER_M, FEET_Y + 0.3 * PX_PER_M]

    def mine_ore(i):
        resp = burst(session, {"ticks": 120, "mouse": ring, "buttons": [1], "until": "event"}, "ceiling: hold MINE on the ringed block")
        return resp, pack(resp, "ore") >= 4
    results["ore"] = rung(session, "ore", 6, mine_ore)
    if results["ore"] is None:
        return 1
    if args.save_to and args.save_after == "ore":
        # The rung-2 variant (D0479): the ore in the pack, the body on the pad where every fresh-game stranger
        # stood when the smelt card came up, the forge ringed three metres left. Saved and done.
        r = burst(session, {"save": str(Path(args.save_to).resolve())}, "ceiling: the rung-2 save")
        print(json.dumps({"saved": r.get("saved"), "path": r.get("path"), "tick": r.get("tick"), "pack": (results["ore"].get("state") or {}).get("pack")}))
        if not args.hold:
            burst(session, {"quit": True}, "ceiling: done at the smelt rung's door")
        return 0 if r.get("saved") else 1
    # Rung 2: select the ore's slot, walk left to stand beside the forge (dx -3; beside means within a
    # body length: dx -1.5), drop, and stand there while the ingots come.
    slots = list((results["ore"].get("state") or {}).get("slots") or [])   # the bar's order: slot N is key N
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
