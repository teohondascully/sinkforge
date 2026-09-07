"""The per-burst evidence table of a stranger session, from the receipts alone (D0476).

    python3 playtest/evidence.py <session-dir>

One row a burst from `input_NNNN.json` (what the agent sent: ticks, keys, pointer, buttons, a composed
move) and `observation_NNNN.json` (what the seat saw: what ended the burst, the refusal and where it was
aimed, the raw cell under the pointer at the first held tick, the cells broken, the HUD state, the pack
and its change). The director's rule 5: inputs and screenshots are evidence, the agent's report is a
hypothesis -- this table is the evidence side, laid out so a first press, its aim, its refusal and its
cells can be quoted without opening a frame. Prints the first-ore and four-ore bursts last.
"""
import glob
import json
import os
import sys
from pathlib import Path


def _load(path):
    try:
        return json.loads(Path(path).read_text())
    except Exception:
        return None


def describe(command):
    """One line for a burst's input: `120t mouse=(545,420) btn=1`, `MOVES[...]`, `QUIT`."""
    if not command:
        return "?"
    if command.get("quit"):
        return "QUIT"
    if "moves" in command:
        return "MOVES[" + "; ".join(describe(m) for m in command["moves"]) + "]"
    parts = ["%dt" % int(command.get("ticks", 0))]
    if command.get("keys"):
        parts.append("keys=" + "+".join(command["keys"]))
    if command.get("mouse"):
        parts.append("mouse=(%d,%d)" % (command["mouse"][0], command["mouse"][1]))
    if command.get("buttons"):
        parts.append("btn=" + ",".join(str(int(b)) for b in command["buttons"]))
    if command.get("until"):
        parts.append("until=" + str(command["until"]))
    return " ".join(parts)


def rows(session):
    session = Path(session)
    inputs = {int(os.path.basename(p)[6:10]): _load(p) for p in sorted(glob.glob(str(session / "input_*.json")))}
    observations = {int(os.path.basename(p)[12:16]): _load(p) for p in sorted(glob.glob(str(session / "observation_*.json")))}
    prev_pack = {}
    out = []
    for i in sorted(set(inputs) | set(observations)):
        c = inputs.get(i) or {}
        o = observations.get(i) or {}
        state = o.get("state") or {}
        pack = state.get("pack") or {}
        gained = {k: v - prev_pack.get(k, 0) for k, v in pack.items() if v != prev_pack.get(k, 0)}
        for k in prev_pack:
            if k not in pack:
                gained[k] = -prev_pack[k]
        out.append({"id": i, "sim_seconds": o.get("sim_seconds", -1), "input": describe(c), "ended_by": o.get("ended_by") or "",
                    "refusal": o.get("refusal") or "", "refusal_at": o.get("refusal_at") or {}, "pointed": o.get("pointed") or {},
                    "broke": o.get("broke") or [], "state": state, "pack": pack, "gained": gained,
                    "still": o.get("still", True), "capture_error": o.get("capture_error", 0)})
        prev_pack = pack
    return out


def main(session):
    table = rows(session)
    first_ore = four_ore = None
    print("id   sim_s  input                                   | ended_by  refusal@aim/body           pointed raw>aim         broke | rung     prog  lesson        cell        pack")
    for r in table:
        ore = int(r["pack"].get("ore", 0))
        if first_ore is None and ore >= 1:
            first_ore = (r["id"], r["sim_seconds"])
        if four_ore is None and ore >= 4:
            four_ore = (r["id"], r["sim_seconds"])
        ra = r["refusal_at"]
        refusal = ("%s@%s/%s" % (r["refusal"], ra.get("aim"), ra.get("body"))) if r["refusal"] else ""
        p = r["pointed"]
        pointed = ("%s>%s" % (p.get("raw"), p.get("aim"))) if p else ""
        flags = ("" if r["still"] else " NOT-STILL") + (" CAPERR" if r["capture_error"] else "")
        st = r["state"]
        print("%-4d %6.1f %-40s| %-9s %-26s %-23s %-5s | %-8s %-5s %-13s %-11s %s%s%s" % (
            r["id"], r["sim_seconds"], r["input"][:40], r["ended_by"][:9], refusal[:26], pointed[:23], len(r["broke"]) or "",
            st.get("rung", ""), st.get("progress", ""), st.get("lesson", "")[:13], st.get("cell", ""),
            json.dumps(r["pack"], separators=(",", ":")), (" +" + json.dumps(r["gained"], separators=(",", ":"))) if r["gained"] else "", flags))
        if r["broke"] and len(r["broke"]) <= 24:
            print("        broke: " + " ".join("(%d,%d)" % (b[0], b[1]) for b in r["broke"]))
    print("first ore:", first_ore, " four ore:", four_ore, " bursts:", len(table))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1]))
