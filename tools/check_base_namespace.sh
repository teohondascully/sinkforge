#!/bin/sh
# NO SUITE MAY REDECLARE A MEMBER OF `tests/test_base.gd`, and the reason this is a separate file is
# that the failure it catches is invisible where you would look for it.
#
# Ported from `legacy/tools/check_base_namespace.sh` (docs/DECISIONS_LEDGER.md D0119), which guarded the
# pre-pivot codebase's own `tools/check_base.gd` and its ~100 subclasses. That file's own real-world
# story: `_asserted()` was added to the base; `check_hint_gate.gd`, untouched for weeks, already had
# `var _asserted: int = 0`. GDScript rejects the SUBCLASS -- "the member already exists in parent class"
# -- so `--check-only` on the EDITED file was clean, the broken file was one nobody had opened, the
# runner scored 105 PASS / 0 FAIL, and only a harness verdict log caught it, 275 seconds later.
#
# This project's own analog is `tests/test_base.gd` (19 real subclasses as of D0119, every `test_*.gd`
# suite plus `fixture_harness_crash_probe.gd`) -- the only base class in the post-pivot tree meaningfully
# extended BY PATH more than once (`tools/check_base.gd` has zero non-legacy subclasses; it is purely a
# legacy/ concern, correctly excluded). Found via `.githooks/pre-commit` silently no-op'ing on this
# check's OWN absence since the pivot moved it to `legacy/tools/` and nothing recreated it at the new
# path -- 119 commits landed with this specific protection off before D0117's sweep-blindness hunt caught
# it (the hook's own `[ -x ... ] || [ -r ... ]` guard was false, so the whole block silently did nothing).
#
# WHAT GDSCRIPT ACTUALLY PERMITS, because the rule is not "no repeated names":
#
#   func over func     LEGAL. That is an override, and layers do it.
#   var/const over ANY base member    ILLEGAL.
#   func over a base var/const        ILLEGAL.
#
# EXTRACTION IS ANCHORED AT COLUMN 0, NOT JUST "starts with var/const" -- a real bug found while porting,
# fixed before trusting this file, not the legacy original's own behavior: the first draft's regex allowed
# leading whitespace, so a LOCAL variable inside a function body (`test_base.gd`'s own `_flat_grid()`
# declares `var grid: TileGrid = ...`) was extracted as a "base member," and every subclass with its own
# unrelated local `var grid` inside some other function then false-positived as a collision. Column-0
# anchoring fixes the confirmed case (this codebase never indents a real class-level member). NOT fixed,
# and currently inert rather than proven safe: an inner `class` block's own method (two subclasses have
# one, `fixture_body_fuzz_probe.gd`/`test_replay_determinism.gd`) is still indented but still class-level
# WITHIN that inner class, and nothing currently distinguishes "inner class's own member" from "outer
# subclass's own member" -- a future inner-class method happening to share a base member's name would
# false-positive the same way. Named here rather than silently left for someone to rediscover.
#
#   sh tools/check_base_namespace.sh            # every subclass in the tree
#   sh tools/check_base_namespace.sh a.gd b.gd  # only these
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/tests/test_base.gd"

if [ ! -r "$BASE" ]; then
	printf 'check_base_namespace: FAIL — %s is not readable, so the base namespace is unknown.\n' "$BASE" >&2
	printf '  An unreadable input is not an empty one. Nothing was compared.\n' >&2
	exit 1
fi

# `signal` is in here because it declares a member too, and `enum` because a named enum does.
base_vars="$(sed -nE 's/^(static[[:space:]]+)?(var|const|signal|enum)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\3/p' "$BASE" | sort -u)"
base_funcs="$(sed -nE 's/^[[:space:]]*(static[[:space:]]+)?func[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/p' "$BASE" | sort -u)"
n_base=$(printf '%s\n%s\n' "$base_vars" "$base_funcs" | grep -c .)
if [ "$n_base" -lt 3 ]; then
	# A REGEX THAT MATCHED ALMOST NOTHING IS A BROKEN INSTRUMENT, NOT A CLEAN BASE CLASS. test_base.gd has
	# had at least three members (`_failures`, `_finish`, `_check`) its whole life; fewer means the
	# extraction stopped working and every comparison below would pass over an empty set.
	printf 'check_base_namespace: FAIL — only %d member(s) parsed out of %s.\n' "$n_base" "$BASE" >&2
	printf '  The extraction is broken; a comparison against an empty namespace passes by default.\n' >&2
	exit 1
fi

# THE POPULATION, COUNTED INDEPENDENTLY OF THE SCAN. `head -1` is how a subclass is recognised below, and
# it is a per-file, SILENT exclusion: put a `@tool` line or a comment above `extends` and that file leaves
# the population with nothing said. A floor at zero would not notice, because it only refuses to report
# when it has lost ALL of the population, and the failure this file exists to catch arrives one layer at a
# time. `grep -l` does not care what line `extends` is on, so the true count is knowable exactly and the
# scan can be held to it BY NAME.
#
# THE PREDICATE IS ANCHORED. An unanchored `extends.*test_base\.gd` would match PROSE too -- a docstring
# mentioning "extends test_base.gd" in passing would put a non-subclass in the population. A statement of
# inheritance starts its line; a mention of it does not.
population="$(grep -rlE '^[[:space:]]*extends[[:space:]]+"?res://tests/test_base\.gd"?' \
	"$ROOT/tests" --include='*.gd' 2>/dev/null | grep -v "^$BASE$" | sort)"
n_pop=$(printf '%s\n' "$population" | grep -c .)

if [ "$#" -gt 0 ]; then
	targets="$*"
	expect=0                                   # an explicit file list is its own population
else
	targets="$population"
	expect="$n_pop"
fi

# ONE COMPARISON, CALLED BY THE CONTROL AND BY THE REAL SCAN. Written out once, so the control cannot
# become a copy of the detector that tests only itself.
collisions_in() {   # collisions_in <file> -> prints one line per collision, empty if clean
	_ci_f="$1"
	_ci_vars="$(sed -nE 's/^(static[[:space:]]+)?(var|const|signal|enum)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\3/p' "$_ci_f" | sort -u)"
	_ci_funcs="$(sed -nE 's/^[[:space:]]*(static[[:space:]]+)?func[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/p' "$_ci_f" | sort -u)"
	for _ci_n in $_ci_vars; do
		printf '%s\n%s\n' "$base_vars" "$base_funcs" | grep -qx "$_ci_n" \
			&& printf '  %s declares  var/const %s  — the base class already has it\n' "$_ci_f" "$_ci_n"
	done
	for _ci_n in $_ci_funcs; do
		printf '%s\n' "$base_vars" | grep -qx "$_ci_n" \
			&& printf '  %s declares  func %s  — the base class has a var/const of that name\n' "$_ci_f" "$_ci_n"
	done
}

# THE POSITIVE CONTROL. Built from a REAL base member rather than a made-up one, so it cannot pass while
# the base extraction above is broken.
_ctl_dir="$(mktemp -d)"
trap 'rm -rf "$_ctl_dir"' EXIT INT TERM
_ctl_member="$(printf '%s\n' "$base_vars" | grep -m1 .)"
if [ -z "$_ctl_member" ]; then
	printf 'check_base_namespace: FAIL — no base var/const parsed, so no control could be built.\n' >&2
	exit 1
fi
printf 'extends "res://tests/test_base.gd"\nvar %s: int = 0\n' "$_ctl_member" > "$_ctl_dir/bad.gd"
printf 'extends "res://tests/test_base.gd"\nvar _sf_ns_control_name_nobody_uses: int = 0\n' > "$_ctl_dir/clean.gd"
if [ -n "$(collisions_in "$_ctl_dir/bad.gd")" ]; then
	printf '  PASS  the detector finds a redeclared `%s` (positive control)\n' "$_ctl_member"
else
	printf 'check_base_namespace: FAIL — the detector did NOT flag a subclass redeclaring `%s`.\n' \
		"$_ctl_member" >&2
	printf '  The instrument is broken, so a clean verdict below would mean nothing. Not reporting one.\n' >&2
	exit 1
fi
if [ -z "$(collisions_in "$_ctl_dir/clean.gd")" ]; then
	printf '  PASS  ...and stays quiet on a subclass that redeclares nothing (negative control)\n'
else
	printf 'check_base_namespace: FAIL — the detector flagged a subclass that redeclares nothing.\n' >&2
	printf '  It fires on everything, so a red below would mean nothing either. Not reporting a verdict.\n' >&2
	exit 1
fi

scanned=0
bad=""
for f in $targets; do
	[ -f "$f" ] || continue
	[ "$f" = "$BASE" ] && continue
	head -1 "$f" | grep -q 'test_base\.gd' || continue
	scanned=$((scanned + 1))
	_hits="$(collisions_in "$f")"
	[ -n "$_hits" ] && bad="$bad
$_hits"
done

if [ "$scanned" -eq 0 ]; then
	printf 'check_base_namespace: FAIL — 0 subclasses found, so nothing was compared.\n' >&2
	printf '  There are around twenty in this tree; zero means the search, not the tree.\n' >&2
	exit 1
fi
if [ "$expect" -gt 0 ] && [ "$scanned" -ne "$expect" ]; then
	printf 'check_base_namespace: FAIL — scanned %d of the %d files that extend test_base.gd.\n' \
		"$scanned" "$expect" >&2
	printf '  The rest do not carry `extends` on line 1, so the scan skipped them SILENTLY and their\n' >&2
	printf '  members were never compared against the base:\n' >&2
	for f in $population; do
		head -1 "$f" | grep -q 'test_base\.gd' || printf '    %s\n' "$f" >&2
	done
	exit 1
fi

if [ -n "$bad" ]; then
	printf 'check_base_namespace: FAIL — a subclass redeclares a member of test_base.gd:%s\n' "$bad" >&2
	printf '\nGDScript rejects the SUBCLASS, not the base, so --check-only on the file you edited is\n' >&2
	printf 'clean and a suite you never opened stops loading. tools/run_gd_test.sh would score that\n' >&2
	printf 'as a parse failure only once that specific suite is run -- this check is instant and runs\n' >&2
	printf 'before the commit even lands.\n' >&2
	printf 'Rename the member in the suite, or do not add it to the base.\n' >&2
	exit 1
fi
printf 'check_base_namespace: PASS — %d of %d subclasses, none redeclares any of the %d base members\n' \
	"$scanned" "$n_pop" "$n_base"
exit 0
