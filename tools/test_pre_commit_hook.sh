#!/usr/bin/env bash
# Mutation test for `.githooks/pre-commit`. `docs/DECISIONS_LEDGER.md` D0320.
#
#   bash tools/test_pre_commit_hook.sh
#
# WHY THIS FILE IN PARTICULAR. `.githooks/pre-commit` has the worst track record in the repository and
# its own comments record it: the base-class namespace gate **silently no-op'd for 119 commits**
# (D0117/D0119), and the identity gate was "dead twice over" -- once below the final `exit 0`, and then
# still dead because the mojibake block opened with `[ -z "$files" ] && exit 0`, so a commit staging none
# of the types THAT gate scans returned before reaching anything after it.
#
# D0319 added a formatter gate at the bottom of that same file and restructured the early return to let
# it be reached. That correctness rests entirely on statement ORDER and on which extensions each block
# globs -- properties no other test in this repository looks at, and exactly the shape that has now gone
# quiet here twice. `tools/test_commit_msg_hook.sh` does this job for `commit-msg`; nothing did it for
# `pre-commit`.
#
# THE CASE THAT MATTERS MOST is row 1. The mojibake gate globs `.gd .md .sh .cfg .godot`; the formatter
# globs `.gd .py .sh .yml .yaml`. **`.py` and `.yaml` are in the second set and not the first**, so a
# commit staging only Python is precisely the commit the old early return swallowed. If that row ever
# goes green-by-skipping again, this says so.
#
# NEVER TOUCHES THE REAL INDEX. Every case runs against a throwaway `GIT_INDEX_FILE`, so an interrupted
# run cannot leave the caller's staging area modified -- which matters because this is routinely run
# while someone has work staged.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

HOOK=".githooks/pre-commit"
[ -r "$HOOK" ] || { echo "test_pre_commit_hook: FAIL - no hook at $HOOK" >&2; exit 1; }

# NOT a dot-directory. The first draft used `.hook_probe_tmp/` and every formatter row came back exit 0
# -- the formatter excludes hidden directories from its scope, so it answered VOID (nothing in scope) and
# the hook correctly passed. Four rows failed while the hook was blameless: the FIXTURE was out of the
# subject's population. A scratch path has to live where the tool under test can actually see it.
SCRATCH="tools/hook_probe_tmp"
INDEX_DIR="$(mktemp -d)"
cleanup() { rm -rf "$SCRATCH" "$INDEX_DIR"; [ "${RESTORE_EMAIL:-0}" = "1" ] && git config --local --unset user.email 2>/dev/null; return 0; }
trap cleanup EXIT
rm -rf "$SCRATCH"; mkdir -p "$SCRATCH"

# THE IDENTITY GATE RUNS FIRST AND WOULD REFUSE EVERY ROW. It compares the effective author/committer
# against `git config --local user.email`, and a fresh CI checkout has no LOCAL user.email at all -- so
# without this the hook exits 1 on every case, rows 1/2/4/6/8 would go green for the wrong reason, and
# the three rows expecting 0 would fail with a message about identity. A uniformly-refusing hook is the
# same shape as a uniformly-passing one: it makes the rows stop discriminating.
#
# So the identity precondition is ESTABLISHED rather than assumed, and restored on exit.
HAD_EMAIL="$(git config --local user.email 2>/dev/null || true)"
if [ -z "$HAD_EMAIL" ]; then
	git config --local user.email "pre-commit-hook-test@invalid"
	RESTORE_EMAIL=1
else
	RESTORE_EMAIL=0
fi
export GIT_AUTHOR_EMAIL="$(git config --local user.email)"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-hook test}"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"

fails=0
check() {  # check <ok:0|1> <label>
	if [ "$1" -eq 0 ]; then echo "  PASS  $2"; else echo "  FAIL  $2" >&2; fails=$((fails + 1)); fi
}

## Runs the hook with ONLY the named scratch files staged, in a private index. Prints its exit code.
run_hook() {  # run_hook <path>...
	local idx="$INDEX_DIR/index"
	rm -f "$idx"
	GIT_INDEX_FILE="$idx" git read-tree HEAD 2>/dev/null
	GIT_INDEX_FILE="$idx" git add -f "$@" 2>/dev/null
	GIT_INDEX_FILE="$idx" sh "$HOOK" >/dev/null 2>&1
	echo $?
}

expect() {  # expect <want-exit> <label> <path>...
	local want="$1" label="$2"; shift 2
	local got; got="$(run_hook "$@")"
	check "$([ "$got" = "$want" ] && echo 0 || echo 1)" "$label (exit $got, want $want)"
}

echo "test_pre_commit_hook: driving $HOOK against a private index"

# Canonical fixtures: exactly what the formatter would leave behind.
printf 'x = 1\ny = 2\n'            > "$SCRATCH/clean.py"
printf 'extends Node\n'            > "$SCRATCH/clean.gd"
printf 'a: 1\n'                    > "$SCRATCH/clean.yaml"
printf '# notes\n'                 > "$SCRATCH/clean.md"
# Non-canonical: a 3+ blank run, which the `blank-run` rule collapses.
printf 'x = 1\n\n\n\n\ny = 2\n'    > "$SCRATCH/dirty.py"
printf 'extends Node\n\n\n\n\nfunc f() -> void:\n\tpass\n' > "$SCRATCH/dirty.gd"
printf 'a: 1   \n'                 > "$SCRATCH/dirty.yaml"   # out of yaml scope under tools/ -- see the row below
printf 'x = 1   \ny = 2\n'        > "$SCRATCH/trailing.py"
# U+0085, a C1 control character -- one round of the Latin-1/UTF-8 confusion always produces these.
printf '# notes \302\205 here\n'   > "$SCRATCH/mojibake.md"

# --- 1-3. THE D0319 REACHABILITY CASE. These extensions are in the FORMATTER's scope and NOT in the
# mojibake gate's, so before the restructure the hook returned 0 without ever reaching the formatter.
expect 1 "a non-canonical .py staged ALONE is refused -- the extension the old early return skipped" \
	"$SCRATCH/dirty.py"
# A SECOND, INDEPENDENT RULE on the same extension -- so row 1 cannot be passing because one rule
# happens to fire. `blank-run` above, `trailing-whitespace` here.
expect 1 "a .py with only TRAILING WHITESPACE is refused -- a second rule, not a second copy of row 1" \
	"$SCRATCH/trailing.py"

# THE SCOPE BOUNDARY, asserted rather than assumed. `.yml`/`.yaml` are in the formatter's scope ONLY
# under `.github/workflows/` and `data/` (formatter.py YAML_DIRS), so a yaml staged anywhere else is
# VOID -- and the hook must PASS on it. A hook that refused what its own formatter cannot judge would
# block commits on files nobody claims to check. This row is why the yaml fixture is not a violation
# fixture: my first draft asserted a refusal here and failed, and the FIXTURE was out of the subject's
# population, not the hook wrong.
expect 0 "a non-canonical .yaml OUTSIDE the yaml scope passes -- VOID is not a violation" \
	"$SCRATCH/dirty.yaml"

# --- 4. An extension in BOTH sets still reaches the formatter (order, not just reachability).
expect 1 "a non-canonical .gd is refused" "$SCRATCH/dirty.gd"

# --- 4. THE CONTROL. Without it every row above is satisfied by a hook that refuses everything.
expect 0 "canonical .gd + .py + .yaml + .md together PASS -- the hook is not always-refuse" \
	"$SCRATCH/clean.gd" "$SCRATCH/clean.py" "$SCRATCH/clean.yaml" "$SCRATCH/clean.md"

# --- 5. The mojibake gate still fires, and on a type the formatter does not scan. A restructure that
# reached the formatter by DISABLING the block above it would pass rows 1-4 and fail here.
expect 1 "mojibake in a .md is still refused -- the older gate survived the restructure" \
	"$SCRATCH/mojibake.md"

# --- 6. A .md alone is in NEITHER scope and must pass: the formatter's exit 2 (VOID, nothing in scope)
# is not a failure. A hook treating "nothing to check" as a refusal would block every docs-only commit.
expect 0 "a clean .md ALONE passes -- 'nothing in scope' is not a violation" "$SCRATCH/clean.md"

# --- 7. One bad file among good ones still refuses: the gate reports on the POPULATION, not the first
# file it happens to look at.
expect 1 "one non-canonical file among canonical ones is refused" \
	"$SCRATCH/clean.gd" "$SCRATCH/clean.md" "$SCRATCH/dirty.py"

if [ "$fails" -eq 0 ]; then
	echo "test_pre_commit_hook: PASS."
	exit 0
fi
echo "test_pre_commit_hook: FAIL -- $fails case(s)." >&2
exit 1
