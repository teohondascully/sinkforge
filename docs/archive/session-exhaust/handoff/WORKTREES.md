# The worktrees — what is in them, and what is not in main

Fourteen non-main worktrees, thirteen of them agent branches, accumulated across sessions that stopped
mid-flight. This document exists so that neither peer rebuilds something that is already written, and so
that "we'll get back to those worktrees" stops being a thing we say and starts being a list.

**Nothing here is a deletion plan.** The standing instruction is *preserve all existing worktrees, history,
assets, sprites, notes, and user files*. Triage here means **document and route**. No branch is deleted, no
worktree is removed, and if a branch's work turns out to be fully landed the branch still stays.

---

## How this was measured, and why the obvious method lies

The intuitive check — does each branch's file match main's? — is worthless here, and confidently so.
Running it reports **`landed 0/16`** for essentially every branch. That is not evidence the work never
landed. Main has moved a great deal since these branches were cut (most base off `3897348`, 2026-08-16), so
any file main has edited since will differ *whether or not the branch's idea is in main*. Byte-identity
cannot distinguish "never landed" from "landed, then edited."

What is used instead: **introduced-symbol presence.** For each branch, extract every identifier it
introduces (`func`, `static func`, `const`, `var`, `signal`, `@export var`) in the diff against its
merge-base, then search main's tree for each one.

```sh
base=$(git merge-base HEAD "$b")
git diff $base $b -- '*.gd' \
  | grep -E '^\+[[:space:]]*(func|const|var|signal|static func|@export var) ' \
  | sed -E 's/^\+[[:space:]]*(static func|func|const|var|signal|@export var)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/' \
  | sort -u
```

**Read these numbers as an UPPER BOUND on how much landed.** Short or generic identifiers (`_emit`, `a0`,
`vec3`, `dur`, `ko`, `ss`) match something in main by coincidence and inflate the "present" count. The
*missing* lists are the trustworthy half — a symbol absent from the whole tree is genuinely absent.

Two shell notes, both of which produced wrong answers before they were caught:

- **zsh does not word-split unquoted variable expansions** (it does split command substitutions). `for f in
  $files` iterates *once* over the entire newline-joined list, so every per-file tally silently reports 1.
  Use `${(f)"$(...)"}`.
- `git merge-base --is-ancestor` reports **NOT contained** for a branch whose commits were replayed by a
  rebase, because the replay assigns new hashes. Content can be 100% landed while the branch tip is not an
  ancestor of anything. `ab86dfe` below is exactly this case — it reads "not contained" and is fully merged.

---

## The table

| branch | symbols present | what it is | verdict |
|---|---|---|---|
| `ab86dfe` | **15/15** | CI: four software-rendered layers, honest PASS/SKIP accounting | **LANDED** — verified byte-identical, see below |
| `a8afacea` | 100/146 | `sfx.gd` +577, new `measure_voice.gd` +276 — per-material pick sounds | live — audio lane |
| `a3208149` | 89/160 | wip, self-described *superseded* | archive |
| `a2462b92` | 71/120 | wip, self-described *superseded* | archive |
| `a6579992` | 68/90 | wip(particles) | review in the presentation lane |
| `ad52b2d1` | 51/65 | `hud.gd` +420/−149 — the Bazaar HUD plate | live — presentation lane |
| `a53ff2bb` | 33/54 | wip(lighting) | blocked with the rock question |
| `ad448b38` | 28/44 | wip(glyphs-inspector) — item glyphs | review in the presentation lane |
| `a9b0034b` | 17/38 | `player.gd` — miner dig pose, rim light, shadow | review in the presentation lane |
| `ae87e736` | **15/46** | `fine_terrain.gd` +237 — rock bedding, partings, lit face | **blocked** — see below |
| `a0d233e9` | 13/18 | THE LODE CUTOVER, 16 files, +405/−128 | **do not merge** — gates red |
| `a3be74d0` | 10/18 | wip(union) — a mid-merge union branch | supersedes `aabacbb2` |
| `aabacbb2` | 10/17 | test(harness): six assertions that could not fail | subsumed by `a3be74d0` |
| `eval-rock` | — | no authored changes against its base | inert |

`a3be74d0`'s missing-symbol list is `aabacbb2`'s **plus** `grained_in_band` — the union branch strictly
contains the harness-assertion branch. Whichever gets picked up, it is the union one; they are not two jobs.

---

## The four that matter

### `ab86dfe` — landed, and worth stating precisely

Verified file-by-file against `HEAD`: `.github/workflows/harness.yml`, `check_frametime.gd`,
`check_opening.gd`, `check_underground.gd`, `check_water_reads.gd` are **byte-identical**. `run_harness.sh`
differs by exactly one line, which `HEAD` *has* and the branch lacks — a layer registration added after the
branch was cut. Nothing on this branch is unlanded. It reads "NOT contained" only because a
`git pull --rebase` rewrote its two commits to new hashes.

### `ad52b2d1` — the Bazaar HUD plate, and a near-miss worth recording

One file, `scenes/hud.gd`, +420/−149. Missing: `_plate_box` `_plate_button` `_plate_lamp`
`_plate_title_size` `_keycap` `_key_legend` `_head_chip_w` `_bazaar_verb_word`.

This was flagged mid-flight while the other peer was actively starting Bazaar work, and the important part
was the *disambiguation*: this branch touches `scenes/hud.gd`, while the live bug (`Bazaars.draw()`
iterating only completed frames, so the first Bazaar a player ever meets has no art) lives in
`scenes/bazaars.gd`. **Different files, no duplication, no collision.** The reflex — "someone already did
this, stop what you're doing" — would have been wrong.

It is still worth reviewing after that lands: `_plate_box` / `_plate_lamp` / `_keycap` / `_key_legend` is
the *menus-must-read-2026* direction (elevation not borders, a detail plate for the selected thing, costs
as glyphs) already built and never merged.

### `ae87e736` — the rock, and why "blocked" got more expensive

The least-landed branch of all, 15/46. One file, `scenes/fine_terrain.gd`, +237/−15. Missing: `BED_AMP`
`BED_DIP` `BED_ROLL` `BED_ROLL_RISE` `CLAST_FORM` `CRACK_YSTRETCH` `FACE_TOP` `FACE_SIDE` `bed_gate`
`_bedding` `_face_light`.

Bedding planes, partings, and a lit top face — squarely the rock-legibility problem both peers marked
*blocked on a blind-vision pass*. It **stays blocked**: `MASS_SHADE 0.55` is still provisional and this
modifies the same surface, so merging it would change two things at once and make the eventual perceptual
judgement uninterpretable.

But the deferral is not free any more. "Blocked" was cheap to say when the belief was that there was
nothing to merge. There are 237 written lines. That raises the value of actually scheduling the
blind-vision pass, and converts it from a deferral into a decision.

### `a0d233e9` — the lode cutover, explicitly not merging

16 files, +405/−128. Missing: `MINESHAFT_LODE_CELL` `nearest_lode` `STARTER_VEIN_AMOUNT`
`TUTORIAL_COAL_AMOUNT` `work_lode`.

Standing instruction, unchanged: **do not merge the lode cutover on the strength of its 98.6 score — its
completion and play gates are red, and thresholds are not to be lowered to manufacture a green.** Recorded
here only so nobody rediscovers the branch and reads the score without the gates.

---

## Routing

- **Presentation lane** — `ad52b2d1` (after the Bazaar draw fix), `a6579992`, `ad448b38`, `a9b0034b`.
- **Audio lane** — `a8afacea`, and diff its `measure_voice.gd` against the current `check_voice.gd`
  *before* extending either; there is a 276-line instrument here that may already cover part of it.
- **Blocked, jointly owned** — `ae87e736` and `a53ff2bb`, both pending the blind-vision pass.
- **Frozen by instruction** — `a0d233e9`.
- **Archive, no action** — `a2462b92`, `a3208149` (both self-described superseded), `eval-rock`.
- **Pick up as one** — `a3be74d0`, which contains `aabacbb2`.
