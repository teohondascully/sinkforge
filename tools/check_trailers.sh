#!/usr/bin/env bash
# every commit in this repository is authored by one person and carries no co-author trailer.
#
#   bash tools/check_trailers.sh
#
# `docs/DECISIONS.md` records this as a locked rule. it was locked for months and commits carried trailers
# anyway, because the rule lived in a document while the tooling that writes commits adds them by default.
# a rule enforced by remembering it is a rule enforced by nobody.
#
# why this is a harness layer and not only a hook. the obvious guard is `.githooks/commit-msg`, and it is
# necessary but nowhere near sufficient: committing with `--no-verify` is routine here, and that is exactly
# the flag that skips it. a guard that gets walked past as a matter of habit is decoration. this one runs
# inside the suite, so it fails the run rather than the commit, and no flag skips the suite.
#
# it also catches what a hook structurally cannot: a trailer arriving by a path other than a fresh commit,
# such as a rebase replaying an old message, a cherry-pick, an amend, or a merge from a branch written
# before the rule. the hook guards the door; this counts what is in the room.
#
# needs no godot and no display. runs in about a second.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
fails=0

# the forms worth refusing, kept deliberately generic. naming one tool's trailers would make this a rule
# about a string rather than about authorship, and the next tool would walk straight through it. this is
# the same pattern `.githooks/commit-msg` refuses, and the two must not drift apart.
# D0151: assisted-by/reviewed-by/generated-by added -- the same class of trailer under a label
# co-authored-by does not cover.
PATTERN='^[[:space:]]*(co-authored-by:|assisted-by:|reviewed-by:|generated-by:|[a-z][a-z-]*-session:|generated with \[)'

check() {  # check <ok:0|1> <label>
	if [ "$1" -eq 0 ]; then
		echo "  PASS  $2"
	else
		echo "  FAIL  $2" >&2
		fails=$((fails + 1))
	fi
}

echo "== authorship: one author, no co-author or tool-generation trailers =="

# --- the detector has to work, and that is not free ---
# a positive control, run every time rather than once when the file was written. everything below asserts
# that a search found NOTHING, and the failure mode of such an assertion is silence: a pattern that stopped
# matching, through a typo or a changed grep or a locale that broke the character class, reports a clean
# history forever and reports it in exactly the words a clean history produces. so feed the detector a
# message that must match before trusting it about messages that must not.
probe='fix(thing): a message that must trip the detector

Co-Authored-By: Some Tool <noreply@example.invalid>'
if printf '%s\n' "$probe" | grep -qiE "$PATTERN"; then
	check 0 "the detector fires on a known-bad message (positive control)"
else
	check 1 "the detector fires on a known-bad message (positive control) -- IT DOES NOT, so every clean" \
		"verdict below is meaningless and this run proves nothing about the history"
	echo "check_trailers: FAIL - the instrument is broken; not reporting a verdict on the history" >&2
	exit 1
fi
printf '%s\n' "a message with no trailer at all" | grep -qiE "$PATTERN"
[ $? -ne 0 ]; check $? "...and does NOT fire on a clean one (negative control)"

# D0151: the three added forms each get their own positive control -- a pattern with an alternation that
# LOOKS like it covers a form but doesn't (a missing colon, a wrong anchor) reports the identical clean
# verdict a genuinely clean history does, so each addition is proven to fire before being trusted.
for form in "Assisted-By: Some Tool <noreply@example.invalid>" \
            "Reviewed-By: Some Tool <noreply@example.invalid>" \
            "Generated-By: Some Tool <noreply@example.invalid>"; do
	printf '%s\n' "$form" | grep -qiE "$PATTERN"
	check $? "the detector fires on '${form%%:*}:' (D0151 positive control)"
done

# --- the scan has to have something to scan ---
# a shallow clone is the vacuity trap here and it is not hypothetical: `actions/checkout` fetches depth 1 by
# default, so this layer would run in CI against one commit, find nothing, and print the same green line it
# prints over a clean thousand-commit history. the workflow sets fetch-depth: 0 for exactly this reason, and
# this assertion is what notices if that is ever removed.
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
	check 1 "the repository is not a shallow clone -- IT IS, so the scan below sees a truncated history" \
		"and cannot speak for the commits it cannot see (set fetch-depth: 0)"
	echo "check_trailers: FAIL - shallow clone; the history was not scanned" >&2
	exit 1
fi
check 0 "the repository is not a shallow clone, so the whole history is visible"

total="$(git rev-list --count --all)"
[ "$total" -ge 100 ]; check $? "$total commits were scanned (floor 100 - a scan of a handful is not a sweep)"

# --- the guard on the ordinary path has to be installed ---
# .githooks/commit-msg is tracked, which makes it present in every clone and active in none of them: git
# only runs it when core.hooksPath points there, and that is a per-clone setting nobody remembers. so a repo
# can carry a perfect hook and enforce nothing, which is worse than carrying none, because the file in the
# tree reads as protection. assert the wiring, not the file.
[ -x ".githooks/commit-msg" ]; check $? "the tracked commit-msg hook exists and is executable"
# the wiring is a property of a developer's clone, not of a build machine - nothing commits from CI, so
# asserting it there would test the checkout step rather than the rule. stood down out loud rather than
# skipped silently: an assertion that quietly evaporates in one environment is how a guard becomes a
# formality in the environment that matters.
if [ -n "${CI:-}" ]; then
	echo "  SKIP  core.hooksPath wiring was NOT asserted - nothing commits from CI, so it proves nothing here"
else
	# compare RESOLVED directories, not the configured string. an absolute hooksPath is not a mistake here,
	# it is the correct setting once worktrees exist: a relative `.githooks` resolves against whichever
	# worktree is running the hook, so only the main checkout would be guarded. this assertion used to
	# demand the literal string and failed on a clone that was wired correctly.
	hooks_path="$(git config --get core.hooksPath || true)"
	want="$(cd "$ROOT/.githooks" 2>/dev/null && pwd || echo unresolvable)"
	got="unset"
	if [ -n "$hooks_path" ]; then
		case "$hooks_path" in
			/*) got="$(cd "$hooks_path" 2>/dev/null && pwd || echo "$hooks_path")" ;;
			*)  got="$(cd "$ROOT/$hooks_path" 2>/dev/null && pwd || echo "$hooks_path")" ;;
		esac
	fi
	[ "$got" = "$want" ] && [ "$want" != "unresolvable" ]; check $? \
		"core.hooksPath resolves to the tracked hooks ('${hooks_path:-unset}') - run: git config core.hooksPath .githooks"
fi

# --- and now the actual claim, over every ref ---
# `--all`, not HEAD. this repository is worked in several worktrees at once, and a branch written before the
# rule carries a trailer straight back the moment it merges. scanning only the current branch would call the
# history clean while the reinfection sat one merge away: a gauge whose population is smaller than the claim
# it is used to make.
#
# no exemptions. there was one for a while, for a backup ref that held the original messages by design, and
# closing it was right: zero commits anywhere, which had made the safety net the last thing carrying the
# thing it was protecting. the absence of an allowlist is the point, because an allowlist that can grow
# quietly is how a guard becomes a formality, and the cheapest way to stop one growing is not to have one.
#
# counts commits, not matching lines, and lets git do the counting. `git log --format=%B | grep -c` counts
# LINES, so a message carrying two trailers reports 2 where the sentence around the number says commits.
# `--grep` matches per commit in C, which is the right unit and fast enough to sweep every ref, where a
# shell loop over every sha per ref took long enough to time out.
dirty=""
for ref in $(git for-each-ref --format='%(refname)' refs/heads refs/remotes refs/tags); do
	n="$(git log -E -i --format='%H' \
		--grep='^[[:space:]]*co-authored-by:' \
		--grep='^[[:space:]]*assisted-by:' \
		--grep='^[[:space:]]*reviewed-by:' \
		--grep='^[[:space:]]*generated-by:' \
		--grep='^[[:space:]]*[a-z][a-z-]*-session:' \
		--grep='generated with \[' "$ref" 2>/dev/null | wc -l | tr -d ' ')"
	[ "$n" -eq 0 ] && continue
	dirty="$dirty  $ref ($n commit(s))"$'\n'
done
hits="$(printf '%s' "$dirty" | grep -c . || true)"
[ "$hits" -eq 0 ]; check $? "no ref anywhere carries a co-author or tool-generation trailer ($hits ref(s) do)"
if [ "$hits" -ne 0 ]; then
	echo "  REINFECTION RISK - these refs still carry it, and a merge brings it straight back:" >&2
	printf '%s' "$dirty" >&2
fi

# the rule is about authorship, not only about a string in a message, and a trailer is the symptom rather
# than the disease. a commit authored by a second identity states the same thing the trailer states, in a
# field no message filter would ever look at. counting DISTINCT identities rather than matching known-bad
# ones means an identity nobody thought to look for still fails this.
authors="$(git log --format='%ae' --all | sort -u | wc -l | tr -d ' ')"
[ "$authors" -eq 1 ]; check $? "every commit shares one author identity ($authors distinct found)"
committers="$(git log --format='%ce' --all | sort -u | wc -l | tr -d ' ')"
[ "$committers" -eq 1 ]; check $? "every commit shares one committer identity ($committers distinct found)"
if [ "$authors" -ne 1 ] || [ "$committers" -ne 1 ]; then
	echo "  identities present:" >&2
	git log --format='%ae%n%ce' --all | sort -u | sed 's/^/    /' >&2
fi

echo
if [ "$fails" -eq 0 ]; then
	echo "check_trailers: PASS - $total commits, one author, no trailers"
	exit 0
fi
echo "check_trailers: FAIL ($fails)" >&2
exit 1
