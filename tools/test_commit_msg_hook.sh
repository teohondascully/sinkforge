#!/usr/bin/env bash
# Mutation test for .githooks/commit-msg's two rules (D0151, queue Part D3):
#   1. touching core/ or sim/ requires a NEW "## D0NNN" header ADDED to docs/DECISIONS_LEDGER.md in the
#      same commit -- editing INSIDE an existing entry (a rename, a typo fix) must NOT satisfy this.
#   2. the trailer-pattern refusal also fires on assisted-by:/reviewed-by:/generated-by:, not just
#      co-authored-by:.
#
#   bash tools/test_commit_msg_hook.sh
#
# Builds a disposable scratch git repo per case (matching tools/layer_lint/test_check_untracked_files.py's
# own pattern) and invokes .githooks/commit-msg directly against staged changes -- never touches this
# repository's own history or its own docs/DECISIONS_LEDGER.md.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/.githooks/commit-msg"
fails=0

check() {  # check <ok:0|1> <label>
	if [ "$1" -eq 0 ]; then
		echo "  PASS  $2"
	else
		echo "  FAIL  $2" >&2
		fails=$((fails + 1))
	fi
}

# run_hook <scratch_dir> <message>  -- stages nothing itself; caller stages first. Returns the hook's exit.
run_hook() {
	local dir="$1" message="$2" msgfile
	msgfile="$(mktemp)"
	printf '%s\n' "$message" > "$msgfile"
	( cd "$dir" && bash "$HOOK" "$msgfile" ) > /dev/null 2>&1
	local code=$?
	rm -f "$msgfile"
	return $code
}

init_scratch() {  # init_scratch <dir> -- a minimal repo with core/, docs/DECISIONS_LEDGER.md, one entry
	local dir="$1"
	git init -q "$dir"
	( cd "$dir" \
		&& git config user.email "scratch@test" \
		&& git config user.name "scratch" \
		&& mkdir -p core docs \
		&& echo "func foo(): pass" > core/foo.gd \
		&& printf '# Ledger\n\n## D0001 . initial entry\n\nsomething decided.\n' > docs/DECISIONS_LEDGER.md \
		&& git add -A && git commit -q -m "initial" )
}

echo "== .githooks/commit-msg: mutation tests (D0151) =="

# --- 1. core/ touched, ledger edited INSIDE the existing entry only (rename), no new header: REFUSED ---
d1="$(mktemp -d)"
init_scratch "$d1"
( cd "$d1" \
	&& sed -i.bak 's/initial entry/renamed entry/' docs/DECISIONS_LEDGER.md && rm -f docs/DECISIONS_LEDGER.md.bak \
	&& echo "func bar(): pass" >> core/foo.gd \
	&& git add -A )
run_hook "$d1" "fix(core): a change with no new ledger header"
[ $? -ne 0 ]
check $? "core/ touched + ledger edited but no NEW header + no trailer: REFUSED (exit 1)"
rm -rf "$d1"

# --- 2. core/ touched, ledger gets a genuinely NEW "## D0NNN" header: ALLOWED ---
d2="$(mktemp -d)"
init_scratch "$d2"
( cd "$d2" \
	&& printf '\n## D0002 . a real new decision\n\nsomething else decided.\n' >> docs/DECISIONS_LEDGER.md \
	&& echo "func bar(): pass" >> core/foo.gd \
	&& git add -A )
run_hook "$d2" "fix(core): a change with a real new ledger entry"
[ $? -eq 0 ]
check $? "core/ touched + a genuinely NEW ## D0NNN header: ALLOWED (exit 0)"
rm -rf "$d2"

# --- 3. core/ touched, ledger untouched, message carries No-Ledger-Entry trailer: ALLOWED ---
d3="$(mktemp -d)"
init_scratch "$d3"
( cd "$d3" && echo "func bar(): pass" >> core/foo.gd && git add -A )
run_hook "$d3" $'fix(core): a rename, no judgment call\n\nNo-Ledger-Entry: pure rename, nothing decided'
[ $? -eq 0 ]
check $? "core/ touched, no ledger entry, but No-Ledger-Entry trailer present: ALLOWED (exit 0)"
rm -rf "$d3"

# --- 4. negative control: no core/sim touched at all -- the rule does not apply regardless of the ledger ---
d4="$(mktemp -d)"
init_scratch "$d4"
( cd "$d4" && echo "some prose" >> docs/OTHER.md 2>/dev/null; echo "some prose" > docs/OTHER.md && git add -A )
run_hook "$d4" "docs: an unrelated doc change"
[ $? -eq 0 ]
check $? "negative control: no core/sim/ touched, rule does not apply: ALLOWED (exit 0)"
rm -rf "$d4"

# --- 5-7. trailer pattern: the three new forms (D0151) each REFUSE a commit outright ---
d5="$(mktemp -d)"
init_scratch "$d5"
( cd "$d5" && echo "some prose" > docs/OTHER.md && git add -A )
for form in "Assisted-By: Some Tool <noreply@example.invalid>" \
            "Reviewed-By: Some Tool <noreply@example.invalid>" \
            "Generated-By: Some Tool <noreply@example.invalid>"; do
	run_hook "$d5" "docs: a change"$'\n\n'"$form"
	[ $? -ne 0 ]
	check $? "trailer '${form%%:*}:' REFUSED even with no core/sim change (D0151)"
done
rm -rf "$d5"

# --- 8. negative control: a clean message with no trailer, no core/sim change: ALLOWED ---
d8="$(mktemp -d)"
init_scratch "$d8"
( cd "$d8" && echo "some prose" > docs/OTHER.md && git add -A )
run_hook "$d8" "docs: a clean, ordinary commit message"
[ $? -eq 0 ]
check $? "negative control: a clean message with no trailer: ALLOWED (exit 0)"
rm -rf "$d8"

echo
if [ "$fails" -eq 0 ]; then
	echo "test_commit_msg_hook: PASS - all cases observed correctly"
	exit 0
fi
echo "test_commit_msg_hook: FAIL ($fails)" >&2
exit 1
