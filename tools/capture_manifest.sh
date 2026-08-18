#!/usr/bin/env bash
# WHAT BUILD IS THIS A PICTURE OF?
#
#   bash tools/capture_manifest.sh            # rewrite docs/CAPTURE_MANIFEST.md
#   bash tools/capture_manifest.sh --check    # fail if the tracked manifest is out of date
#
# The "Sees" tier hands a zero-context vision agent the tracked `_moment_*.png` and asks what a first-time
# player would see. Forty-eight undated PNGs cannot answer the one question that decides whether their
# verdict means anything: WHICH BUILD IS THIS. Tonight 41 of them came from one commit and 7 from another
# ten hours and one shader later, and nothing about looking at the set said which were which.
#
# WHAT THIS IS NOT, and the two designs it replaces, because both were wrong in instructive ways:
#
#   "no capture may be older than the newest file that draws it."  Its population is "did any drawing file
#   change" and its claim is "is this frame out of date" — different populations. Under it, a commit that
#   reordered a price label in the Bazaar marks `_moment_delve.png` — rock in the dark — stale. It would
#   also be red within the hour of every renderer commit, and a permanently red gate gets ignored or gets
#   its floor lowered.
#
#   "every capture was last written by the same commit."  Better: it compares captures to each other and
#   never to source, so it is silent on ordinary renderer commits. But it taxes ADDING one capture at the
#   price of re-shooting all of them, forever, and a guard people route around is worse than none.
#
# And re-shooting is not available anyway, which is the fact that settled it. Roughly twelve of the tracked
# captures have no recoverable recipe: the `boot_green` / `boot_rust` / `boot_silver` ore-nugget A/Bs were
# taken with a hex nobody wrote down, `room_before` / `room_after` / `delve_after` are suffix variants with
# unrecorded state, and the six `*_zoom` frames come from `zoom.gd` with per-frame crop coordinates that
# were never recorded. All 41 landed in a single commit having been untracked before it, so git has no
# per-frame history to mine either. That commit also says so in as many words: *"It called the moments
# 'regenerable'. Re-running tools/sees.sh does not reproduce them, because the game underneath has changed;
# each capture records a world that no longer exists. That is an argument for versioning them, not against."*
#
# So the set is an ARCHIVE, not a baseline, and the defect is not that it is mixed — it is that it is mixed
# SILENTLY. A mixed archive that says so is usable; a uniform one that says nothing is only accidentally
# safe. This describes rather than forbids: every frame, the commit that wrote it, and a signature of the
# drawing sources as they stood in that commit's tree, so two frames sharing a signature are pictures of the
# same renderer no matter which day they were taken.
#
# NO COMMIT SHA IN THE TABLE, AND THAT IS THE SECOND DESIGN THIS FILE HAS HAD. The first version printed
# the sha of the commit that last wrote each capture, which is the obvious identifier and the wrong one:
# a sha does not exist until its commit does, so the manifest could not ride in the same commit as the
# frames; amending to squeeze it in changed the sha and invalidated it again; and then a routine rebase onto
# a peer's work rewrote the sha a third time and invalidated it once more. An identifier that changes every
# time history is tidied is a standing invitation to regenerate a file nobody read.
#
# The AUTHOR DATE and the RENDERER SIGNATURE both survive a rebase, and the signature is the better answer
# to the question anyway: "which commit" is a pointer, "which renderer" is the fact. `git log -1 -- <file>`
# recovers the sha in one command when somebody actually wants it.
#
# It still lags by one commit — a capture must be committed before this can describe it — so adding or
# re-shooting frames is two commits: the frames, then the manifest. `--check` gates the PUSHED tip, where
# the first is already history.
#
# THE MANIFEST IS GENERATED, NEVER EDITED. `--check` regenerates it and diffs, so it cannot drift from the
# repository the way a hand-kept list would — the failure this project has now hit in `check_item_reads`'s
# ITEMS list, in the capture count, and in the material registry.
#
# A CORRECTION TO `3c46c8c`, PLACED HERE BECAUSE A COMMIT MESSAGE CANNOT BE EDITED. That commit bars lossy
# compression of these frames on the grounds that "the harness samples these pixels (check_rock_reads and
# neighbours read values off them)". It does not. `grep -rln "_moment_"` over `tools/*.gd` finds
# capture_moments (writes them), the two mocks (write their own), zoom.gd (reads one in order to crop it),
# and one COMMENT in check_hud_layout citing `docs/media/baseline/_moment_map.png`, a different path. No
# layer reads a canonical capture as input, and the `tools/sees.sh` the same message cites does not exist.
# The knockout evidence is decisive the other way: `check_rock_reads` moved 61% -> 87% across a shader
# mutation with no capture re-shot, which is only possible if it renders live.
#
# The bar on lossy is probably still right — an archive of pixel evidence should not be requantized — but
# it is resting on a coupling that is not there, and a rule with a false reason is a rule that gets refuted
# and taken down with it.
#
# Needs no Godot and no display. Pure git.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
OUT="docs/CAPTURE_MANIFEST.md"
MODE="${1:-write}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The moments `capture_moments.gd` can actually pose, read off its match arms rather than kept in a second
# list here. `_items_the_view_knows()` in check_item_reads.gd does the same thing for the same reason: a
# mirror of a list is a list that drifts.
sed -n '/^	match moment:/,/^		_:/p' tools/capture_moments.gd \
	| grep -oE '^		"[a-z_]+"(, "[a-z_]+")*:' | tr -d '\t":' | tr ',' '\n' | tr -d ' ' \
	| grep -v '^$' | sort -u > "$TMP/moments"

# The files that decide what a frame LOOKS like. A capture is a picture of these.
{ echo scenes/world_renderer.gd; echo scenes/visuals.gd; echo scenes/hud.gd
  echo scenes/fine_terrain.gd; echo scenes/terrain_painter.gd
  git ls-files 'scenes/*.gdshader'; } | sort -u > "$TMP/drawers"

# One signature per COMMIT, not per file, so 48 captures from 2 commits cost 2 lookups and not 48.
sig_for_commit() {  # sig_for_commit <sha>
	local sha="$1" cache="$TMP/sig.$1"
	if [ -f "$cache" ]; then cat "$cache"; return; fi
	local acc=""
	while IFS= read -r d; do
		acc="$acc$(git rev-parse "$sha:$d" 2>/dev/null || echo missing) $d"$'\n'
	done < "$TMP/drawers"
	printf '%s' "$acc" | git hash-object --stdin | cut -c1-10 > "$cache"
	cat "$cache"
}

# The command that produces a frame, inverted from `capture_moments.gd`'s own naming:
#   _moment_<m>.png        ->  -- <m>
#   _moment_<m>_z<N>.png   ->  -- <m> <N>
# Everything else took an argument that was never recorded, and says so rather than guessing. A recipe
# invented to fill a column is worse than a blank one: it would be run.
recipe_for() {  # recipe_for <basename-without-_moment_-and-.png>
	local stem="$1"
	if grep -qx "$stem" "$TMP/moments"; then
		echo "capture_moments.gd -- $stem"
		return
	fi
	local base="${stem%_z[0-9]}" z="${stem##*_z}"
	if [ "$base" != "$stem" ] && grep -qx "$base" "$TMP/moments"; then
		echo "capture_moments.gd -- $base $z"
		return
	fi
	case "$stem" in
		*_zoom) echo "zoom.gd -- _moment_${stem%_zoom}.png <crop UNRECORDED>" ;;
		*)      echo "UNRECORDED" ;;
	esac
}

n=0
{
	echo "# CAPTURE MANIFEST"
	echo
	echo "**Generated. Do not edit.** \`bash tools/capture_manifest.sh\` rewrites it;"
	echo "\`--check\` fails if it is out of date."
	echo
	echo "Every tracked \`_moment_*.png\`, the date it was written, and a signature of the drawing sources as"
	echo "they stood in the tree that wrote it. **Two frames sharing a RENDERER signature are pictures of the same"
	echo "renderer**, whatever day they were taken; two frames that differ are not comparable to each other and"
	echo "a vision agent judging them together is judging two builds."
	echo
	echo "The RECIPE column is how the frame is produced. \`UNRECORDED\` means the command took an argument"
	echo "nobody wrote down — an ore-nugget hex, a crop rectangle, a suffix variant's extra state — so the"
	echo "frame cannot be re-shot faithfully and is an archival record rather than a reproducible baseline."
	echo "A recipe invented to fill that column would be worse than a blank one, because it would be run."
	echo
	echo "| capture | date | renderer | recipe |"
	echo "|---|---|---|---|"
	while IFS= read -r f; do
		stem="${f#_moment_}"; stem="${stem%.png}"
		sha="$(git log -1 --format=%H -- "$f")"
		printf '| `%s` | %s | `%s` | `%s` |\n' \
			"$stem" "$(git log -1 --format=%ad --date=format:'%Y-%m-%d %H:%M' "$sha")" \
			"$(sig_for_commit "$sha")" "$(recipe_for "$stem")"
		n=$((n + 1))
	done < <(git ls-files '_moment_*.png')
} > "$TMP/manifest.md"

# The summary is appended after the table so the counts are of what was actually written, not of what was
# expected — a header that states a count it did not derive is the defect this repo has hit twice.
{
	echo
	echo "## Cohorts"
	echo
	git ls-files '_moment_*.png' | while IFS= read -r f; do
		sha="$(git log -1 --format=%H -- "$f")"; sig_for_commit "$sha"
	done | sort | uniq -c | sort -rn | while read -r count sig; do
		echo "- \`$sig\` — $count frames"
	done
	echo
	echo "One line here means the archive is one renderer. More than one means it is mixed, which is"
	echo "permitted and described rather than forbidden: re-shooting is not available for every frame, so"
	echo "a gate on uniformity would be a gate on a state nobody can reach."
} >> "$TMP/manifest.md"

if [ "$MODE" = "--check" ]; then
	if [ ! -f "$OUT" ]; then
		echo "  FAIL  $OUT does not exist — run tools/capture_manifest.sh" >&2
		exit 1
	fi
	if diff -q "$OUT" "$TMP/manifest.md" >/dev/null; then
		echo "capture_manifest: PASS — the manifest matches the repository"
		exit 0
	fi
	echo "  FAIL  $OUT is out of date. Regenerate it with: bash tools/capture_manifest.sh" >&2
	diff "$OUT" "$TMP/manifest.md" | head -20 >&2
	exit 1
fi

mkdir -p "$(dirname "$OUT")"
cp "$TMP/manifest.md" "$OUT"
echo "wrote $OUT ($(grep -c '^| `' "$OUT") captures)"
