#!/usr/bin/env bash
# NO COMMIT IN THIS REPOSITORY CARRIES AN assistant CO-AUTHOR TRAILER.
#
#   bash tools/check_trailers.sh
#
# `docs/DECISIONS.md` records this as a LOCKED rule: the sole author of every commit is the developer, and
# no Assistant/Vendor co-author line appears anywhere in the history. It was locked for months and 23
# commits carried the trailer anyway, because the rule lived in a document and the tooling that writes
# commits defaults to adding one. A rule enforced by remembering it is a rule enforced by nobody.
#
# WHY THIS EXISTS AS A HARNESS LAYER AND NOT ONLY AS A HOOK. The obvious guard is `.githooks/commit-msg`,
# and it is necessary but nowhere near sufficient: all work in this repo commits with
# `--no-verify` as a matter of habit, which is precisely the flag that skips it. A guard that the people it
# guards routinely walk past is decoration. This one runs inside the suite, so it fails the RUN rather than
# the commit, and there is no flag that skips the suite.
#
# It also catches what a hook structurally cannot: a trailer that arrives by a path other than a fresh
# commit — a rebase that replays an old message, a cherry-pick, a merge from a branch written before the
# rule, an amend. The hook guards the door; this counts what is in the room.
#
# Needs no Godot and no display. Runs in about a second.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
fails=0

# The forms worth refusing. `assistant-session` is here because the same tooling that adds the co-author line
# also offers a session-URL trailer, and a rule that named only one of them would be a rule about a string.
PATTERN='^[[:space:]]*(co-authored-by:.*(assistant|vendor)|assistant-session:|generated with \[assistant)'

check() {  # check <ok:0|1> <label>
	if [ "$1" -eq 0 ]; then
		echo "  PASS  $2"
	else
		echo "  FAIL  $2" >&2
		fails=$((fails + 1))
	fi
}

echo "== no commit in this repository carries an assistant co-author trailer =="

# --- THE DETECTOR HAS TO WORK, and that is not free ---
# A POSITIVE CONTROL, run every time rather than once when the file was written. Everything below is an
# assertion that a search found NOTHING, and the failure mode of such an assertion is silence: a pattern
# that stopped matching — a typo, a changed grep, a locale that broke the character class — reports a clean
# history forever and reports it in exactly the words a clean history produces. So feed the detector a
# message that MUST match before trusting it about messages that must not.
probe='fix(thing): a message that must trip the detector

Co-Authored-By: Assistant Opus 5 (1M context) <noreply@vendor.com>'
if printf '%s\n' "$probe" | grep -qiE "$PATTERN"; then
	check 0 "the detector fires on a known-bad message (positive control)"
else
	check 1 "the detector fires on a known-bad message (positive control) — IT DOES NOT, so every clean" \
		"verdict below is meaningless and this run proves nothing about the history"
	echo "check_trailers: FAIL — the instrument is broken; not reporting a verdict on the history" >&2
	exit 1
fi
printf '%s\n' "a message with no trailer at all" | grep -qiE "$PATTERN"
[ $? -ne 0 ]; check $? "...and does NOT fire on a clean one (negative control)"

# --- THE SCAN HAS TO HAVE SOMETHING TO SCAN ---
# A shallow clone is the vacuity trap here and it is not hypothetical: `actions/checkout` fetches depth 1 by
# default, so this layer would run in CI against ONE commit, find nothing, and print the same green line it
# prints over a clean 452-commit history. The CI workflow sets fetch-depth: 0 for exactly this reason, and
# this assertion is what notices if that is ever removed.
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
	check 1 "the repository is not a shallow clone — IT IS, so the scan below sees a truncated history" \
		"and cannot speak for the commits it cannot see (set fetch-depth: 0)"
	echo "check_trailers: FAIL — shallow clone; the history was not scanned" >&2
	exit 1
fi
check 0 "the repository is not a shallow clone, so the whole history is visible"

total="$(git rev-list --count --all)"
[ "$total" -ge 100 ]; check $? "$total commits were scanned (floor 100 — a scan of a handful is not a sweep)"

# --- THE GUARD ON THE ORDINARY PATH HAS TO BE INSTALLED ---
# .githooks/commit-msg is tracked, which makes it PRESENT in every clone and ACTIVE in none of them: git
# only runs it if core.hooksPath points there, and that is a per-clone setting nobody remembers. So a repo
# can carry a perfect hook and enforce nothing, which is worse than carrying none, because the file in the
# tree reads as protection. Assert the wiring, not the file.
[ -x ".githooks/commit-msg" ]; check $? "the tracked commit-msg hook exists and is executable"
# The WIRING is a property of a developer's clone, not of a build agent — nothing commits from CI, so
# asserting it there would test the checkout step rather than the rule. Stood down out loud rather than
# skipped silently: an assertion that quietly evaporates in one environment is how a guard becomes a
# formality in the environment that matters.
if [ -n "${CI:-}" ]; then
	echo "  SKIP  core.hooksPath wiring was NOT asserted — nothing commits from CI, so it proves nothing here"
else
	hooks_path="$(git config --get core.hooksPath || true)"
	[ "$hooks_path" = ".githooks" ]; check $? \
		"core.hooksPath is wired to the tracked hooks ('${hooks_path:-unset}') — run: git config core.hooksPath .githooks"
fi

# --- AND NOW THE ACTUAL CLAIM, OVER EVERY REF ---
# `--all`, not HEAD. There are thirteen worktrees on this repository and a branch written before the rule
# carries the trailer straight back in the moment it is merged. Scanning only the current branch would call
# the history clean while the reinfection sat one merge away, which is the shape of half the defects in
# the audit notes: a gauge whose population is smaller than the claim it is used to make.

# THE ONE EXEMPTION, named rather than pattern-matched. `pre-trailer-strip` is the pre-rewrite history,
# kept deliberately so the strip is reversible; it carries all 23 original messages BY DESIGN and always
# will. the trailer-strip map is the old-sha -> new-sha mapping that makes it usable.
#
# Written as an exact ref name and asserted to be the ONLY exemption, because an allowlist that can grow
# quietly is how a guard becomes a formality. If a second ref ever needs exempting, that is a decision
# somebody makes on purpose, in this file, in a diff.
EXEMPT='refs/tags/pre-trailer-strip'
dirty=""
n_exempt=0
for ref in $(git for-each-ref --format='%(refname)' refs/heads refs/remotes refs/tags); do
	n="$(git log --format='%B' "$ref" 2>/dev/null | grep -icE "$PATTERN")"
	[ "$n" -eq 0 ] && continue
	if [ "$ref" = "$EXEMPT" ]; then
		n_exempt=$((n_exempt + 1))
		continue
	fi
	dirty="$dirty  $ref ($n)"$'\n'
done
[ "$n_exempt" -le 1 ]; check $? "at most one ref is exempt from the scan (found $n_exempt)"
hits="$(printf '%s' "$dirty" | grep -c . || true)"
[ "$hits" -eq 0 ]; check $? "no ref outside the named backup carries an assistant trailer ($hits ref(s) do)"
if [ "$hits" -ne 0 ]; then
	echo "  REINFECTION RISK — these refs still carry it, and a merge brings it straight back:" >&2
	printf '%s' "$dirty" >&2
fi

# The rule is about AUTHORSHIP, not only about a string in a message, and the trailer is the symptom rather
# than the disease. A commit authored by anyone other than the developer states the same thing the trailer
# states, in a field no message filter would ever look at.
authors="$(git log --format='%ae' --all | sort -u | grep -icE "vendor|assistant" || true)"
[ "$authors" -eq 0 ]; check $? "no commit is AUTHORED by an assistant address (found $authors distinct)"

echo
if [ "$fails" -eq 0 ]; then
	echo "check_trailers: PASS — $total commits, sole author is the developer, no trailers"
	exit 0
fi
echo "check_trailers: FAIL ($fails)" >&2
exit 1
