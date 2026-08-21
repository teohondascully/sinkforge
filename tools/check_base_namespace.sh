#!/bin/sh
# NO LAYER MAY REDECLARE A MEMBER OF ITS BASE CLASS, and the reason this is a separate file is that the
# failure it catches is invisible where you would look for it.
#
# WHAT HAPPENED. `_asserted()` was added to `tools/check_base.gd`. `check_hint_gate.gd`, untouched for
# weeks, already had `var _asserted: int = 0`. GDScript rejects the SUBCLASS -- "the member already exists
# in parent class" -- so:
#
#   `godot --check-only` on the EDITED file was clean; the broken file was one nobody had opened
#   `godot --script` exits 0 when a script fails to load, so the RUNNER scored it 105 PASS / 0 FAIL
#   only `tools/harness_verdict.sh` caught it, by reading the log rather than the code, after 275 seconds
#
# A base class owns the namespace of every subclass, and there are 103 of them here. This is a pure-text
# check over that namespace: no engine, no boot, instant, and it runs from the pre-commit hook so the cost
# of the mistake is a refused commit rather than a sweep.
#
# WHAT GDSCRIPT ACTUALLY PERMITS, because the rule is not "no repeated names":
#
#   func over func     LEGAL. That is an override, and layers do it.
#   var/const over ANY base member    ILLEGAL.
#   func over a base var/const        ILLEGAL.
#
#   sh tools/check_base_namespace.sh            # every subclass in the tree
#   sh tools/check_base_namespace.sh a.gd b.gd  # only these
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/tools/check_base.gd"

if [ ! -r "$BASE" ]; then
	printf 'check_base_namespace: FAIL — %s is not readable, so the base namespace is unknown.\n' "$BASE" >&2
	printf '  An unreadable input is not an empty one. Nothing was compared.\n' >&2
	exit 1
fi

# `signal` is in here because it declares a member too, and `enum` because a named enum does.
base_vars="$(sed -nE 's/^[[:space:]]*(static[[:space:]]+)?(var|const|signal|enum)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\3/p' "$BASE" | sort -u)"
base_funcs="$(sed -nE 's/^[[:space:]]*(static[[:space:]]+)?func[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/p' "$BASE" | sort -u)"
n_base=$(printf '%s\n%s\n' "$base_vars" "$base_funcs" | grep -c .)
if [ "$n_base" -lt 5 ]; then
	# A REGEX THAT MATCHED ALMOST NOTHING IS A BROKEN INSTRUMENT, NOT A CLEAN BASE CLASS. check_base.gd has
	# had at least seven members its whole life; a handful means the extraction stopped working and every
	# comparison below would pass over an empty set.
	printf 'check_base_namespace: FAIL — only %d member(s) parsed out of %s.\n' "$n_base" "$BASE" >&2
	printf '  The extraction is broken; a comparison against an empty namespace passes by default.\n' >&2
	exit 1
fi

# THE POPULATION, COUNTED INDEPENDENTLY OF THE SCAN. `head -1` is how a subclass is recognised below, and
# it is a per-file, SILENT exclusion: put a `@tool` line or a comment above `extends` and that file leaves
# the population with nothing said. A floor at zero would not notice, because it only refuses to report
# when it has lost ALL of the population, and the failure this file exists to catch arrives one layer at a
# time. `grep -l` over the same two directories does not care what line `extends` is on, so the true count
# is knowable exactly and the scan can be held to it BY NAME. Found in review, and it is M5's own lesson --
# a floor that never binds is a licence with extra syntax -- reappearing in a guard written to apply it.
#
# THE PREDICATE IS ANCHORED, AND THE UNANCHORED ONE WAS TRIED FIRST AND WAS WRONG BY ONE. `extends.*
# check_base\.gd` matches PROSE: `tools/frontier_corpus.gd` extends SceneTree and says so in its docstring
# -- "it extends `SceneTree` rather than `tools/check_base.gd`" -- so the loose form put a non-subclass in
# the population and the new floor failed on a clean tree. The two errors are mirrors of each other and
# both were live in the same guard: `head -1` is too NARROW (misses a real subclass under an annotation),
# an unanchored grep is too BROAD (finds the class name in a comment). A statement of inheritance starts
# its line; a mention of it does not.
population="$(grep -rlE '^[[:space:]]*extends[[:space:]]+"?res://tools/check_base\.gd"?' \
	"$ROOT/tools" "$ROOT/tests" --include='*.gd' 2>/dev/null | grep -v "^$BASE$" | sort)"
n_pop=$(printf '%s\n' "$population" | grep -c .)

if [ "$#" -gt 0 ]; then
	targets="$*"
	expect=0                                   # an explicit file list is its own population
else
	targets="$population"
	expect="$n_pop"
fi

scanned=0
bad=""
for f in $targets; do
	[ -f "$f" ] || continue
	[ "$f" = "$BASE" ] && continue
	head -1 "$f" | grep -q 'check_base\.gd' || continue
	scanned=$((scanned + 1))
	sub_vars="$(sed -nE 's/^[[:space:]]*(static[[:space:]]+)?(var|const|signal|enum)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\3/p' "$f" | sort -u)"
	sub_funcs="$(sed -nE 's/^[[:space:]]*(static[[:space:]]+)?func[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/p' "$f" | sort -u)"
	for n in $sub_vars; do
		printf '%s\n%s\n' "$base_vars" "$base_funcs" | grep -qx "$n" \
			&& bad="$bad
  $f declares  var/const $n  — the base class already has it"
	done
	for n in $sub_funcs; do
		printf '%s\n' "$base_vars" | grep -qx "$n" \
			&& bad="$bad
  $f declares  func $n  — the base class has a var/const of that name"
	done
done

if [ "$scanned" -eq 0 ]; then
	printf 'check_base_namespace: FAIL — 0 subclasses found, so nothing was compared.\n' >&2
	printf '  There are around a hundred in this tree; zero means the search, not the tree.\n' >&2
	exit 1
fi
if [ "$expect" -gt 0 ] && [ "$scanned" -ne "$expect" ]; then
	printf 'check_base_namespace: FAIL — scanned %d of the %d files that extend check_base.gd.\n' \
		"$scanned" "$expect" >&2
	printf '  The rest do not carry `extends` on line 1, so the scan skipped them SILENTLY and their\n' >&2
	printf '  members were never compared against the base:\n' >&2
	for f in $population; do
		head -1 "$f" | grep -q 'check_base\.gd' || printf '    %s\n' "$f" >&2
	done
	exit 1
fi

if [ -n "$bad" ]; then
	printf 'check_base_namespace: FAIL — a subclass redeclares a member of check_base.gd:%s\n' "$bad" >&2
	printf '\nGDScript rejects the SUBCLASS, not the base, so --check-only on the file you edited is\n' >&2
	printf 'clean and a layer you never opened stops loading. The runner scores that as a PASS.\n' >&2
	printf 'Rename the member in the layer, or do not add it to the base.\n' >&2
	exit 1
fi
printf 'check_base_namespace: PASS — %d of %d subclasses, none redeclares any of the %d base members\n' \
	"$scanned" "$n_pop" "$n_base"
exit 0
