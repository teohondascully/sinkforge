#!/usr/bin/env python3
"""The repeatable frame-cost fixture: named workloads, warm and cold windows, and a host-speed control.

    python3 tools/perf_fixture.py --workload dig --reps 3 --label after
    python3 tools/perf_fixture.py --all --reps 2 --out /tmp/run.json
    python3 tools/perf_fixture.py --compare before.json after.json

## Why this exists

`docs/PERF_PLAN.md`'s first remaining-work item, and the reason it is first: three sets of frame numbers
were voided on 2026-09-07 and 2026-09-08 for want of it.

* One pair of runs was paced. `fps_wall` read 119.8-120.0 with `--disable-vsync` set, so half the frames
  measured as one refresh interval and `over8.3ms` counted nearly all of them (D0527). A paced window and
  an unpaced window are not comparable and no field but `fps_wall` says which you have.
* One pair was contended. The host ran the main thread about three times slower, intermittently, and
  every painter, every HUD chip and the sim-side `observe` slowed by the SAME factor in the same frames
  (D0527). Nothing in the game changed.
* One was both, and the verdict inverted between repetitions.

So this runner refuses. It reads the frame meter's own fixed-work calibration loop -- no allocation, no
draw call, a property of the core and nothing else -- out of every window, and when that control moves
across the windows being compared it prints VOID and no ranking. A number that survives is a number whose
control held still. `[[control-inside-the-measurement]]`, `[[name-the-frame]]`.

## What it will not do

It will not average the cold window into the warm ones. Window 1 carries the shader compiles and the
first full bake, which are real costs and a different question; they are reported on their own line.
It will not claim a frames-per-second improvement from a per-region or per-painter measurement, and it
will not compare two runs whose paced/unpaced state differs.
"""
import argparse
import json
import pathlib
import re
import statistics
import subprocess
import sys
import threading

ROOT = pathlib.Path(__file__).resolve().parent.parent
GODOT = "/opt/homebrew/bin/godot"
WORKLOADS = ("still", "walk", "dig", "fall")
# Ticks a window covers, matching `SeatDrive.meter_tick`'s own divisor. One source; if that changes and
# this does not, `drawn=.../tick` would still be right and every per-tick figure here would be wrong.
WINDOW_TICKS = 300
# The control's allowed drift across the windows being compared, as a ratio of the slowest window's
# median to the fastest. Two thresholds, because a flat refusal threw away usable descriptions: past
# SUSPECT the numbers are printed with the drift stated, so a reader can see how much of any difference
# the host could account for; past VOID they are not printed at all. Only a plain VALID may be compared
# against another run -- `compare()` enforces that, which is where a wrong verdict would actually cost
# something. Measured drift on this host: 1.02-1.10 inside a busy workload, 1.30 across a mostly idle one
# (the core drops its clock when the game gives it nothing to do, and the control feels that too).
CAL_DRIFT_SUSPECT = 1.20
CAL_DRIFT_MAX = 1.50
# `fps_wall` inside this band means the display paced the process at 120 Hz whatever the vsync flag said.
PACED_BAND = (117.0, 123.0)

WINDOW_RE = re.compile(r"^WINDOW tick=(\d+) workload=(\w+) body=\((-?\d+),(-?\d+)\)")
PERF_RE = re.compile(
    r"^PERF frames=(\d+) fps_wall=([\d.]+) frame p50=([\d.]+)ms p99=([\d.]+)ms max=([\d.]+)ms "
    r"over8\.3ms=(\d+) over16\.7ms=(\d+) focus=([\d.]+) \| draw p50=([\d.]+)ms p99=([\d.]+)ms.*?"
    r"quiet p50=([\d.]+)ms p99=([\d.]+)ms n=\d+ \| "
    r"cal p50=(\d+)us p99=(\d+)us max=(\d+)us spread=([\d.]+) n=(\d+)")
PAINT_RE = re.compile(r"^painters total=([\d.]+)ms.*?drawn=([\d.]+)ms/tick")
BAKE_RE = re.compile(
    r"^bake prep=([\d.]+)ms/tick chunks=(\d+) cells=(\d+) ([\d.]+)us/cell \| "
    r"upload=([\d.]+)ms/tick n=(\d+) cells=(\d+) ([\d.]+)us/cell")


def flags_for(workload, ticks, zoom, extra=()):
    """The seat's argv for one workload. Always `--perf-drive=`, never bare `--perf`: only a driven seat
    is deaf to the real keyboard, and a measurement a passer-by can change is not a measurement."""
    seat = ["--fresh", "--muted", "--zoom=%s" % zoom, "--quit-after=%d" % ticks,
            "--perf-drive=%s" % workload]
    return ["--resolution", "1280x720", "--disable-vsync", "--max-fps", "0",
            "--path", str(ROOT), "--", "--unfocused"] + seat + list(extra)


# THE SEAT RENDERS FOR REAL, ALWAYS. Hiding the process was tried and rejected by the director: macOS
# stops presenting a hidden window, the draw phase falls from 4.40 ms to 0.50, and presentation is not
# overhead to be dodged -- it is the telemetry. `--hidden` survives only as a way to isolate CPU phases
# from presentation deliberately, and it withholds every frame number when used.
#
# What is left is the focus itself, which is a real cost to whoever owns the machine and was a real cost
# to these measurements: `PlayInput.verbs` read the physical keyboard even on a scripted seat, so a
# keystroke typed into what looked like the director's own window could select a hotbar well and change
# what MINE snaps to. The seat is deaf now (D0535) and `--unfocused` refuses keyboard focus from the
# first frame of `_ready`, but macOS activates the process anyway a few seconds in, once it starts
# presenting. So the runner keeps a custodian: every couple of seconds it asks which process is
# frontmost, and if it is THIS seat -- by unix id, never by name, since the director may have their own
# game open -- it hands the front back to whatever was there before the run started. It never takes
# focus from anything except the seat it launched.
HIDE_AFTER_S = 2.0
CUSTODY_EVERY_S = 2.0
FRONT_NAME = 'tell application "System Events" to get name of first application process whose frontmost is true'
FRONT_PID = 'tell application "System Events" to get unix id of first application process whose frontmost is true'
HIDE_SCRIPT = ('tell application "System Events" to set visible of '
               '(first process whose unix id is %d) to false')
RAISE_SCRIPT = 'tell application "System Events" to set frontmost of process "%s" to true'


def _osa(script):
    r = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


def _hide(pid):
    _osa(HIDE_SCRIPT % pid)


def _keep_custody(pid, restore_to, done):
    """Give the front back to `restore_to` whenever this seat has taken it, until `done` is set."""
    while not done.wait(CUSTODY_EVERY_S):
        if _osa(FRONT_PID) == str(pid) and restore_to:
            _osa(RAISE_SCRIPT % restore_to)


def run_once(workload, ticks, zoom, godot, hide=False, front=False, extra=()):
    """One seat run, returning its windows in order. Window 1 is the cold one, by construction."""
    was_front = _osa(FRONT_NAME)
    proc = subprocess.Popen([godot] + flags_for(workload, ticks, zoom, extra),
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, cwd=str(ROOT))
    done = threading.Event()
    timer = None
    if hide:
        timer = threading.Timer(HIDE_AFTER_S, _hide, args=(proc.pid,))
        timer.start()
    elif not front:
        custodian = threading.Thread(target=_keep_custody, args=(proc.pid, was_front, done), daemon=True)
        custodian.start()
    try:
        out, _ = proc.communicate(timeout=max(60, ticks / 60 * 10))
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.communicate()
        raise RuntimeError("VOID: seat exceeded its wall-time limit") from None
    finally:
        done.set()
        if timer is not None:
            timer.cancel()
    windows = parse_windows(out)
    validate_run(windows, out, proc.returncode, workload, ticks)
    return windows


def validate_run(windows, output, returncode, workload, ticks):
    """Require a complete, successful process, not merely enough surviving samples to average."""
    if returncode != 0 or re.search(r"(?:SCRIPT ERROR:|^ERROR:)", output, re.MULTILINE):
        raise RuntimeError("VOID: seat failed (exit %d)\n%s" % (returncode, output[-4000:]))
    expected = list(range(WINDOW_TICKS, ticks + 1, WINDOW_TICKS))
    if [w["tick"] for w in windows] != expected:
        raise RuntimeError("VOID: missing, duplicate or out-of-order window reports")
    required = {"drawn_per_tick", "prep_ms", "upload_ms", "cal_p50"}
    if any(w["workload"] != workload or not required.issubset(w) for w in windows):
        raise RuntimeError("VOID: mismatched workload or incomplete phase report")


def parse_windows(out):
    """The seat's window reports, in order, dropping any window that carried no PERF line."""
    windows, cur = [], None
    for line in out.splitlines():
        m = WINDOW_RE.match(line)
        if m:
            cur = {"tick": int(m.group(1)), "workload": m.group(2),
                   "body": (int(m.group(3)), int(m.group(4)))}
            windows.append(cur)
            continue
        if cur is None:
            continue
        if line.startswith("BURST "):
            cur["burst"] = json.loads(line[6:])
            continue
        m = PERF_RE.match(line)
        if m:
            cur.update(zip(("frames", "fps_wall", "p50", "p99", "max", "over8", "over16",
                            "focus", "draw_p50", "draw_p99", "quiet_p50", "quiet_p99", "cal_p50", "cal_p99",
                            "cal_max", "cal_spread", "cal_n"), (float(g) for g in m.groups())))
            continue
        m = PAINT_RE.match(line)
        if m:
            cur["painters_last"], cur["drawn_per_tick"] = float(m.group(1)), float(m.group(2))
            continue
        m = BAKE_RE.match(line)
        if m:
            cur.update(zip(("prep_ms", "prep_chunks", "prep_cells", "prep_us_cell",
                            "upload_ms", "uploads", "upload_cells", "upload_us_cell"),
                           (float(g) for g in m.groups())))
            peak = re.search(r"peak_tick cells=(\d+) prep=([\d.]+)ms", line)
            if peak:
                cur["peak_cells"], cur["peak_prep_ms"] = map(float, peak.groups())
    return [w for w in windows if "fps_wall" in w]


def gather(workload, reps, ticks, zoom, godot, hide=False, front=False, extra=()):
    runs = []
    for i in range(reps):
        w = run_once(workload, ticks, zoom, godot, hide, front, extra)
        print("  rep %d/%d: %d windows" % (i + 1, reps, len(w)), file=sys.stderr)
        if not w:
            print("  rep %d produced NO windows -- the seat did not reach tick %d" % (i + 1, ticks),
                  file=sys.stderr)
        runs.append(w)
    return runs


def verdict(workload, warm):
    """VALID, or the reason these windows may not be ranked. Checked before any number is read.

    This is the PHASE verdict and it deliberately says nothing about pacing. A paced window's frame
    spacing was set by the display, but its CPU phase clocks -- preparation, upload, painter draw --
    were not: they are timers inside the frame and they measure the same work either way. Ruling out a
    paced window's bake cost would throw away good measurements of exactly the thing the five passes
    move. `frame_note` below is where pacing disqualifies what it actually reaches.
    """
    if len(warm) < 2:
        return "VOID: %d warm window(s); a single window has no spread and cannot carry a control" % len(warm)
    # THE FIXTURE MUST HAVE DONE THE WORK IT IS NAMED FOR, inside the timed window -- `docs/PERF_PLAN.md`
    # rule 10, learned by legacy when "a phase that mined nothing reported 9.36 ms against an honest
    # 33.37" and the broken fixture looked like a 3.5x win. Here it arrived as `bake prep=0.000ms/tick
    # chunks=0` for four consecutive windows while the runner would happily have averaged them in.
    idle = [w for w in warm if w.get("prep_chunks", 0) == 0]
    if workload in ("dig", "fall") and idle:
        return ("VOID: %d of %d warm windows baked NO chunks. The %s workload did not do its own work; "
                "these frames are a standstill wearing its name." % (len(idle), len(warm), workload))
    # AND THE BODY ITSELF. `walk` cannot be checked by the bake -- this world is too narrow to stream
    # horizontally -- so it is checked by the only thing it claims: that the camera kept moving. `still`
    # is checked by its opposite. Both catch the same class of failure the bake check caught twice.
    places = {w["body"] for w in warm if "body" in w}
    if workload == "walk" and len(places) < 2:
        return "VOID: the walk ended at one place, %s, in every warm window; the camera was not moving" % places
    if workload == "still" and len(places) > 1:
        return "VOID: the still workload moved: %s. Something pressed a key that was not the script" % sorted(places)
    cals = [w["cal_p50"] for w in warm]
    lo, hi = min(cals), max(cals)
    if lo <= 0:
        return "VOID: the host-speed control read zero; the loop was not sampled"
    if hi / lo > CAL_DRIFT_MAX:
        return ("VOID: the host-speed control moved %.2fx across the warm windows (%.0f-%.0f us, "
                "limit %.2fx). The host changed speed during the run; nothing here is about the game."
                % (hi / lo, lo, hi, CAL_DRIFT_MAX))
    if hi / lo > CAL_DRIFT_SUSPECT:
        return ("SUSPECT: the host-speed control moved %.2fx across the warm windows (%.0f-%.0f us). "
                "Read the numbers below as descriptions, not as a comparison: up to %.0f%% of any "
                "difference could be the host." % (hi / lo, lo, hi, (hi / lo - 1.0) * 100.0))
    return "VALID"


HIDDEN_FRAMES = ("WITHHELD: the window was hidden, so macOS stopped presenting it and the draw phase no "
                 "longer carries presentation. Re-run with --visible for a frame-rate number.")


# A frame number belongs to a window regime, not to the game alone. Below this share of focused frames
# the compositor was not presenting the window the way a player's would be presented, and the frame and
# draw numbers describe macOS's economy rather than ours -- measured across three runs of one workload
# with the CPU control steady: draw p50 4.40 ms focused, 0.55 ms while the fixture kept handing the front
# back to the director, 1.31 ms occluded behind a terminal.
FOCUS_MIN = 0.95

# THE RUN-TO-RUN NOISE FLOOR OF EACH METRIC, as a ratio, measured rather than assumed. Three `--front`
# runs of the `dig` workload on 2026-09-08 -- one before the minimap fix, two after, the two after
# differing by a change worth 0.7% of painter CPU -- reported `fps_wall` 381.4, 533.1 and 409.8 with the
# host-speed control at 61, 60 and 61 us and painter CPU at 2.372, 2.418 and 2.401 ms/tick. So the frame
# rate moved 30% between builds that were, by every stable measure, the same. Below these floors a
# difference is not evidence, and `compare()` says so on the line rather than leaving the reader to
# multiply it out. `[[scrutiny-asymmetry]]`: the number that is changing is the one to distrust.
# Below these absolute sizes a metric is at its own print precision and a ratio over it means nothing.
TINY = {"warm_upload_ms": 0.010, "warm_prep_ms": 0.010, "warm_drawn_per_tick": 0.010}
NOISE_FLOOR = {"warm_fps_wall": 0.30, "warm_p50": 0.30, "warm_p99": 0.25, "warm_draw_p50": 0.30,
               "warm_max": 0.15, "warm_drawn_per_tick": 0.05, "warm_prep_ms": 0.10,
               "warm_prep_us_cell": 0.10, "warm_upload_ms": 0.50}


def frame_note(warm):
    """Whether the FRAME statistics may be read: `fps_wall`, the percentiles and the over-budget counts.

    A window whose `fps_wall` sits at ~120 with `--disable-vsync` set was paced by the display, and then
    every frame that fitted inside a refresh interval measured as exactly one refresh interval -- legacy
    wrote this down and D0527 walked into it anyway. There is nothing to salvage: the numbers describe
    the compositor. The phase clocks above survive it; these do not.
    """
    unfocused = [w for w in warm if w.get("focus", 0.0) < FOCUS_MIN]
    if unfocused:
        return ("WITHHELD: %d of %d warm windows drew into a window that was not frontmost (focus %s). "
                "macOS stops presenting what nobody is looking at, so these frame and draw times are the "
                "compositor's, not the game's. Re-run with --front." % (len(unfocused), len(warm),
                ", ".join("%.2f" % w.get("focus", 0.0) for w in unfocused[:4])))
    paced = [w for w in warm if PACED_BAND[0] <= w["fps_wall"] <= PACED_BAND[1]]
    if not paced:
        return "VALID"
    return ("WITHHELD: %d of %d warm windows were paced at ~120 Hz despite --disable-vsync. Frame times "
            "there measure the display, not the game." % (len(paced), len(warm)))


def med(warm, key):
    vals = [w[key] for w in warm if key in w]
    return statistics.median(vals) if vals else float("nan")


def summarise(workload, runs, hidden=False):
    cold = [r[0] for r in runs if r]
    warm = [w for r in runs for w in r[1:]]
    s = {"workload": workload, "reps": len(runs), "warm_windows": len(warm),
         "verdict": verdict(workload, warm),
         "frames": HIDDEN_FRAMES if hidden else frame_note(warm)}
    if not runs or any(len(r) < 3 for r in runs):
        s["verdict"] = "VOID: every repetition must contain a cold and at least two warm windows"
    for key in ("fps_wall", "p50", "p99", "max", "over16", "quiet_p50", "cal_p50", "cal_spread",
                "focus", "draw_p50", "draw_p99", "drawn_per_tick", "prep_ms", "prep_us_cell", "prep_cells", "upload_ms",
                "upload_us_cell", "uploads"):
        s["warm_" + key] = med(warm, key)
    for key in ("fps_wall", "p50", "max", "prep_ms", "upload_ms"):
        s["cold_" + key] = med(cold, key)
    s["warm_window_max_median"] = s["warm_max"]
    s["warm_max"] = max((w["max"] for w in warm if "max" in w), default=float("nan"))
    s["cold_max"] = max((w["max"] for w in cold if "max" in w), default=float("nan"))
    s["warm_frames"] = sum(w.get("frames", 0) for w in warm)
    s["warm_over16_total"] = sum(w.get("over16", 0) for w in warm)
    s["runs"] = runs  # retain windows; do not discard the evidence behind the summary
    s["schema_version"] = 2
    s["warm_peak_prep_ms"] = max((w.get("peak_prep_ms", 0) for w in warm), default=0)
    s["warm_peak_cells"] = max((w.get("peak_cells", 0) for w in warm), default=0)
    events = [dict(w["burst"], repetition=i + 1, window_tick=w["tick"])
              for i, run in enumerate(runs) for w in run[1:] if w.get("burst")]
    s["slowest_burst"] = max(events, key=lambda event: event["usec"], default={})
    return s


def render(s):
    print("\n=== %s: %d reps, %d warm windows ===" % (s["workload"], s["reps"], s["warm_windows"]))
    print("  phases  %s" % s["verdict"])
    print("  frames  %s" % s["frames"])
    print("  control       cal p50 %.0f us  (p99/p50 %.2f)" % (s["warm_cal_p50"], s["warm_cal_spread"]))
    if s["verdict"].startswith("VOID"):
        return
    print("  warm physics  quiet tick p50 %.2f ms" % s["warm_quiet_p50"])
    print("  slowest burst " + json.dumps(s["slowest_burst"], sort_keys=True))
    print("  warm peak     preparation %.3f ms in one physics tick; peak painted rectangle cells %.0f"
          % (s["warm_peak_prep_ms"], s["warm_peak_cells"]))
    print("  warm painters drawn %.3f ms/tick" % s["warm_drawn_per_tick"])
    if s["frames"] == "VALID":
        print("  warm draw     phase p50 %.2f ms  p99 %.2f ms   (window focused in %.0f%% of frames)"
              % (s["warm_draw_p50"], s["warm_draw_p99"], s["warm_focus"] * 100.0))
    print("  warm bake     prep %.3f ms/tick over %.0f cells (%.2f us/cell) | upload %.3f ms/tick, %.0f of them (%.3f us/cell)"
          % (s["warm_prep_ms"], s["warm_prep_cells"], s["warm_prep_us_cell"],
             s["warm_upload_ms"], s["warm_uploads"], s["warm_upload_us_cell"]))
    print("  cold window   prep %.3f ms/tick  upload %.3f ms/tick"
          % (s["cold_prep_ms"], s["cold_upload_ms"]))
    if s["frames"].startswith("VALID"):
        print("  warm frame    median-window fps_wall %.1f  p50 %.2f ms  p99 %.2f ms  observed max %.2f ms  over16.7 %.0f/%.0f"
              % (s["warm_fps_wall"], s["warm_p50"], s["warm_p99"], s["warm_max"],
                 s["warm_over16_total"], s["warm_frames"]))
        print("  cold frame    fps_wall %.1f  p50 %.2f ms" % (s["cold_fps_wall"], s["cold_p50"]))


def compare(before, after):
    """Two saved runs, workload by workload. Refuses any pair whose verdicts are not both plain VALID."""
    b = {s["workload"]: s for s in json.loads(pathlib.Path(before).read_text())}
    a = {s["workload"]: s for s in json.loads(pathlib.Path(after).read_text())}
    for name in [w for w in WORKLOADS if w in b and w in a]:
        print("\n=== %s ===" % name)
        if b[name]["verdict"] != "VALID" or a[name]["verdict"] != "VALID":
            print("  REFUSED: before %s / after %s" % (b[name]["verdict"], a[name]["verdict"]))
            continue
        frames_valid = b[name]["frames"] == a[name]["frames"] == "VALID"
        if not frames_valid:
            print("  frame statistics withheld: at least one side is invalid; phase clocks below only")
        ratio = a[name]["warm_cal_p50"] / max(b[name]["warm_cal_p50"], 1e-9)
        if not 1 / CAL_DRIFT_MAX <= ratio <= CAL_DRIFT_MAX:
            print("  REFUSED: the host ran %.2fx differently between the two runs (control %.0f -> %.0f us)"
                  % (ratio, b[name]["warm_cal_p50"], a[name]["warm_cal_p50"]))
            continue
        print("  control held: %.0f -> %.0f us (%.2fx)" % (b[name]["warm_cal_p50"], a[name]["warm_cal_p50"], ratio))
        for key, unit in (("warm_fps_wall", "fps"), ("warm_p50", "ms"), ("warm_p99", "ms"),
                          ("warm_max", "ms"), ("warm_drawn_per_tick", "ms/tick"),
                          ("warm_draw_p50", "ms"), ("warm_prep_ms", "ms/tick"),
                          ("warm_prep_us_cell", "us/cell"), ("warm_upload_ms", "ms/tick")):
            if not frames_valid and key in ("warm_fps_wall", "warm_p50", "warm_p99", "warm_max", "warm_draw_p50"):
                continue
            if key == "warm_max" and any(s[name].get("schema_version") != 2 for s in (a, b)):
                print("  max withheld: legacy reports stored a median of maxima, not an observed maximum")
                continue
            was, now = b[name][key], a[name][key]
            # A RATIO BETWEEN TWO NUMBERS AT THE PRINT PRECISION IS NOT A RESULT: 0.001 -> 0.002 ms/tick
            # reads as +100% and is one digit of rounding. Below the floor the line says so and stops.
            if max(abs(was), abs(now)) < TINY.get(key, 0.0):
                print("  %-22s %8.3f -> %8.3f %-8s  (both below %.3f: rounding, not a result)"
                      % (key[5:], was, now, unit, TINY[key]))
                continue
            moved = abs(now - was) / max(abs(was), 1e-9)
            floor = NOISE_FLOOR.get(key, 0.10)
            mark = "  moved %+.0f%%" % (100.0 * (now - was) / max(abs(was), 1e-9)) if moved > floor \
                else "  (within this metric's %.0f%% noise floor: not evidence)" % (100.0 * floor)
            print("  %-22s %8.3f -> %8.3f %-8s%s" % (key[5:], was, now, unit, mark))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--workload", choices=WORKLOADS)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--reps", type=int, default=3)
    ap.add_argument("--ticks", type=int, default=1500)
    ap.add_argument("--zoom", default="2")
    ap.add_argument("--godot", default=GODOT)
    ap.add_argument("--out")
    ap.add_argument("--label", default="")
    ap.add_argument("--seat", action="append", default=[],
                    help="an extra flag passed through to the seat, e.g. --seat=--interpolate. Repeatable.")
    ap.add_argument("--front", action="store_true",
                    help="do not hand focus back: the seat keeps the front for the whole run, which is "
                         "the only regime a frame rate can be claimed from, and takes the screen to do it")
    ap.add_argument("--hidden", action="store_true",
                    help="hide the seat window after two seconds. macOS then stops presenting it, so the "
                         "CPU phases are isolated from presentation and every frame number is withheld. "
                         "Not the default: presentation is part of what is being measured.")
    ap.add_argument("--compare", nargs=2, metavar=("BEFORE", "AFTER"))
    args = ap.parse_args()
    if args.compare:
        compare(*args.compare)
        return 0
    if args.reps < 1 or args.ticks < 900 or args.ticks % WINDOW_TICKS:
        ap.error("require positive repetitions and at least 900 ticks in complete 300-tick windows")
    names = list(WORKLOADS) if args.all else [args.workload or "still"]
    out = []
    for name in names:
        print("running %s x%d (%d ticks each)" % (name, args.reps, args.ticks), file=sys.stderr)
        out.append(summarise(name, gather(name, args.reps, args.ticks, args.zoom, args.godot,
                                           args.hidden, args.front, tuple(args.seat)), args.hidden))
    print("\nfixture: %s, %d ticks a run, zoom %s, label %r" % (", ".join(names), args.ticks, args.zoom, args.label))
    for s in out:
        render(s)
    if args.out:
        pathlib.Path(args.out).write_text(json.dumps(out, indent=1))
        print("\nsaved %s" % args.out)
    return 1 if any(s["verdict"] != "VALID" for s in out) else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
