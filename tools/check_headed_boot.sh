#!/usr/bin/env bash
# Boots tests/body/reveal_scene.tscn WITH A REAL WINDOW and checks that the documented invocations do
# what they are documented to do. Every other suite in this repository runs `--headless`, so until this
# existed nothing exercised the path a human actually uses.
#
# WHY IT EXISTS (docs/DECISIONS_LEDGER.md D0248). The director ran the command from
# `docs/NEEDS_DIRECTOR.md` P015 to look at the sky and got an agent-mode run that drove itself twelve
# ticks, wrote a recording, and quit -- no window, nothing to look at. Nothing was broken and nothing
# was red: the scene defaults to agent mode, `--play` is what asks for a window, and the documented line
# omitted it. **A whole class of failure lived below the test suite.** A scene can boot, render, pass 42
# headless suites, and still not do what its own header tells a human to type.
#
# WHAT IT ASSERTS, each with a control, so a uniformly-broken run cannot read as a pass:
#
#   A. agent mode, headed         -> DOES print "agent-mode run finished"
#   B. --play, headed, +shutter   -> does NOT print it, and captures a non-blank frame
#
# A is not decoration. Alone, B's "did not print the agent string" would pass on a boot that crashed
# before reaching the line, on a renamed message, and on a binary that cannot open a window at all. A
# proves the string is producible by this build, in this scene, right now -- so B's silence means the
# flag took effect rather than that the discriminator is gone. Same binary, same scene, one flag apart.
#
# HOW "a real frame reached a real window" IS MEASURED. Not by exit code and not by file size, but by
# the scene's own blankness instrument (D0189/D0190), which prints the distinct-colour count of a sample
# grid over the captured image. A window that never rendered yields 1. This is deliberately NOT compared
# against a headless capture: `tools/capture_moments.sh` already records that the headless renderer
# cannot do this at all -- it returns a null image, and the scene then hangs rather than exiting -- so a
# headless "control" would be measuring a known-broken path, not a blank one. The first draft of this
# script did exactly that and hung for five minutes.
#
# Usage: tools/check_headed_boot.sh <godot-binary>
# In CI this needs a display (`xvfb-run -a`), which the workflow step provides.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

GODOT_BIN="${1:?usage: check_headed_boot.sh <godot-binary>}"
SCENE="tests/body/reveal_scene.tscn"
WORK="$(mktemp -d)"
## the EXIT trap is installed below, once `cleanup_byproducts` exists to go in it

# Both runs below boot a scene that writes an input recording on quit, so every invocation of this
# script drops two byproducts into `tests/body/recordings/`. D0220 records twelve of them reaching two
# commits via `git add -A` before anyone noticed, and `tools/capture_moments.sh` already solved this;
# the pattern is copied rather than re-invented.
#
# ONE DIFFERENCE THAT MATTERS. capture_moments only ever produces `reveal_agent_*`, which that directory's
# README calls a byproduct to "delete them freely". This script also produces `reveal_play_*`, and the
# same README says those are REAL RECORDED PLAY, not to be deleted without asking the director. So the
# before/after snapshot is not a tidiness measure here -- it is the only thing separating "a log this
# script just made" from "the session the director recorded while it was running". Anything that existed
# before this run is left alone, whatever it is called.
RECORDINGS="tests/body/recordings"
BEFORE_LOGS="$(ls "$RECORDINGS"/reveal_agent_*.log "$RECORDINGS"/reveal_play_*.log 2>/dev/null | sort)"

cleanup_byproducts() {
	local after new count
	after="$(ls "$RECORDINGS"/reveal_agent_*.log "$RECORDINGS"/reveal_play_*.log 2>/dev/null | sort)"
	new="$(comm -13 <(printf '%s\n' "$BEFORE_LOGS") <(printf '%s\n' "$after"))"
	count="$(printf '%s\n' "$new" | grep -c . || true)"
	if [ "$count" -gt 0 ]; then
		printf '%s\n' "$new" | while IFS= read -r log; do
			[ -n "$log" ] && rm -f "$log"
		done
		note "removed $count byproduct recording(s) this run created"
	fi
}
trap 'cleanup_byproducts; rm -rf "$WORK"' EXIT

AGENT_DONE="agent-mode run finished"
# A frame that never drew samples as ONE colour. Any real frame of this world is in the hundreds -- the
# headed run this script was written against reported 188, and the committed milestone pairs carry 168
# and 199 over the full image. 8 sits far above blank and far below anything legitimately dark, and the
# measured value is printed on every run so tightening it later is a measurement, not a guess.
MIN_COLOURS=8
fail=0

note() { printf 'check_headed_boot: %s\n' "$1"; }
bad()  { printf 'check_headed_boot: FAIL - %s\n' "$1" >&2; fail=1; }

# --- A. agent mode, headed. Establishes that the discriminator string is producible at all. -----------
out_a="$("$GODOT_BIN" --path . "$SCENE" -- --site=reveal_test_dense --seed=20260826 2>&1)"
rc_a=$?
if [ "$rc_a" -ne 0 ]; then
	bad "agent-mode headed boot exited $rc_a -- a windowed boot does not work here at all, so nothing below is a verdict about --play"
	printf '%s\n' "$out_a" | tail -15 >&2
	exit 1
fi
if printf '%s\n' "$out_a" | grep -qF "$AGENT_DONE"; then
	note "PASS  A: agent mode, headed, drives itself and says so"
else
	bad "the agent-mode headed run never printed \"$AGENT_DONE\" -- the discriminator B rests on is not producible, so B's own silence would mean nothing"
	printf '%s\n' "$out_a" | tail -15 >&2
	exit 1
fi

# --- B. --play, headed: the exact line the director typed, plus a shutter so it terminates. -----------
shot="$WORK/headed.png"
# The camera row is RELATIVE TO THE SURFACE (P017/D0292). At an absolute 4 it pointed into the sky, the
# frame came back blank, and this check failed with "could not read a distinct-colour count" -- a message
# about the instrument, in a run where nothing was wrong with the instrument.
SURFACE_ROW="$("$ROOT/tools/surface_row.sh")" || exit 1
out_b="$("$GODOT_BIN" --path . "$SCENE" -- --play --sky --zoom=6.5 --camera=24,$((SURFACE_ROW + 4)) \
	--screenshot-tick=10 --screenshot-out="$shot" 2>&1)"
rc_b=$?
[ "$rc_b" -ne 0 ] && { bad "--play headed boot exited $rc_b"; printf '%s\n' "$out_b" | tail -15 >&2; }

if printf '%s\n' "$out_b" | grep -qF "$AGENT_DONE"; then
	bad "--play ran as an AGENT run: it printed \"$AGENT_DONE\". This is the D0248 defect itself -- the documented command ignoring the flag that hands a human control."
else
	note "PASS  B: --play does not self-drive as an agent run"
fi

[ -s "$shot" ] || bad "--play headed run wrote no screenshot, so nothing shows a frame was ever drawn"

colours="$(printf '%s\n' "$out_b" | sed -n 's/.*capture has \([0-9]*\) distinct colours.*/\1/p' | tail -1)"
if [ -z "$colours" ]; then
	bad "could not read a distinct-colour count out of the run -- the scene's own blankness instrument (D0189) is what this check rests on, and it did not report. Refusing to call the frame non-blank on the strength of the file merely existing."
elif [ "$colours" -ge "$MIN_COLOURS" ]; then
	note "PASS  B: the captured frame carries $colours distinct colours (floor $MIN_COLOURS; a window that never rendered gives 1)"
else
	bad "the captured frame carries only $colours distinct colours (floor $MIN_COLOURS) -- the window booted but drew nothing worth looking at"
fi

if [ "$fail" -eq 0 ]; then
	note "PASS - the documented headed invocations behave as documented"
fi
exit $fail
