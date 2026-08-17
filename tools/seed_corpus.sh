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

# The seed-sensitive layers: each boots a generated world and measures a property of it. Layers that
# assert something seed-independent (save durability, controls, registries) are deliberately absent --
# running them per seed would burn minutes to re-prove the same thing.
LAYERS=(
	check_richness
	check_descent
	check_relief
	check_room_reads
	check_tells
	check_underground
)

DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT

echo "SEED CORPUS — ${#LAYERS[@]} layers x ${#CORPUS[@]} seeds"
echo "godot: $GODOT"
echo

# Header
printf '%-24s' "layer"
for s in "${CORPUS[@]}"; do printf '%9s' "$s"; done
printf '%8s\n' "pass"
printf -- '-%.0s' $(seq 1 $((24 + 9 * ${#CORPUS[@]} + 8))); echo

total_fail=0
declare -a FAILED_CELLS=()

for layer in "${LAYERS[@]}"; do
	printf '%-24s' "$layer"
	npass=0
	for s in "${CORPUS[@]}"; do
		log="$DIR/$layer.$s.log"
		if SF_SEED="$s" "$GODOT" --headless --path . --script "res://tools/$layer.gd" >"$log" 2>&1; then
			printf '%9s' "ok"
			npass=$((npass + 1))
		else
			printf '%9s' "FAIL"
			total_fail=$((total_fail + 1))
			FAILED_CELLS+=("$layer @ seed $s")
			cp "$log" "${TMPDIR:-/tmp}/seed_corpus.$layer.$s.log" 2>/dev/null
		fi
	done
	printf '%7s/%d\n' "$npass" "${#CORPUS[@]}"
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
		nums=$(grep -hE "^[[:space:]]*(PASS|FAIL)" "$log" 2>/dev/null \
			| grep -oE '\([^)]*[0-9][^)]*\)' | head -4 | tr '\n' ' ')
		if [ -n "$nums" ]; then
			[ "$shown" = 0 ] && { echo; echo "--- $layer"; shown=1; }
			printf '  seed %-10s %s\n' "$s" "$nums"
		fi
	done
	[ "$shown" = 0 ] && { echo; echo "--- $layer  (prints no parenthesised numbers — read its log directly)"; }
done

echo
if [ "$total_fail" -eq 0 ]; then
	echo "CORPUS GREEN — every floor holds on all ${#CORPUS[@]} seeds."
	exit 0
fi
echo "$total_fail RED CELL(S) — the generator is seed-fragile at these points:"
for c in "${FAILED_CELLS[@]}"; do echo "  $c"; done
echo
echo "Logs for failing cells: ${TMPDIR:-/tmp}/seed_corpus.<layer>.<seed>.log"
echo "This is a FINDING. Do not lower a floor to clear it."
exit 1
