#!/usr/bin/env python3
"""Mutation tests for check_content_reachable.py (D0591).

    python3 tools/layer_lint/test_check_content_reachable.py

Five cases, and three of them exist because the gate would look healthy without them:

  * AND-SEMANTICS. A recipe is reachable only when ALL its inputs are. Plain graph search declares it
    reachable on one, and a gate that did so would have passed the very tree that motivated it.
  * THE SEEDED CYCLE. A production loop that feeds itself is DESIRABLE and must pass; the same loop with
    no way in must fail. A topological sort rejects both, which is the likeliest silent mis-write here.
  * THE PARTITION IS LOAD-BEARING. If moving a machine from a dev fixture into the shipped start does not
    change the verdict, the fixture exclusion is decorative and the shipped-progression proof is
    unfalsified. This is the case that would have caught `torch` being counted as reachable because a
    LIGHTING BENCH places it -- a hand count made exactly that error, and "corrected" seven orphans to
    six on the strength of it.

Runs the real script against scratch trees via `--root`, never against `data/`: a test that edited the
repository's own records and crashed would leave the tree broken.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "check_content_reachable.py"
RESULTS: list[tuple[str, bool]] = []

MAIN_GD = 'const START: StringName = &"tutorial"\n'


def build(root: Path, materials, recipes, machines, starts, tiers, main_gd=MAIN_GD) -> None:
    (root / "shell").mkdir(parents=True, exist_ok=True)
    (root / "shell" / "main.gd").write_text(main_gd, encoding="utf-8")
    for kind, records in (("materials", materials), ("recipes", recipes), ("machines", machines),
                          ("starts", starts), ("progression", tiers)):
        folder = root / "data" / kind
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "SCHEMA.yaml").write_text("fields: {}\n", encoding="utf-8")
        for text in records:
            ident = [ln for ln in text.splitlines() if ln.startswith("id:")][0].split(":", 1)[1].strip()
            (folder / f"{ident}.yaml").write_text(text, encoding="utf-8")


def run(root: Path) -> tuple[int, str]:
    done = subprocess.run([sys.executable, str(SCRIPT), "--root", str(root)],
                          capture_output=True, text=True)
    return done.returncode, done.stdout + done.stderr


def case(label: str, ok: bool, detail: str = "") -> None:
    RESULTS.append((label, ok))
    print(f"  {'PASS' if ok else 'FAIL'}: {label}{(' -- ' + detail) if not ok and detail else ''}")


# A complete, reachable little economy: mine ore by hand, smelt it on a placed forge, deliver for a drill.
ORE = "id: ore_iron\nyields: ore\n"
COAL = "id: coal\n"
SMELT = "id: smelt_ingot\ninputs: {ore: 2, coal: 1}\noutputs: {ingot: 1}\n"
PROCESSOR = "id: processor\nrecipe: smelt_ingot\n"
DRILL = "id: drill\nrecipe: mine_ore\n"
MINE = "id: mine_ore\ninputs: {}\noutputs: {ore: 1}\n"
TUTORIAL = "id: tutorial\nfixtures:\n  - {kind: machine, id: processor, dx: 0, dy: 0}\n"
D1 = "id: d1\norder: 1\nwants: {ingot: 2}\ngrants: {drill: 1}\n"


def main() -> int:
    print("test_check_content_reachable: the gate's own guards, run as mutations")

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build(root, [ORE, COAL], [SMELT, MINE], [PROCESSOR, DRILL], [TUTORIAL], [D1])
        code, out = run(root)
        case("a complete economy passes (the control: without this every FAIL below is meaningless)",
             code == 0, out)

    # AND-semantics: one input present, the other not. Plain graph search would call this reachable.
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build(root, [ORE], [SMELT, MINE], [PROCESSOR, DRILL], [TUTORIAL], [D1])
        code, out = run(root)
        case("a recipe with ONE of two inputs is unreachable, not reachable",
             code == 1 and "smelt_ingot" in out and "coal" in out, out)

    # A self-feeding loop with a way in must PASS...
    seed = "id: seedstone\nyields: seed\n"
    a = "id: r_a\ninputs: {seed: 1}\noutputs: {alpha: 1}\n"
    loop1 = "id: r_loop1\ninputs: {alpha: 1}\noutputs: {beta: 1}\n"
    loop2 = "id: r_loop2\ninputs: {beta: 1}\noutputs: {alpha: 2}\n"
    mach = "id: mill\nrecipe: r_a\n"
    mach1 = "id: mill1\nrecipe: r_loop1\n"
    mach2 = "id: mill2\nrecipe: r_loop2\n"
    start_all = ("id: tutorial\nfixtures:\n"
                 "  - {kind: machine, id: mill, dx: 0, dy: 0}\n"
                 "  - {kind: machine, id: mill1, dx: 1, dy: 0}\n"
                 "  - {kind: machine, id: mill2, dx: 2, dy: 0}\n")
    tier = "id: d1\norder: 1\nwants: {beta: 1}\ngrants: {}\n"
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build(root, [seed], [a, loop1, loop2], [mach, mach1, mach2], [start_all], [tier])
        code, out = run(root)
        case("a self-feeding production loop WITH a seed passes (a topo sort would reject it)",
             code == 0, out)

    # ...and the same loop with no way in must FAIL.
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build(root, [seed], [loop1, loop2], [mach1, mach2], [start_all], [tier])
        code, out = run(root)
        case("the same loop with NO seed fails (a topo sort would reject this one too, for the wrong reason)",
             code == 1 and "r_loop1" in out and "r_loop2" in out, out)

    # THE PARTITION. `bench` places the forge; the shipped start does not. Same records, two verdicts.
    bench = "id: lighting_bench\nfixtures:\n  - {kind: machine, id: processor, dx: 0, dy: 0}\n"
    bare = "id: tutorial\nfixtures: []\n"
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build(root, [ORE, COAL], [SMELT, MINE], [PROCESSOR, DRILL], [bare, bench], [D1])
        code, out = run(root)
        blind = code == 0
        case("a machine placed only by a BENCH does not count as shipped progression",
             code == 1 and "processor" in out,
             "the gate passed on a bench's fixture -- the exclusion is decorative" if blind else out)

    # The population and partition refusals: never a vacuous pass.
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build(root, [ORE, COAL], [], [PROCESSOR], [TUTORIAL], [D1])
        code, out = run(root)
        case("no recipes at all is a broken scan, not a clean tree", code == 1 and "scan is broken" in out, out)

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        build(root, [ORE, COAL], [SMELT, MINE], [PROCESSOR, DRILL], [TUTORIAL], [D1],
              main_gd='const START: StringName = &"no_such_start"\n')
        code, out = run(root)
        case("a START naming no record refuses a verdict rather than guessing",
             code == 1 and "refusing to guess" in out, out)

    bad = [label for label, ok in RESULTS if not ok]
    print(f"test_check_content_reachable: {len(RESULTS) - len(bad)}/{len(RESULTS)} cases witnessed")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
