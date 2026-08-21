#!/usr/bin/env bash
# THE SEED CORPUS — run the seed-sensitive layers across MANY worlds, not just the one we grew up on.
#
# The problem this exists for: every feel floor in this project is measured on seed 1337 and nothing else.
# Every screenshot, play-test, capture and richness reading in the repo's history is one world. A change
# that leaves 1337 pleasant and 4242 barren passes the entire harness, and we would not find out until
# somebody pressed TAB on the title screen.
#
# It runs the REAL layers with their REAL floors (via SF_SEED, which MainView.default_seed consults), so
# the corpus can never drift from what the harness asserts. Nothing here re-implements a measurement and
# nothing here relaxes one.
#
# READ THIS BEFORE "FIXING" A RED CELL: a seed-fragile generator is the FINDING, not a thing to tune away.
# Do not lower a floor to make this green. If most seeds fail a floor, the floor may genuinely be wrong --
# but that is an argument to make explicitly, with the distribution in hand, not a number to quietly edit.
#
#   bash tools/seed_corpus.sh                 # the committed corpus
#   bash tools/seed_corpus.sh 1337 99 12345   # ad-hoc seeds
#
# Not part of run_harness.sh: it is layers x seeds and takes minutes. Run it when worldgen or a feel floor
# changes, and before believing any richness/relief/descent number.
set -u

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
[ -x "$GODOT" ] || GODOT="$(command -v godot || echo godot)"

# THE COMMITTED CORPUS. Fixed on purpose: a random corpus makes every run a different experiment and you
# can never tell a regression from a reroll. 1337 leads because it is the shipping seed and the one every
# historical measurement used -- keep it first so its column is always the comparison point.
CORPUS=(1337 4242 7 99 20260817 31337 512 8675309)
[ "$#" -gt 0 ] && CORPUS=("$@")

# NARROW TO ONE LAYER when you are chasing a specific finding rather than sweeping. Extended regex against
# the layer name, same shape as the harness's SF_ONLY so there is one thing to remember:
#   SF_CORPUS_ONLY=check_pacing bash tools/seed_corpus.sh
# A subset is never a corpus run, and the header below says which it was.

# The seed-sensitive layers: each boots a GENERATED world and measures a property of it. Layers asserting
# something seed-independent (save durability, controls, registries) are deliberately absent — running them
# per seed would burn minutes to re-prove the same thing. A layer that builds its own FIXTURE does not
# belong here either, however seed-shaped its subject sounds.
#
# `check_tells` was in this list and has been removed. Its first sweep printed BYTE-IDENTICAL numbers in all
# eight columns — 0.48 / 1.00 / 0.00 / 0.96-vs-0.00, every seed — because its own docstring says it measures
# a hand-built fixture "rather than on generated terrain", deliberately and for good reasons. Eight ok cells
# that are one result printed eight times. Nothing was broken; the corpus was simply claiming 48 cells of
# coverage when 40 of them were the evidence. The invariance check below now catches this class rather than
# trusting this list to stay honest.
LAYERS=(
	check_richness
	check_descent
	check_relief
	check_room_reads
	check_underground
	# ADDED 2026-08-17, and it is the exact class this tool exists for: `check_pacing` run across four
	# ad-hoc seeds failed two of them on floors that are green in the harness, because the harness runs
	# ONE seed. A layer whose subject is "the shape of a session" is seed-sensitive by construction — the
	# session happens in a generated world — and it had never been pointed at more than one. Whatever the
	# distribution says, it is a finding about the worlds and not a licence to move a floor; read the
	# warning at the top of this file before touching one.
	check_pacing
)

# WHICH LAYERS NEED A REAL WINDOW. `check_underground` judges PIXELS, and the headless driver paints blank
# frames — run it under --headless and it stands itself down with exit 42. This list used to not exist, so
# every one of its cells came back non-zero and the corpus would have printed EIGHT RED CELLS for a layer
# that never ran, which reads exactly like the seed-fragility finding this tool was built to look for.
# Fabricating the finding you went looking for is the worst failure available to an instrument.
GL_LAYERS=" check_underground "

# The runner's whole-layer skip code. A layer that stood down did NOT fail, and a corpus that cannot tell
# those apart is the "skip counts as PASS" bug from queue item 1 wearing its sign backwards.
SKIP_CODE=42

DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT

# Anything that boots Godot takes the harness lock. `user://` is keyed on the project NAME, so this sweep
# shares one save slot and one set of fixtures with any harness run, in any worktree, on this machine.
# Sixteen minutes of Godot next to somebody's sweep corrupts both, and the corpus is precisely the tool
# whose output somebody will read as a property of the WORLD.
LOCK="${SF_LOCK:-${TMPDIR:-/tmp}/sinkforge-harness.lock}"
LOCK_HELD=0
if [ "${SF_NO_LOCK:-0}" != "1" ]; then
	waited=0
	while :; do
		if mkdir "$LOCK" 2>/dev/null; then
			printf '%s\n%s\n' "$$" "$PWD" >"$LOCK/owner"; LOCK_HELD=1; break
		fi
		holder="$(head -1 "$LOCK/owner" 2>/dev/null || true)"
		if [ -n "${holder:-}" ] && ! kill -0 "$holder" 2>/dev/null; then
			echo "  (clearing a stale harness lock: pid $holder is gone)"; rm -rf "$LOCK"; continue
		fi
		if [ "$waited" -ge "${SF_LOCK_WAIT:-900}" ]; then
			echo "!! another run has held $LOCK for ${waited}s (pid ${holder:-unknown}) — refusing to sweep"
			echo "   concurrently, because the distribution would then describe two runs. SF_NO_LOCK=1 overrides."
			exit 5
		fi
		[ $((waited % 30)) -eq 0 ] && echo "  waiting for the harness lock (held by pid ${holder:-?}) ..."
		sleep 2; waited=$((waited + 2))
	done
	trap 'rm -rf "$DIR"; [ "$LOCK_HELD" = "1" ] && rm -rf "$LOCK"' EXIT
fi

if [ -n "${SF_CORPUS_ONLY:-}" ]; then
	KEEP=()
	for l in "${LAYERS[@]}"; do
		printf '%s' "$l" | grep -Eq -- "$SF_CORPUS_ONLY" && KEEP+=("$l")
	done
	if [ "${#KEEP[@]}" -eq 0 ]; then
		echo "!! SF_CORPUS_ONLY='${SF_CORPUS_ONLY}' matched none of: ${LAYERS[*]}" >&2
		exit 2
	fi
	LAYERS=("${KEEP[@]}")
fi
subset=""
[ -n "${SF_CORPUS_ONLY:-}" ] && subset=" — SUBSET, SF_CORPUS_ONLY='${SF_CORPUS_ONLY}'"
echo "tree: $(cd "$(dirname "$0")/.." && pwd -P)  branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null)  head: $(git rev-parse --short HEAD 2>/dev/null)"
echo "SEED CORPUS — ${#LAYERS[@]} layers x ${#CORPUS[@]} seeds${subset}"
echo "godot: $GODOT"
echo

# Header
printf '%-24s' "layer"
for s in "${CORPUS[@]}"; do printf '%9s' "$s"; done
printf '%8s\n' "pass"
printf -- '-%.0s' $(seq 1 $((24 + 9 * ${#CORPUS[@]} + 8))); echo

total_fail=0
total_skip=0
seed_blind=0
declare -a FAILED_CELLS=()
declare -a SKIPPED_CELLS=()

for layer in "${LAYERS[@]}"; do
	printf '%-24s' "$layer"
	npass=0
	nran=0
	# A pixel layer gets a real window; everything else stays headless, which is faster and is what CI does.
	headless=(--headless)
	case "$GL_LAYERS" in *" $layer "*) headless=() ;; esac
	for s in "${CORPUS[@]}"; do
		log="$DIR/$layer.$s.log"
		# `${a[@]+"${a[@]}"}` rather than `"${a[@]}"`: macOS ships bash 3.2, where expanding an EMPTY array
		# under `set -u` is an unbound-variable error. The pixel layer is exactly the case with an empty one.
		SF_SEED="$s" "$GODOT" ${headless[@]+"${headless[@]}"} --path . --script "res://tools/$layer.gd" >"$log" 2>&1
		rc=$?
		if [ "$rc" -eq 0 ]; then
			printf '%9s' "ok"; npass=$((npass + 1)); nran=$((nran + 1))
		elif [ "$rc" -eq "$SKIP_CODE" ]; then
			# NOT a failure and NOT a pass. Counted in neither, named at the bottom, and excluded from the
			# per-layer denominator so "6/6" never quietly means "6 of the 2 that ran".
			printf '%9s' "skip"; total_skip=$((total_skip + 1)); SKIPPED_CELLS+=("$layer @ seed $s")
		else
			printf '%9s' "FAIL"; nran=$((nran + 1))
			total_fail=$((total_fail + 1))
			FAILED_CELLS+=("$layer @ seed $s")
			cp "$log" "${TMPDIR:-/tmp}/seed_corpus.$layer.$s.log" 2>/dev/null
		fi
	done
	printf '%7s/%d\n' "$npass" "$nran"
done

echo
echo "=== THE NUMBERS, per seed (the distribution is the point, not the verdict) ==="
# Surface every measured quantity the layers printed, so a floor that is barely held on six seeds and
# comfortably held on two is VISIBLE rather than hidden behind a row of "ok".
for layer in "${LAYERS[@]}"; do
	shown=0
	for s in "${CORPUS[@]}"; do
		log="$DIR/$layer.$s.log"
		[ -f "$log" ] || continue
		# Layers report their measurements parenthesised inside the assertion text -- "(density 7.4 per 100
		# rows)", "(drought 19)". Pull the parenthesised groups that contain a digit off the PASS/FAIL lines
		# and put one seed per line. Deliberately dumb: any layer that prints its numbers the normal way
		# shows up here without the corpus knowing anything about that layer.
		allnums=$(grep -hE "^[[:space:]]*(PASS|FAIL)" "$log" 2>/dev/null \
			| grep -oE '\([^)]*[0-9][^)]*\)')
		if [ -z "$allnums" ]; then
			nums=""
		else
			ngroups=$(printf '%s\n' "$allnums" | grep -c .)
			nums=$(printf '%s\n' "$allnums" | head -4 | tr '\n' ' ')
			# A cap that drops evidence without saying so reads as "that was all of it". It was not.
			[ "$ngroups" -gt 4 ] && nums="$nums(+$((ngroups - 4)) more, see the log) "
		fi
		if [ -n "$nums" ]; then
			[ "$shown" = 0 ] && { echo; echo "--- $layer"; shown=1; }
			printf '  seed %-10s %s\n' "$s" "$nums"
			printf '%s\n' "$nums" >>"$DIR/$layer.nums"
		fi
	done
	[ "$shown" = 0 ] && { echo; echo "--- $layer  (prints no parenthesised numbers — read its log directly)"; }

	# THE INVARIANCE CHECK. A row whose numbers never move across eight different worlds is not evidence
	# that the generator is robust — it is evidence the LAYER never looked at the world. Those cells are a
	# constant repeated, and counting them as coverage is how a corpus overstates itself.
	#
	# This is here because it already happened: `check_tells` sat in the layer list printing one identical
	# result eight times, and the sweep read as 6x8 green. The list is now one line shorter, but a list is a
	# snapshot and this is the runner for it — the next layer added by somebody who has not read this far
	# announces itself instead of quietly padding the total.
	if [ -f "$DIR/$layer.nums" ]; then
		distinct=$(sort -u "$DIR/$layer.nums" | wc -l | tr -d ' ')
		if [ "$distinct" -eq 1 ] && [ "${#CORPUS[@]}" -gt 1 ]; then
			echo "  !! SEED-BLIND: identical on all ${#CORPUS[@]} seeds. This layer is not reading the world;"
			echo "     its cells are one result repeated and prove nothing about seed robustness."
			seed_blind=$((seed_blind + 1))
		fi
	fi
done

echo
if [ "$total_skip" -gt 0 ]; then
	echo "$total_skip CELL(S) DID NOT RUN — not passes, not failures:"
	for c in "${SKIPPED_CELLS[@]}"; do echo "  $c"; done
	echo
fi
if [ "$total_fail" -eq 0 ]; then
	if [ "$total_skip" -gt 0 ]; then
		# The word "GREEN" is reserved for a sweep that actually measured every cell. This is the same rule
		# the runner learned the hard way when it printed "ALL 61 HARNESS LAYERS PASS" over four layers that
		# had drawn nothing.
		echo "NO RED CELLS, but $total_skip did not run — this is NOT a clean corpus sweep."
		exit 4
	fi
	if [ "$seed_blind" -gt 0 ]; then
		echo "NO RED CELLS, but $seed_blind layer(s) are SEED-BLIND — that is not a clean sweep either."
		exit 4
	fi
	echo "CORPUS GREEN — every floor holds on all ${#CORPUS[@]} seeds."
	exit 0
fi
if [ "$seed_blind" -gt 0 ]; then
	echo "$seed_blind LAYER(S) ARE SEED-BLIND — see the flags above. Their columns are not coverage."
	echo
fi
# A red cell says THIS LAYER failed on THIS SEED. It does not say the generator did it. The layer and the
# play driver are both inside the measurement, and the first time this ran, two of the five red cells were a
# driver that could not finish the opening rather than a world that was badly shaped.
echo "$total_fail RED CELL(S) — this layer failed on this seed:"
for c in "${FAILED_CELLS[@]}"; do
	echo "  $c"
	_layer="${c%% @ seed *}"; _seed="${c##* }"
	# THE ASSERTION TEXT, not a digit-filtered sample of it. The numbers block above only pulls
	# parenthesised groups CONTAINING A DIGIT, so an assertion whose parenthetical is words was invisible
	# there — and on the first corpus run that was the single most important line in the whole sweep:
	# "FAIL: the session is playable at all (the opening reached first automation)" fired on two seeds and
	# never reached the summary, which showed only the dead-air and density numbers that are downstream of
	# it. A summary that cannot print a failure is worse than no summary, because it looks like one.
	grep -hE "^[[:space:]]*FAIL" "$DIR/$_layer.$_seed.log" 2>/dev/null | sed -E 's/^[[:space:]]*/      /'
done
echo
echo "Logs for failing cells: ${TMPDIR:-/tmp}/seed_corpus.<layer>.<seed>.log"
echo "This is a FINDING. Do not lower a floor to clear it."
exit 1
