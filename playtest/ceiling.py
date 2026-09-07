"""The ceiling run: a scripted perfect opening on a fresh seat, timed per rung (D0456).

    python3 playtest/ceiling.py <session-dir> [--mission-note "..."]

Establishes that the route and the adapter work on this build and how fast the game itself lets the
first three rungs go: ore from the ringed block, ingots from the coal-fed forge, the drill from the rig (D0485). It is the
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
    r = subprocess.run([sys.executable, str(HERE / "command.py"), str(session), json.dumps(command), "--timeout", "120", "--note", note, "--full"],
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
    """BUILD from its door (D0485): the save holds the drill in the pack, the body by the rig. Walk east to the
    shaft's mouth (dx +7 of the spawn), press the drill's slot key and BUILD on the mouth's lower open cell.
    Read from the receipts: the rung past BUILD."""
    resp = burst(session, {"ticks": 5}, "ceiling r4: look")
    body_cell = (resp.get("state") or {}).get("cell") or [136, 75]
    while body_cell[0] < 154:                                                 # dx +6: the mouth's column in reach
        resp = burst(session, {"ticks": max(2, min(20, int((154 - body_cell[0]) * 1.5))), "keys": ["D"]}, "ceiling r4: walk toward the shaft")
        body_cell = (resp.get("state") or {}).get("cell") or body_cell
    slots = list((resp.get("state") or {}).get("slots") or [])
    burst(session, {"ticks": 3, "keys": [str(slots.index("drill") + 1) if "drill" in slots else "1"]}, "ceiling r4: select the drill")
    px_per_cell = PX_PER_M / 4.0

    def place(i):
        mouth = [BODY_X + (157.5 - (body_cell[0] + 0.5)) * px_per_cell, FEET_Y + (85.5 - 79.5) * px_per_cell + i * 4]
        resp = burst(session, {"ticks": 10, "mouse": mouth, "buttons": [2]}, "ceiling r4: BUILD on the shaft's mouth")
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
    parser.add_argument("--save-after", default="drill", choices=["ore", "drill"], help="which rung --save-to follows: 'ore' writes the rung-2 variant (the forge rung's door, D0479) and stops there; 'drill' (default) writes BUILD's door")
    parser.add_argument("--rung4", default="", help="open this BUILD-door save (the drill in hand) and play the fourth rung only: the drill placed at the shaft's mouth (D0467, D0485)")
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
    # Rung 2 (D0483): the forge takes ore AND coal. The seam is five metres right of the spawn: walk to it,
    # hold MINE on it, come back beside the forge (dx -3; beside means within a body length) and drop each
    # stack by its slot key, then stand there while the ingots come.
    resp = burst(session, {"ticks": 18, "keys": ["D"]}, "ceiling: walk to the coal seam")
    body_cell = (resp.get("state") or {}).get("cell") or [130, 75]
    seam = [BODY_X + (150.5 - (body_cell[0] + 0.5)) * PX_PER_M / 4.0, FEET_Y + 0.3 * PX_PER_M]

    def mine_coal(i):
        resp = burst(session, {"ticks": 120, "mouse": seam, "buttons": [1], "until": "event"}, "ceiling: hold MINE on the coal seam")
        return resp, pack(resp, "coal") >= 4
    results["coal"] = rung(session, "coal", 6, mine_coal)
    if results["coal"] is None:
        return 1
    resp = burst(session, {"ticks": 30, "keys": ["A"]}, "ceiling: back to the forge")
    body_cell = (resp.get("state") or {}).get("cell") or body_cell
    while body_cell[0] > 124:
        resp = burst(session, {"ticks": 2, "keys": ["A"]}, "ceiling: a nudge beside the forge")
        body_cell = (resp.get("state") or {}).get("cell") or body_cell
    slots = list((resp.get("state") or {}).get("slots") or [])          # the bar's order: slot N is key N
    for item in ("ore", "coal"):
        key = str(slots.index(item) + 1) if item in slots else "1"
        burst(session, {"ticks": 3, "keys": [key]}, "ceiling: select the %s" % item)
        burst(session, {"ticks": 3, "keys": ["Q"]}, "ceiling: drop the %s into the forge" % item)

    def smelt(i):
        resp = burst(session, {"ticks": 90, "until": "event"}, "ceiling: wait beside the forge")
        return resp, pack(resp, "ingot") >= 2
    results["ingots"] = rung(session, "ingots", 8, smelt)
    if results["ingots"] is None:
        return 1
    # Rung 3 (D0485): the delivery. The rig stands two metres right of the spawn; beside it, select the
    # ingots and drop; the rig pays the drill into the well under it and the walk-over collect takes it.
    resp = burst(session, {"ticks": 12, "keys": ["D"]}, "ceiling: walk to the rig")
    body_cell = (resp.get("state") or {}).get("cell") or body_cell
    while body_cell[0] < 136:
        resp = burst(session, {"ticks": 2, "keys": ["D"]}, "ceiling: a nudge beside the rig")
        body_cell = (resp.get("state") or {}).get("cell") or body_cell
    slots = list((resp.get("state") or {}).get("slots") or [])
    burst(session, {"ticks": 3, "keys": [str(slots.index("ingot") + 1) if "ingot" in slots else "1"]}, "ceiling: select the ingots")

    def deliver(i):
        if i == 0:
            resp = burst(session, {"ticks": 3, "keys": ["Q"]}, "ceiling: drop the ingots into the rig")
        else:
            resp = burst(session, {"ticks": 60, "until": "event"}, "ceiling: wait by the rig for the drill")
        return resp, pack(resp, "drill") >= 1
    results["drill"] = rung(session, "drill", 6, deliver)
    if args.save_to and results["drill"] is not None:
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
