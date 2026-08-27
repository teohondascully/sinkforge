> **ARCHIVED 2026-08-27.** Untracked since the 2026-08-25 pivot despite `docs/archive/PIVOT_PLAN_2026-08-25.md`
> §1 recommending KEEP as-is, and despite being cited by name from inside two already-tracked archived
> documents (`COMPAT_AUDIT_2026-08-25.md`'s `tools/` baseline reconciliation note, and
> `PIVOT_PLAN_2026-08-25.md` §1's own KEEP list) — moving it here resolves what was, until this move, a
> dangling reference from tracked prose to an untracked file. One of the five sources behind the
> 2026-08-25 pivot decision. Moved here while closing the `.git/info/exclude` hole (ANVIL step 1). Kept
> for provenance.

---

# SINKFORGE Repository Portfolio Audit

**Auditor role:** senior-staff repository quality review, read-only.
**Audit window:** 2026-08-20, ~19:00–20:10 local.
**Pinned commit:** `e9f23e2b69281a5d0ef3e069ae92848fd754dcc5` (`e9f23e2`, *"docs: a landing page and a contributing guide (T2.5)"*).
**Published tip at audit time:** `origin/main` = `aa52aceb77045591635e7cd147531acd05302867` (`aa52ace`).

Every claim below is labelled **Observed** (directly verified by command output or file read),
**Inferred** (reasoned from observed evidence), or **Unknown** (not safely verifiable under the
constraints in §2). Nothing in this document was fixed while it was being audited; no source, test,
harness, threshold, branch, worktree or history was modified. The only file created is this one.

---

## Executive verdict

### The three findings I would defend most strongly

**1. The repository a hiring panel can see is not the repository this audit measured.**
`git ls-remote origin refs/heads/main` returns `aa52ace`; local `main` is **135 commits ahead and 0
behind** it. The most recent *completed* CI run against the published tip **failed** (run
`32321357033`, 2026-08-20T01:32Z): the pixels job came back 13 pass / 3 fail, and the two runs before
it were cancelled. So the public artifact is a two-and-a-half-week-old snapshot wearing a red X,
while every improvement made since — `CONTRIBUTING.md`, the rewritten README, eight further harness
layers, the carry-cap seam, the capture manifest gate — exists only on this machine. **Observed.**
This single fact dominates the portfolio score more than any code defect in the repository.

**2. The instrument outweighs the subject, and the same imbalance has spread into the process.**
Tracked GDScript: `tools/` **33,773 lines across 112 files**; the game itself is `scenes/` 21,180 +
`src/` 5,490 = **26,670**. The verification harness is 127% the size of the thing it verifies, and
that is before `tests/` (4,439). Around it sit **42 git worktrees consuming 8.5 GB inside the repo
directory**, **50 local branches** (20 already fully merged into `main`, 2 with *no merge base at
all*), and a 56-entry director-bus directive log. **Observed.** The harness is excellent — see the
next section — but a reviewer counting lines will conclude that the project's centre of gravity has
moved from the game to the apparatus, and the branch/worktree residue is the visible form of that.

**3. 71 MB of PNG captures are tracked at the repository root, and no registered harness layer reads
any of them.** `git ls-files '_moment_*.png'` = **52 files, 71 MB**, plus 32 `.import` sidecars and
2 `_crop_*.png`, on a tracked tree of **~326 MB**. I scanned all 101 registered layer scripts for a
`_moment_*` read (`Image.load` / `load_from_file` against a `_moment_` path): **zero hits.** The only
occurrence inside a registered layer is a prose comment, `tools/check_hud_layout.gd:808`, naming
`docs/media/baseline/_moment_map.png` — a different file, correctly filed under `docs/media/`.
**Observed.** The *decision to preserve* the captures is legitimate and well-argued in `.gitignore`
(they are an irreplaceable record of builds that no longer exist, and the user instructed that they be
committed). The *location* is not: `docs/media/` already exists, already carries a `.gdignore`, and
already holds the two baseline sets. Root placement is what a reviewer meets first.

### The three things that already demonstrate senior-level judgment

**1. Save and data safety, which is the best-engineered surface in the repository.**
`src/core/save_game.gd` (362 lines): a versioned envelope at `VERSION = 2` with a real
single-step migration chain (`_migrate`, v1→v2 for the seep phase); a **transactional** restore that
validates and duplicates the entire envelope into a staging dictionary before `_commit` touches the
live sim; a write path that encodes to `.tmp`, **reads it back and proves it decodes** before
promoting, copies the current slot to `.bak` **only if the current slot is itself a valid envelope**
(so a damaged primary cannot destroy the last good generation), aborts the whole write if that copy
fails, and finishes with one atomic rename; `read()` that falls back to `.bak` and distinguishes
NONE / OK / RECOVERED / CORRUPT so the UI can tell "new player" from "lost work"; `f.get_var()` left
at `allow_objects = false`, so no object deserialization surface exists. On top of that,
`_fixture_may_not_write()` refuses a `user://` write from any `--script` process that has not
declared an isolated home — keyed on a **positive** marker rather than on recognising the dangerous
state, which is the correct polarity. **Observed.** Three independent mechanisms then guard the
developer's own save during a sweep: `HOME`/`XDG_*` redirection in `run_harness.sh`, the
`check_save_isolation` source scan, and `save_sentinel.gd`'s before/after hash of the real production
slot. That is a property proved three ways rather than promised once.

**2. The three-state harness protocol, and the join-defect layer that keeps it honest.**
A layer is PASS / FAIL / **SKIP (exit 42, plus a reason line — half a contract is refused)**, with a
fourth partial state (`SKIP:` prefix ⇒ `PASS*`, "passed without verifying everything"). The runner
refuses to print the word "ALL" over any list containing a skip, refuses to report on a filtered
subset, checksums its own script so a mid-run edit invalidates the result, and carries five distinct
exit codes with the severity-masking hazard written down. This exists because the suite once printed
`ALL 61 HARNESS LAYERS PASS` over four layers that had drawn nothing, for 33 consecutive red pushes.
The fix was then generalised: `tools/check_ci_coverage.gd` reads **both** `run_harness.sh` and
`.github/workflows/harness.yml` and asserts **set equality** between the layers registered `add_gl`
and the layers the display job selects or explicitly excludes — with non-vacuity counts asserted
first, because "every name the workflow lists is real" passes trivially over an empty list. That is a
defect class being closed, not a bug being patched. **Observed.**

**3. An assertion-validity culture that is stronger than most production codebases'.**
Sampled directly: `tools/check_carry_cap.gd` refuses to call `can_carry` at all, because "a test that
asks the predicate whether it would refuse cannot notice that nobody asks it" — every assertion goes
through `mine()` and `collect_ground()`, and every full-pack assertion is paired with a below-cap or
non-bulk control so a permanently-jammed cap cannot pass. `check_frametime` carries workload floors
(`RUN_MIN_PX`, `DIG_MIN_MINES`, `SWING_MIN_ANCHORED`) marked *proven able to fail*. Layers are
registered **only on the day they pass** rather than lowered to meet the picture (`check_rock_reads`,
`check_material_grammar`), and both carry knockout controls demonstrating a red state. Cues that
separate their own null rig are **disqualified by rule** (ANISO, at 80% on the null). Every one of
the five vacuous assertions named in `docs/ORCHESTRATOR.md` §5 — `check_pack_layout:105`,
`check_mining:99`, `check_plunge:123`, `check_loop_health:130-132`, `check_seam:88` — has been
repaired, with the repair and its reasoning left in place at the site. **Observed.**

### The single biggest portfolio risk

**The GitHub landing experience.** A reviewer arriving at `github.com/teohondascully/sinkforge` sees:
a red CI cross on the head commit; a root directory in which ~85 of ~90 entries are `.png` and
`.png.import` files; a 326 MB clone; no release, no tag, no version string, no build badge — and a
README that is, in fact, outstanding, but sits below the file list. The engineering underneath is
B+/A- work. The five-minute impression is C. That gap is the whole finding, and it is cheap to close
relative to everything else in this document.

### Overall

| | |
|---|---|
| **Weighted score** | **83.7 / 100** |
| **Grade** | **B** |
| **One sentence** | A genuinely strong engineering artifact — exceptional data-safety and test-validity discipline on a real, enforced simulation/representation seam — whose public face is a stale red snapshot buried under 71 MB of root-level screenshots, and whose verification apparatus has grown larger than the game it verifies. |

**No P0 was found.** I looked specifically for a path that destroys or silently loses a player save
and did not find one; the historical instance (`check_saveload` driving and deleting the real F5 slot)
is closed by three independent mechanisms. Saying that plainly is part of the finding: the highest-risk
category in this repository is also its best-defended one.

---

## Repository state and audit limits

### State

| | |
|---|---|
| Pinned commit | `e9f23e2` — *docs: a landing page and a contributing guide (T2.5)* |
| Branch | `main` |
| Working tree at pin | clean at the moment of pinning; a transient ` M tools/check_pacing.gd` and ` M tools/check_seam_flood.gd` were observed earlier and were committed by another session |
| Published tip | `origin/main` = `aa52ace`; **local `main` is 135 ahead, 0 behind** |
| Total commits | 876, **single author** `teohondascully <121736842+teohondascully@users.noreply.github.com>` (100%, verified over the whole history) |
| Tags | 2 (`pre-lode`, `pre-merge-capture-deafness`) — neither is a release tag |
| Local branches | 50 — 20 fully merged into `main`, 29 unmerged, **2 with no merge base at all** (`audio-per-material` 402 commits, `presentation-glyphs` 399 commits) |
| Worktrees | 42 registered; `.claude/worktrees/` holds 39 of them at **8.5 GB** |
| Tracked files | 595 · **~326 MB**, of which `history/` 166 files / 228 MB and root `_moment_*.png` 52 files / 71 MB |
| Engine | Godot `4.6.2.stable.official.71f334935`, present at `/opt/homebrew/bin/godot` |
| Harness | **100 registered layers** across 101 distinct scripts (`add` 83, `add_gl` 14, `add_excl` 3) |
| Last completed CI on the published tip | **FAILURE** — run `32321357033`, headless 77 P / 0 F / 15 S of 92, pixels 13 P / 3 F of 16 |

### THE TREE MOVED UNDER THIS AUDIT — read this before quoting any number

The user notified me mid-audit that **other agents are actively editing files**. `HEAD` advanced
**five times** while I was gathering evidence:

`2389823` → `f5e6318` → `2896ed5` → `e9f23e2` → `a3ffcd4`

and at least two of those commits repaired findings I had already recorded. Specifically:

- The README claim *"Several of the pixel layers read them as evidence, which is why they are tracked
  rather than generated on demand"* — which I verified false — was **rewritten during the audit** to
  the accurate *"Several tools address them by `res://` path."* The finding stands against the
  captures' *location*, not against the current README sentence.
- `CONTRIBUTING.md` **did not exist** when I began and **does exist** at the pin (`e9f23e2`), 14,414
  bytes, with Setup / Running / Exit codes / lock / parse-check / conventions / adding-a-layer /
  commits sections. It is graded as present.

Every figure in this report was re-verified in one consolidated sweep at the pinned commit. Anything
that moved after the pin is out of scope and should be re-derived, not read off this document.

### Tests run

**None.** No Godot process was launched and the harness was not run. Two independent reasons, both
required by the operating constraints:

1. **Save safety was verified as a mechanism, and it holds.** `run_harness.sh:148-166` redirects
   `HOME`, `XDG_DATA_HOME` and `XDG_CONFIG_HOME` to a per-repo-root scratch home unless
   `SF_REAL_HOME=1`, so `user://` is not the player's directory during a sweep;
   `save_sentinel.gd:_production_digest()` hashes the **real** slot before and after **without ever
   opening it for write**; `SaveGame._fixture_may_not_write()` refuses a `user://` write from any
   `--script` process lacking `SF_ISOLATED_HOME`. A full sweep could not have overwritten a real save.
   **Observed — the constraint is satisfied.**
2. **The run would have been contaminated anyway, and would have taken the machine hostage.**
   `run_harness.sh` takes a machine-wide `mkdir` lock (`${TMPDIR}/sinkforge-harness.lock`) with a
   900 s default wait, and three of its layers are `add_excl` because *a timing layer measures the
   box, not the directory*. With other agents running Godot on this machine and mutating the tree, any
   sweep I started would have (a) blocked their work for minutes, (b) measured a tree that changed
   under it — the exact failure `SELF_SUM` and the `tree:` / `head:` banner exist to catch, and (c)
   produced perf numbers describing contention. Under this repository's own rules that is a **VOID**,
   not a result. Reporting a void as evidence would be the defect this codebase has spent weeks
   documenting.

**Consequence, stated plainly:** every green/red judgement in §Test-truth below is a judgement about
**assertion structure read from source**, not about today's run outcome. Where I say a layer "cannot
pass vacuously", I mean its source contains a reachable failing path and a non-vacuity guard — not
that I watched it go red.

### Evidence classified as stale, contaminated, or unavailable

| Item | Status | Why |
|---|---|---|
| The last CI result | **Stale by 135 commits** | It describes `aa52ace`, not the pin. It is nonetheless the only CI evidence that exists. |
| `docs/ORCHESTRATOR.md` | **Stale, materially** | Says *"~19,000 lines of GDScript"* (actual tracked: 64,907), a 58-layer harness (actual: 100), *"THIRTEEN AGENT WORKTREES"* (actual: 42), and `tests/ 5` / `history/ GITIGNORED` (history is tracked). It is also gitignored, so it is invisible on GitHub. |
| `docs/handoff/NEW_SESSION_PROMPT.md` | **Stale** | *"Main is green: 58/58 locally and CI is passing"* and *"Last commit `10641ac`"*. Contradicted by the README's own honest CI paragraph. |
| The 42 worktrees | **Not evidence of mainline behaviour** | 30 of them are ≥50 commits behind `main`; two share no ancestry with it. Nothing in this report treats a worktree as current behaviour. |
| Agent completion claims in handoff docs | **Not used as evidence** | e.g. the "57/57" self-reports in `ORCHESTRATOR.md` §12 are recorded there as untrusted by the document's own author; I treated them the same way. |
| Whether `check_grapple_reads` / `check_hud_layout` / `check_snap_frame` still fail at the pin | **Unknown** | Requires a display run I did not take. |
| Whether the full harness is green at the pin | **Unknown** | Not run. Do not assume either way. |

---

## Scorecard

Weighting note: this is **not** a flat average of intent. Two caps were applied. *Release readiness*
is capped by the total absence of a release path (no export preset, no version, no tag, no artifact).
*CI quality* and *Portfolio presentation* are capped by the published tip being red and 135 commits
stale — a well-designed pipeline that is red is still red.

| # | Category | Grade | Score | Verdict (one sentence) | Strongest evidence | Biggest gap | Highest-leverage action | Effort | Depends on | Re-evaluate by |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Repository organization | C | 70 | Coherent below the root and chaotic at it: 52 tracked PNGs, 3 orphan sidecars and a typo'd audit file are the first thing anyone sees. | `git ls-files \| grep -v /` = 5 real files + 85 image artifacts; `docs/media/` already exists and is correctly organised | 71 MB of captures at the root with no layer reading them | `git mv` the `_moment_*` set into `docs/media/moments/`, repoint `capture_moments.gd` + `capture_manifest.sh`, keep every byte | M | manifest + capture tooling repoint | `git ls-files \| grep -v / \| wc -l` ≤ 12 |
| 2 | Architecture | B+ | 87 | The load-bearing seam is real and mechanically enforced; the layers on the presentation side have not been given the same discipline. | 0 `get_tree()` and 0 `res://scenes` references in `src/`; every `src/` script extends `RefCounted`/`Resource` | 4 god files hold 14,846 lines (56% of game code) | Extract `lighting.gd` from `world_renderer.gd` behind the existing `LightLayer` painter Callable | L | a pixel baseline before/after | god-file LOC < 1,800 each, `check_*` green |
| 3 | Modularity | B | 84 | Content is data and algorithms are extracted, but one new machine still touches three files and `CELL` is defined seven times. | `src/data/machines/*.tres` (20), `_BEHAVIORS` dispatch by method name, `water_flow`/`power_flow`/`flora`/`fine_terrain` extracted | `const CELL: int = 32` in 7 game files + ~27 tool files, with nothing relating them | Single `Grid.CELL` (or `FactorySim.CELL`) + a source-scan layer forbidding redefinition | S | none | `grep -rc "const CELL" scenes/ src/` = 1 |
| 4 | Code quality | B+ | 88 | Typed-everywhere is a compile error rather than a lint, naming is consistent, and comments explain *why* — at a density that has itself become a cost. | `project.godot` `untyped_declaration=2`; sampled `save_game.gd`, `factory_sim.gd`, `check_carry_cap.gd` | 21,133 comment lines = **35.8%** of non-blank tracked GDScript; `hud.gd` opens with ~500 lines of constants and design essay before its first real function | Move standing design rationale out of file prologues into `docs/DECISIONS.md`, leave the *local* why at the site | M | DECISIONS is already the right home | comment fraction of `hud.gd` < 30%; first `func` before line 150 |
| 5 | Maintainability | B | 85 | The recorded reasoning is a genuine asset; the palimpsest documents and the god files are what a newcomer will actually fight. | `docs/DECISIONS.md` (533 lines, every entry cites a source); dated in-place corrections throughout | `docs/PRIORITY.md` is 2,639 lines with 17 "supersed", 19 "withdraw", 53 "correct" markers | Split PRIORITY into a ≤150-line live board + an append-only `docs/PRIORITY_ARCHIVE.md` | M | director judgement on what is live | `wc -l docs/PRIORITY.md` < 200 |
| 6 | Correctness | A- | 90 | Authoritative state transitions are guarded, conserved and tested at the verb; no data-destroying path was found. | `check_carry_cap.gd` (39 assertions, all through `mine()`/`collect_ground()`); `tests/test_sim.gd` 427 assertions incl. capture→restore→tick→signature | The pack cap is enforced at 4 independent write sites by convention; a 5th would escape silently | Source-scan layer: every `inventory[...] =` in `src/` must be inside `take_into_pack`, or guarded by `can_carry`/`pack_room`, or on a named exemption list | S | none | new layer red on a deliberately-uncapped mutant |
| 7 | Reliability | B | 83 | The suite is honest about its own failure modes, but three layers are failing on the published tip and two more are known-intermittent under load. | Runner's `add_excl` rationale with measured contention figures (IDLE p95 15.59 → 20.70 ms) | 3 red pixel layers at `aa52ace`; status at the pin unknown | Run `SF_GL_ONLY=1 SF_STRICT=1` on a quiet machine, fix or ticket each of the three, then push | M | machine lock free of other agents | pixels job green on the published tip |
| 8 | Save / data safety | A | 95 | Best-in-repo: versioned, migrating, transactional, readback-verified, backup-generational, and proved by an instrument rather than promised by a comment. | `save_game.gd` `_stage`/`_commit`/`write`/`read`; `check_save_durability` (69 assertions); `check_save_isolation`; `save_sentinel.gd` | No `fsync` (documented as a deliberate non-claim); a v1 save missing `world_seed` restores at seed 0 and re-molds the fine terrain from the wrong seed | Refuse a v1 envelope with no `world_seed` rather than defaulting it — pre-1.0, no shipped saves | S | none | a v1-without-seed fixture is refused, `last_invalid` names it |
| 9 | Test validity | A- | 90 | The assertion discipline is the repository's signature strength; the residual gaps are structural, not cultural. | All five `ORCHESTRATOR` §5 vacuity defects verified repaired in place; knockout controls and demonstrated red states recorded at registration | 13 registered layers still bypass `check_base.gd` and hand-roll the exit protocol | Port the 13 to `check_base` one at a time, harness-green after each | M | none | `for s in $(registered); do head -3 $s \| grep -c "^extends SceneTree"; done` = 0 |
| 10 | Integration coverage | B+ | 87 | `play_tests` is a real end-to-end pilot through reach-gated verbs, weakened by privileged inputs and best-of-3 reporting. | 16 goals through the real scene, real body, real physics; friction ceilings with dated ratchets | `play_agent.give()` injects into the pack and `nearest_material()` scans `sim.solid` wholesale — neither is a player capability | Split the pilot's API into `PLAYER_LEGAL` and `FIXTURE_ONLY` namespaces; assert each goal declares which it used | M | `docs/handoff/BLIND_EVAL_READINESS.md` §3 (56 privileged inputs) | every goal prints its privileged-input count; ≥8 goals at zero |
| 11 | CI quality | C+ | 78 | Unusually well-reasoned pipeline design, in a red state, on a tip 135 commits stale, with an unverified engine download. | 3 jobs, registration-derived pixel selection, `SF_NOT` as a spoken exclusion, artifacts + step summaries, `check_ci_coverage` holding both files | Red; no checksum on the Godot zip; no cache; actions on mutable major tags | Push the 135 commits, get the pixels job green, then pin `actions/*` to SHAs and add `sha256sum -c` on the engine | M | §7 | green run on `origin/main`; `grep -c sha256 .github/workflows/harness.yml` ≥ 2 |
| 12 | Performance discipline | B+ | 87 | Real budgets, real hitch ratios, real workload floors — and one uncached O(cols×rows) scan running every frame. | `check_frametime` 120 fps budget, `DIG_HITCH_RATIO` 6.0, `MOVE_HITCH_RATIO` 2.0, host-pinned absolute via `SF_PERF_HOST`; chunked terrain repaint | `_paint_godrays` calls `sim.surface_row()` 3× per column × 128 columns every frame; `surface_row` is an O(128) linear scan; no cache exists | Memoize `surface_row` per column, invalidate on `sim.terrain_dirty` | S | none | `profile_frame.gd` shows the light pass cost falling; `check_frametime` unchanged or better |
| 13 | Documentation | B | 84 | Deep, dated, self-correcting — and 39 of its citations point at files that are not in the repository. | `ARCHITECTURE.md`, `DECISIONS.md`, `HARNESS_LAYERS.md`, `CAPTURE_MANIFEST.md` (generated, `--check` PASSES) | 39 citation instances from tracked files to gitignored paths (`docs/ORCHESTRATOR.md`, `docs/handoff/*`, `docs/tracelog/*`, `AUDIT_REPONSE.md`) | Either publish the cited docs or replace each citation with the fact it was carrying | M | director call on publishing process docs | a link-check layer over tracked files returns 0 |
| 14 | Onboarding | B+ | 86 | A newcomer can now clone, run, test and commit from published files alone — as of the pinned commit, and not before it. | `CONTRIBUTING.md` (Setup / Running / Exit codes / lock / parse check / conventions / adding a layer / commits); `HARNESS_LAYERS.md` | The real orientation document (`ORCHESTRATOR.md`) is gitignored; 326 MB clone; `README` "Running from source" does not mention the machine lock | Add a `--depth 1` / partial-clone note and a 10-line quickstart block at the top of `CONTRIBUTING.md` | S | none | a stopwatch: clone → `godot --path .` running in < 15 min |
| 15 | Release readiness | D+ | 64 | There is no release path of any kind: nothing versions, nothing packages, nothing ships. | `export_presets.cfg` gitignored; no `config/version` in `project.godot`; 2 tags, neither a release; no CHANGELOG | A contributor cannot produce a build from a clean clone, and the README says so | Commit a sanitised `export_presets.cfg`, add `config/version="0.1.0"`, tag `v0.1.0`, add a `release` job producing a zip artifact | M | §11 green | `gh release list` non-empty; a downloaded artifact launches |
| 16 | Security / data integrity | B+ | 88 | Realistically clean for a local game: no secrets, no shell-out, no object deserialization — with one genuine supply-chain hole. | 0 hits for credentials/keys in tracked source; 0 `OS.execute`/`OS.shell_open` in `scenes/`+`src/`; `get_var()` at `allow_objects=false` | CI `wget`s a 60 MB engine zip from GitHub releases twice per push with **no checksum** (`grep -c sha256` = 0) | Publish `4.6.2-stable` SHA256 in the workflow and `sha256sum -c` before `unzip` | S | none | `grep -c sha256sum .github/workflows/harness.yml` = 2 |
| 17 | Dependency hygiene | B+ | 87 | Zero third-party runtime dependencies and an exactly-pinned engine — undermined only by mutable action tags and the missing checksum. | no `addons/`; `project.godot` `config/features=("4.6",…)`; CI pins `V=4.6.2-stable` | `actions/checkout@v5`, `actions/upload-artifact@v4` are mutable major tags; apt packages unpinned; no `dependabot.yml` | Pin the two actions to commit SHAs; add `.github/dependabot.yml` for the actions ecosystem | S | none | no `@vN` action reference remains in the workflow |
| 18 | Development-process maturity | B- | 82 | A real multi-agent governance system with acks, locks, worktree isolation and evidence-bearing commits — carrying more residue than it clears. | `director_bus.sh` (56 directives, 55 RESOLVED, ack states ACCEPT/DISPUTE/DONE); `with_machine.sh`; `check_trailers` promoted from hook to harness layer; `core.hooksPath` verified set | 42 worktrees / 8.5 GB / 50 branches / 135 unpushed commits; the whole process record is gitignored so none of it is legible to an outside reviewer | Prune the 20 fully-merged branches + their worktrees; write a 40-line `docs/PROCESS.md` that *is* published | M | per-item confirmation before removing anything (house rule) | `git worktree list \| wc -l` ≤ 6; `git branch --merged main \| wc -l` ≤ 1 |
| 19 | Portfolio presentation | C+ | 76 | Excellent writing sitting underneath a red build, a stale tip and a wall of screenshots. | README is honest to the point of publishing its own red CI result and its own non-claims ("92 is a count of registered layers. It is not a coverage figure") | The published tip is red and 135 commits old; ~85 of ~90 root entries are images; no badge, no release, no tag | Push, get green, move the captures, add the CI badge back | M | §1, §7, §11 | a first-time GitHub visit shows green CI, ≤12 root entries, a release |
| 20 | Technical-debt control | B | 83 | Debt is genuinely paid down in the code and genuinely accumulated in the repository around it. | `check_base.gd` extraction (84 layers), all five audited vacuity defects repaired, `_fixture_may_not_write` added after the incident | Branch/worktree/unpushed-commit debt has no owner and no gate | A `check_repo_hygiene` layer: fail on >8 worktrees, on any fully-merged branch, on any tracked `.import` whose image is untracked | S | §18 pruning first, else it is red on arrival | the layer registers green after the prune |

**Weighted total: 83.7 / 100 — B.**

---

## Root-directory inventory

Only the top level. "Belongs?" is judged against what a senior reviewer expects at the root of a
public game repository.

| Path | Purpose | Belongs at root? | Recommendation | Migration risk |
|---|---|---|---|---|
| `README.md` | Landing page; genuinely strong | **Yes** | Add the CI badge back once green | none |
| `LICENSE` | MIT, © 2026 teohondascully | **Yes** | none | none |
| `CONTRIBUTING.md` | Setup, tests, lock, conventions, layer recipe (landed at the pin) | **Yes** | Add a quickstart block and a shallow-clone note | none |
| `project.godot` | Engine entry point; carries the `untyped_declaration=2` tripwire | **Yes** (required) | Add `config/version` | none |
| `.gitignore` | 200 lines, more than half prose rationale | **Yes** | Move the long historical rationale into `docs/DECISIONS.md`; keep patterns + one-line reasons | none — comments only |
| `.editorconfig` | tabs for `.gd`, spaces elsewhere | **Yes** | none | none |
| `.github/workflows/harness.yml` | 3-job CI | **Yes** | See §CI findings | none |
| `.githooks/{pre-commit,commit-msg}` | identity + trailer gates; `core.hooksPath` verified set | **Yes** | none | none |
| `_moment_*.png` ×52 (**71 MB**) + `.import` ×32 | Canonical named-moment captures, indexed by `docs/CAPTURE_MANIFEST.md` | **No** | `git mv` to `docs/media/moments/`; repoint `capture_moments.gd`, `capture_manifest.sh`, `zoom.gd`, `mock_*.gd`, README image links | **Medium** — `res://` paths are addressed by string in ≥5 tools; the manifest `--check` gate will catch a miss, and it currently PASSES so it is a usable before/after control |
| `_moment_water{,_body,_rock}.png.import` ×3 | **Orphan sidecars** — the images they describe were untracked by `git rm --cached`, the sidecars were not | **No** | `git rm --cached` the three `.import` files (files stay on disk, per house rule) | **Low** — nothing resolves them |
| `_crop_boot.png`, `_crop_stain.png` | Crops, tracked *before* `.gitignore:89` `/_crop_*.png` was added — currently tracked **and** ignored | **No** | Move to `docs/media/` if wanted as evidence, else `git rm --cached` | **Low** |
| ~~`AUDIT_REPONSE.md` (64 KB)~~ | **DONE 2026-08-24, spelling call reversed.** The file itself carries a note this audit missed: *"AUDIT_REPONSE.md preserves the spelling requested by the user."* Moved to `docs/handoff/AUDIT_REPONSE.md` (root entry gone, the actual goal); the spelling is kept, not fixed, since it was a deliberate past user choice this ticket would otherwise have silently overridden. Also stale: "2 tracked citations" — `git grep -l AUDIT_REPONSE` (tracked files only) returned zero before this move; every citation lived in an already-gitignored doc | — | — |
| `_capture_*.png` ×18, `_mock_*.png` ×5, `_diag_*.png` ×5, `_miner_sheet.png` | Diagnostic/eyeball renders; correctly gitignored | **No** (on disk only) | Leave; optionally relocate to a gitignored `scratch/` so the root listing is short for the developer too | none |
| `_moment_prev/` (14 entries, 9.6 MB) | One-generation undo for the captures; gitignored | **No** | Move under `scratch/` with the above | none |
| `history/` (281 on disk, **166 tracked, 228 MB**) | Curated dated screenshot archive; `.gdignore` present so Godot skips it | Defensible | Keep tracked (explicit user instruction). Consider `git lfs` or a `history` orphan branch **only** as a director decision | **High** — it is the sacred archive; do not touch without per-item confirmation |
| `docs/` (30 entries; 19 tracked `.md` + `media/`) | Design, decisions, architecture, manifests | **Yes** | See §Documentation | none |
| `src/`, `scenes/`, `tests/`, `tools/`, `assets/` | Sim / representation / suites / harness / art | **Yes** | none | none |
| `.claude/` (**8.5 GB**, 39 worktrees) | Agent worktrees; gitignored | **No** | Prune to the actively-owned set (per-item confirmation) | **Medium** — unmerged work lives here; see §Do-not-do |
| `.godot/` (166 MB), `.DS_Store` | Engine cache / macOS noise; ignored | n/a | none | none |

**Post-move root would be 12 entries.** That is the single highest-ratio presentation change available.

---

## Critical findings

No P0. Ranked P1 first, then the P2s that a reviewer would raise.

### P1-1 · The published repository is 135 commits stale and its last CI run is red

- **Severity:** P1 — it is the entire portfolio surface.
- **Evidence:** `git ls-remote origin refs/heads/main` → `aa52ace`; `git rev-list --count origin/main..HEAD` → **135**; `gh run list` → most recent completed run against `main` is `failure` (`32321357033`), preceded by two `cancelled` and two further `failure` runs.
- **Impact:** Every improvement of the last two-and-a-half weeks is invisible. A reviewer sees a red cross and a README that (honestly) confirms it.
- **Confidence:** Certain. **Observed.**
- **Recommendation:** Get the pixels job green locally (`SF_GL_ONLY=1 SF_STRICT=1`), then push. Do not push red.
- **Effort:** M (bounded by P1-2). **Owner:** director + harness owner.
- **Closure evidence:** `gh run list --limit 1` on `origin/main` shows `success`; `git rev-list --count origin/main..HEAD` = 0.

### P1-2 · Three display-dependent layers fail on the published tip

- **Severity:** P1 — they are assertions about what the player sees, and one of them is a HUD collision gate.
- **Evidence:** run `32321357033` pixels job: `check_grapple_reads` FAIL (`and a taut one does not (0.463 slack against 0.462 taut)` — the bow measure does not distinguish the two rope states), `check_hud_layout` FAIL (2 failures), `check_snap_frame` FAIL. `check_ceremony_reads` additionally reported `PASS*` with one assertion stood down.
- **Impact:** Either three real presentation defects, or three broken instruments. Both are P1: this repository's own doctrine is that a gauge which cannot register its subject is the dominant failure class here.
- **Confidence:** The failures are certain at `aa52ace`. **Whether they still fail at the pin is Unknown** — 135 commits have landed, several of them on `check_grapple_reads` (`+198/-20`) and `check_hud_layout` (`+236/-13`).
- **Recommendation:** Re-run the three alone on a quiet machine before diagnosing anything. For `check_grapple_reads`, note that a bow measure returning `0.463` vs `0.462` is a *near-identity* — screen the instrument (does the fixture actually pull the rope taut?) before screening the renderer.
- **Effort:** M. **Owner:** harness owner.
- **Closure evidence:** three green layers in a `SF_GL_ONLY=1 SF_STRICT=1` run, plus a stated cause for each.

### P1-3 · `_paint_godrays` runs an O(cols × rows) scan three times per column, every frame, uncached

- **Severity:** P1 for scalability; P2 for today's frame budget.
- **Evidence:**
  - `scenes/world_renderer.gd:575-578` — `_process` calls `queue_redraw()` and `_lights.queue_redraw()` **unconditionally every frame**.
  - `scenes/world_renderer.gd:4319-4320` — `_paint_lights()` calls `_paint_godrays(layer)` first.
  - `scenes/world_renderer.gd:4459-4465` — `for col in range(FactorySim.GRID_COLS)` with **three** `sim.surface_row()` calls per iteration.
  - `src/core/factory_sim.gd:541-546` — `surface_row()` is a linear scan `for row in range(0, GRID_ROWS)` doing a `Dictionary.has()` per row, returning at the first non-foliage solid.
  - `grep -rn "_surface_cache\|surface_cache"` → **no cache exists anywhere.**
  - `grep -c "sim.surface_row" scenes/world_renderer.gd` → 11 call sites, several inside per-frame paths (`_paint_lights` lamp scaling at 4351, seam darkness at 4396, glint darkness at 1184).
- **Impact:** Worst case **128 cols × 3 × 128 rows = 49,152 dictionary lookups per frame** from this one function, before the other eight call sites. Cost is O(GRID_COLS × GRID_ROWS): a 256×256 world would be 4× this. It is also the exact trap `docs/ORCHESTRATOR.md` §9.7 records — *"`surface_row()` scans are hot — hoist them"* — still unhoisted.
- **Confidence:** The call structure is **Observed** and certain. The **cost is Inferred and unmeasured** — `check_frametime` passes its 120 fps budget on the developer's machine today, and it is deliberately excluded from CI, so no measurement of this path exists in any artifact. Do not describe it as a measured bottleneck.
- **Recommendation:** *Profile first, then fix.* (a) Add a `_paint_godrays` / `_paint_lights` timer to `tools/profile_frame.gd` and record the baseline. (b) Memoize `surface_row` in `FactorySim` as `Dictionary col→row`, invalidated from the same place `terrain_dirty` is appended. (c) Re-measure. The memo is safe because `surface_row` is a pure function of `solid`.
- **Effort:** S (memo) + S (profile). **Owner:** renderer owner. **Prerequisite:** exclusive machine.
- **Closure evidence:** `profile_frame.gd` before/after on the same commit and same host, plus `check_frametime` and `check_dig_hitch` unchanged or improved.

### P1-4 · 39 documentation citations from tracked files point at files that are not in the repository

- **Severity:** P1 for a *public* repository — every one is a dead reference for anyone who is not on this machine.
- **Evidence:** `.gitignore` (WORKING NOTES block) excludes `docs/tracelog/`, `docs/handoff/`, `docs/superpowers/`, `/docs/PEER_SESSIONS.md`, `/docs/ORCHESTRATOR.md`, `/docs/DIRECTOR_BRIEF.md`, `/docs/AGENT_PLAY_EVALUATION_PROTOCOL.md`, `/AUDIT_REPONSE.md`. Those paths are cited **39 times** across 14 tracked files, including 8 source/tool files: `tools/check_frametime.gd`, `check_hud_layout.gd`, `check_progressive_bake.gd`, `check_rock_reads.gd`, `check_save_durability.gd`, `check_save_isolation.gd`, `check_underground.gd`, `play_agent.gd`, `seed_corpus.sh`, and the docs `DIRECTOR_BUS.md`, `FEEL_GAP.md`, `HARNESS_LAYERS.md`, `PRIORITY.md`, `VISUAL_RECOMMENDATIONS_SURFACE.md`.
- **Impact:** A harness layer whose docstring says "see `docs/handoff/AUDIT_UPDATE.md` for why this threshold is what it is" is, to every outside reader, a threshold with no derivation — which is precisely the failure mode this repository names and forbids.
- **Confidence:** Certain. **Observed.**
- **Recommendation:** For each citation, choose one: (a) publish the cited document, (b) inline the one fact the citation was carrying, or (c) delete the citation. Then add a link-check layer restricted to tracked files so it cannot regress.
- **Effort:** M. **Owner:** docs owner + director (the publish/withhold call is a judgement).
- **Closure evidence:** a `check_doc_links` layer that resolves every `docs/…md` reference in tracked files against `git ls-files`, green, with its own non-vacuity count printed.

### P1-5 · There is no release path

- **Severity:** P1 against the "industry-standard readiness" bar; P3 against "is the game good".
- **Evidence:** `export_presets.cfg` is gitignored (`.gitignore:4`); `project.godot` has **no** `config/version`; `git tag` = 2, neither a release; no `CHANGELOG.md`; no release workflow; `gh release list` would be empty. README states the consequence honestly.
- **Impact:** Nobody — including the author on a second machine — can produce a playable build from the repository. There is no version to reference in a bug report and no artifact to attach.
- **Confidence:** Certain. **Observed.**
- **Recommendation:** Commit a sanitised `export_presets.cfg` (Linux + macOS), set `config/version="0.1.0"`, tag `v0.1.0`, add a `release` job that exports and uploads a zip on tag push. Add `CHANGELOG.md` seeded from the existing prose commit titles, which are unusually well suited to it.
- **Effort:** M. **Owner:** release owner. **Prerequisite:** P1-1, P1-2.
- **Closure evidence:** a downloadable artifact from a tagged run that launches on a clean machine.

### P1-6 · The pack cap is an invariant with four enforcement sites and no structural guard

- **Severity:** P1 for maintainability of a *recently broken* invariant; not currently a defect.
- **Evidence:** `factory_sim.gd:1695` calls `take_into_pack` *"THE ONE DOOR INTO THE PACK"*, and it is not: `take_lode` (1437) writes `inventory[item]` inline after a `can_carry` guard; `remove_sapling` (1167) writes inline after a `can_carry` guard; `collect_ground` (2905) writes inline after a `pack_room()` computation; `craft_item` (1583) writes inline under a documented exemption. All four are **correct today** — I traced each. But `check_carry_cap._the_rest_of_the_yield_paths()` is a *hand-enumerated* list of paths, and the recent history (`db6363b`, `93bd934` — *"three more paths were writing the pack inline, and one of my repairs destroyed ore"*) shows exactly how this class re-opens.
- **Impact:** A fifth yield path added tomorrow escapes both the cap and its test, silently. The designed pain stops reaching the player again, and nothing goes red.
- **Confidence:** The four sites and their guards are **Observed**. The escape is **Inferred** from the enumeration being manual.
- **Recommendation:** A pure source-scan layer (same shape as `check_posed_fields.gd`, which already does this successfully for a different class): every `inventory[` assignment in `src/` must be inside `take_into_pack`, or lexically preceded by a `can_carry`/`pack_room` guard in the same function, or listed on an explicit exemption array with a reason string. Prove it red by adding an unguarded write to a scratch mutant.
- **Effort:** S. **Owner:** sim owner.
- **Closure evidence:** the layer goes red on the mutant and green on `main`, and prints the number of sites it classified (non-vacuity).

### P2-1 · 42 worktrees, 8.5 GB, 50 branches, 2 of them unmergeable by construction

- **Evidence:** `git worktree list` = 42; `du -sh .claude/worktrees` = **8.5 G**; `git branch --merged main` = 20; `git branch --no-merged main` = 29; `git merge-base audio-per-material main` and `git merge-base presentation-glyphs main` both **fail** — no common ancestor, 402 and 399 commits respectively. **Observed.**
- **Impact:** The two orphans cannot be merged, rebased or cherry-picked by ancestry — their work can only be re-derived by reading the diff. Thirty worktrees are ≥50 commits behind and are a standing invitation to read stale code as current. 8.5 GB sits inside the project directory.
- **Recommendation:** Prune the 20 already-merged branches and their worktrees (they contain nothing not in `main` — verify per branch with `git cherry main <branch>` printing only `-`). For the 2 orphans and the 29 unmerged, produce a one-line disposition each in a **tracked** `docs/WORKTREES.md` (the untracked one exists) before removing anything. **This is not mine to execute**: the house rule requires per-item confirmation, and unmerged work is at stake.
- **Effort:** M. **Owner:** director.

### P2-2 · Three tracked `.import` sidecars describe untracked images

- **Evidence:** `_moment_water.png.import`, `_moment_water_body.png.import`, `_moment_water_rock.png.import` are tracked; their `.png` files were untracked via `git rm --cached` when the `_diag_*` split landed (`.gitignore:103-106`). **Observed.**
- **Impact:** Cosmetic, but it is exactly the tell a reviewer picks up on: a tracked file that looks current and is not. The `.gitignore` comment for that split even argues the principle it then half-applied.
- **Recommendation:** `git rm --cached` the three `.import` files. Files stay on disk. **Effort:** XS.

### P2-3 · CI downloads a 60 MB engine binary twice per push with no integrity check

- **Evidence:** `.github/workflows/harness.yml:89` and `:160` — `wget -q https://github.com/godotengine/godot/releases/... -O godot.zip && unzip -q && chmod +x && run`. `grep -c "sha256\|shasum\|checksum"` = **0**. No `actions/cache` on the download either. **Observed.**
- **Impact:** Realistic risk is low (GitHub releases, HTTPS) but non-zero, and it is the one supply-chain surface this repository has. The missing cache costs ~2 downloads × every push in CI minutes and, per the `.gitignore`'s own note, re-imports 228 MB of `history/` twice per push on top.
- **Recommendation:** Add the published SHA256 and `sha256sum -c` before `unzip`; add `actions/cache` keyed on `V`. Pin `actions/checkout` and `actions/upload-artifact` to commit SHAs. **Effort:** S.

### P2-4 · `const CELL: int = 32` is defined independently in 7 game files and ~27 tool files

- **Evidence:** `scenes/{hud,player,world_renderer,sfx,main,bazaars,grapple}.gd` each declare their own (`hud.gd` as `float`, the rest as `int`), plus `tools/` copies. Nothing relates them; `FactorySim` does not export one. **Observed.**
- **Impact:** A constant that must equal another constant, with no derivation between them — the purest instance of a defect no assertion catches because nobody wrote one.
- **Recommendation:** One definition (`FactorySim.CELL`), everything else derives, plus a source-scan assertion forbidding redefinition. `hud.gd`'s `float` variant becomes `float(FactorySim.CELL)`. **Effort:** S, mechanical, but touches 7 files — schedule it alone, not beside a renderer change.

### P2-5 · Comment density has crossed from asset to obstacle in the two largest files

- **Evidence:** tracked GDScript is **35.8% comment** by non-blank line (21,133 / 59,003). `hud.gd`: 2,135 comment lines against 2,573 code (0.83); `world_renderer.gd`: 1,797 / 2,358 (0.76). `hud.gd`'s first real function begins at **line 533** — the preceding ~500 lines are constants interleaved with multi-paragraph design essays. **Observed.**
- **Impact:** The *rationale* is the repository's best feature and must not be deleted. But standing design doctrine (the gold-accent role analysis, the focal hierarchy argument) is not local "why" — it is `DECISIONS.md` content living in a source prologue, where it pushes the code below the fold and where, by this project's own rule, it becomes a claim nobody re-checks.
- **Recommendation:** Move *standing rules* to `docs/DECISIONS.md` with a one-line back-reference at the site; keep *local* why (why this branch, why this constant) inline. Target: first `func` in `hud.gd` above line 150. **Effort:** M, docs-only, zero behaviour risk.

### P2-6 · 13 registered layers bypass `check_base.gd` and hand-roll the exit protocol

- **Evidence:** `check_bake_idempotent`, `check_body_stress`, `check_fastforward`, `check_fixture_pointer`, `check_grid`, `check_score`, `check_snap_frame`, `check_step`, `check_texture`, `check_water_audio`, `measure_player`, `play_tests`, plus the non-layer `save_sentinel` — all `extends SceneTree` directly. 84 layers use the base. **Observed.**
- **Impact:** The runner's own `fail_lines()` comment records the cost: *"`check_base.gd` prints `  FAIL: label` and 79 layers inherit that, but the 11 layers that extend SceneTree each rolled their own"* — and a pattern written against the base class routes those into the "the layer DIED" diagnosis branch, answering a real assertion failure with a confident wrong cause. The runner now works around this rather than the layers being fixed. Note that **`check_snap_frame` — one of the three CI failures — is on this list.**
- **Recommendation:** Port all 13 to `check_base`, one per commit, harness-green after each. **Effort:** M.

### P3s worth a line each

- `world_seed` defaults to `0` for a v1 envelope (`save_game.gd:_stage`), re-molding fine terrain from the wrong seed. Cosmetic-only (fine terrain is derived), pre-1.0, no shipped saves. Prefer refusing the envelope over defaulting it.
- `tools/check_hud_layout.gd:1229` — `_check(bare >= 0.0, "the bare screen was measured for footprint")` is unconditionally true for a fraction. Harmless: the very next assertion is `bare > 0`. Fold them.
- Two absolute personal paths in tracked docs: `docs/DIRECTOR_BUS.md:35,44` and `docs/PRIORITY.md:409` (`/Users/thondascully/...`). Replace with `tools/director_bus.sh …`.
- `docs/PRIORITY.md:1064` cites `docs/REPOSITORY_MAP.md`, which does not exist. It is conditional ("only if"), so it is a plan, not a broken link — but it reads as one.
- `FineTerrain` names two unrelated classes (`src/core/fine_terrain.gd`, the sim's molding module, and `scenes/fine_terrain.gd`, the renderer's baker). Rename one.
- 23 of 52 tracked `_moment_*.png` have no tracked `.import` sidecar while 29 do. Godot regenerates them, so it is harmless — and it is an inconsistency a reviewer will notice.

---

## Architecture map

### The dependency graph, as verified rather than as documented

```
                       ┌──────────────────────────────────────────┐
   CI  .github/         │  NOTHING BELOW THIS LINE MAY LOOK UP     │
   workflows/           └──────────────────────────────────────────┘
   harness.yml ──┐
                 │
   tools/  (112 files, 33,773 LOC)   tests/ (5 files, 4,439 LOC)
   run_harness.sh · check_*.gd       test_base.gd + 4 suites
   play_tests · play_agent           builds a FactorySim with NO SCENE TREE
        │            │                       │
        │            └───────────┬───────────┘
        │  boots scenes/main.tscn│  constructs src/ directly
        ▼                        ▼
   ┌─────────────────────────────────────────────────────────────┐
   │ scenes/   REPRESENTATION  (24 files, 21,180 LOC)            │
   │   main.gd 2,864     the only input→verb crossing point      │
   │   world_renderer 4,517 · hud 5,098 · visuals 1,518          │
   │   fine_terrain 1,317 · sfx 1,212 · player 886 · +16 more    │
   │   5 .gdshader                                                │
   └───────────────────────────┬─────────────────────────────────┘
                               │  132 refs to FactorySim, 13 to SaveGame,
                               │  37 MachineState, 32 MiningRules, 30 Seams
                               ▼               (ONE DIRECTION ONLY)
   ┌─────────────────────────────────────────────────────────────┐
   │ src/      AUTHORITATIVE SIMULATION  (18 files, 5,490 LOC)   │
   │   core/factory_sim.gd 2,915   RefCounted · 20 Hz · 157 funcs│
   │        ├─ water_flow · power_flow · flora · fine_terrain    │
   │        ├─ save_game.gd 362    versioned envelope v2         │
   │        └─ machine_state.gd                                  │
   │   core/world_gen ◄─ heightmap_world_gen ◄─ layered_world_gen│
   │        └─ world_data.gd   the gen→sim handshake, plain data │
   │   data/  machine_def · material_def · recipe_def · seams    │
   │          mining_rules · bit_rules · research_rules          │
   │          machines/*.tres (20) materials/*.tres (16)         │
   │          recipes/*.tres (6)                                 │
   └─────────────────────────────────────────────────────────────┘
```

**The seam is real and I verified it four ways.** `grep -rn "get_tree()" src/` → **0**.
`grep -rn "res://scenes" src/` → **0**. Every `extends` in `src/` is `RefCounted`, `Resource`, or
another `src/` script — **no `Node` anywhere**. The only engine call in the whole of `src/` is
`OS.get_environment` / `OS.get_cmdline_args` in `save_game.gd:273-277`, and it exists solely to refuse
a dangerous fixture write. The reverse direction is dense (132 `FactorySim` references from
`scenes/`) and correct. The README's claim that *"you could delete the player entirely and the
production numbers would be identical"* is architecturally enforced, not aspirational. **Observed.**

| Layer | Owner files | Authoritative? | Depends on | Depended on by |
|---|---|---|---|---|
| Simulation | `src/core/factory_sim.gd` + 4 extracted algorithms + `machine_state.gd` | **Yes** — all production state and math | `src/data/*` only | `scenes/*`, `tests/*`, `tools/*` |
| Data definitions | `src/data/*.gd` + 42 `.tres` | Yes (content) | nothing | sim, renderer, HUD, harness |
| World generation | `world_gen` ← `heightmap_world_gen` ← `layered_world_gen`, meeting the sim through `world_data.gd` | Yes (produces) | `src/data` | `FactorySim.load_world`, `test_worldgen` |
| Persistence | `src/core/save_game.gd` | Yes (serialises) | sim + machine defs | `main.gd` (F5/F9), 3 harness layers |
| Renderer | `world_renderer.gd`, `fine_terrain.gd`, `terrain_painter.gd`, `sky_painter.gd`, `light_layer.gd`, `particles.gd`, 5 shaders | **No** — read-only over the sim | sim, data | main |
| UI | `hud.gd`, `settings.gd`, `controls.gd`, `hover_info.gd`, `objectives.gd`, `hints.gd` | No | sim, data | main |
| Controller | `scenes/main.gd` | No — **the single input→verb crossing point** | everything | the scene |
| Tools / harness | `tools/` 112 files | No | boots the scene *or* builds a sim directly | CI |
| Tests | `tests/` 5 files | No | `src/` only, **no scene tree** | CI |
| CI | `.github/workflows/harness.yml` 3 jobs | No | `run_harness.sh` registration | — |

### The ten most expensive architectural seams, ranked

Rank = blast radius × change frequency × defect likelihood, discounted by migration difficulty, with
portfolio impression as a tiebreak.

| # | Seam | Blast radius | Change freq | Defect likelihood | Migration difficulty | Portfolio impression | Note |
|---|---|---|---|---|---|---|---|
| 1 | **`scenes/hud.gd` — 5,098 lines holding HUD, minimap, Bazaar, bench, dashboard, help, settings, tooltips** | Very high | Very high (`+2013/-317` in 133 commits) | High | High | Worst single-file impression in the repo | Six unrelated screens in one file |
| 2 | **`scenes/world_renderer.gd` — 4,517 lines incl. a full lighting engine** | Very high | Very high (`+2128/-1586`) | High | Medium | Bad, but the `LightLayer` painter Callable is a ready-made extraction seam | Extract first: highest payoff, lowest risk |
| 3 | **`FactorySim`'s ~40 public mutable Dictionaries** | Very high | Medium | Medium | High | Invisible to a skim, damning on a read | No invariant can be enforced; 333 external writes exist (13 in `scenes/`, 172 in `tools/`, 72 in `tests/`) |
| 4 | **The 3-file cost of adding one machine** (`.tres` + `_BEHAVIORS` + `Visuals.MACHINE_STYLE`) | High | High | Medium (silent-fallback renderers) | Low | Good story if closed | Guarded today by `check_craftable_registry` / `check_material_registry`; the guard is the fix for the symptom, not the seam |
| 5 | **`scenes/main.gd` — 2,864 lines: input routing, camera, sim advance, mining subsystem, layout constants** | High | High | Medium | Medium | Mixed | The ~600-line mining subsystem is the obvious `digging.gd` |
| 6 | **The harness↔workflow join** | High | Medium | **Was** high | Low | Excellent — this one is *closed* | `check_ci_coverage` now asserts set equality both directions. Model for the others |
| 7 | **`const CELL` × 7 (+~27)** | Medium | Low | Medium | Low | Poor — trivially greppable | Constant that must dominate constant, with nothing relating them |
| 8 | **`play_agent`'s privileged verbs (`give`, `nearest_material`)** | Medium | Medium | Medium | Medium | Undercuts the project's most distinctive claim | The agent-play eval is the thesis; privileged inputs weaken it |
| 9 | **Two classes named `FineTerrain`** | Low | Low | Medium | Low | Poor | `src/core/fine_terrain.gd` vs `scenes/fine_terrain.gd` |
| 10 | **Captures addressed by literal `res://` string across ≥5 tools + the manifest** | Medium | Low | Low | Medium | This is what makes the root cleanup a *migration* rather than a `git mv` | The manifest `--check` gate is the safety net, and it currently PASSES |

### God files: responsibilities, seams, extraction order

**`scenes/hud.gd` — 5,098 lines (2,573 code / 2,135 comment)**

- *Responsibilities:* HUD chrome (depth chip, FORGED counter, objective line, alerts, flash, hint bubble, arrival plate) · minimap · hotbar/inventory · item tooltip · **the Bazaar counter** (rail, head, foot, detail plate, three tabs) · **the tech tree** (chips, art, next-step lamp) · **the production dashboard** · **the help overlay** · **the settings screen** (rail, head, detail, key capture) · a ~500-line constants-and-doctrine prologue.
- *Seams that already exist:* every screen is entered through exactly one `_draw_*_overlay()` and has its own geometry function (`_settings_geometry`, `works_columns`, `_remap_per_col`). The palette constants are shared and belong to none of them.
- *Safest extraction order:* (1) `scenes/ui/theme.gd` — the palette + `bottom_furniture_fraction()` + the layout constants, referenced by name; zero behaviour risk, and it removes the 500-line prologue. (2) `scenes/ui/settings_screen.gd` — most self-contained, has its own harness layers (`check_settings`, `check_binding_conflict`, `check_binding_persistence`, `check_binding_text`). (3) `scenes/ui/bazaar_screen.gd` — guarded by `check_pack_layout`, `check_row_identity`, `check_item_reads`. (4) `scenes/ui/dashboard.gd`. (5) `scenes/ui/tech_tree.gd`. Leave the always-on HUD chrome in `hud.gd`.
- *Risk of behaviour change:* Low for (1), Medium for (2)–(5) — every one of them draws into the same `CanvasLayer` and reads `_hud`-private state; a moved field is a silent blank panel.
- *Tests needed BEFORE starting:* `check_hud_layout` **must be green first** (it is currently one of the three CI failures) — it is the only instrument that measures panel rectangles across 15 states and it is the extraction's whole safety net. Add a per-state footprint baseline before the first move and diff it after each.

**`scenes/world_renderer.gd` — 4,517 lines (2,358 code / 1,797 comment)**

- *Responsibilities:* coarse terrain bake + chunked dirty repaint · fine mold pass hand-off · lode/stain · machines, status lamps, nameplates, IO, load gauges · water · conduits and power pulses · ropes, torches, saplings · **the entire lighting engine** (`_update_veil`, `_paint_lights`, `_paint_godrays`, `_paint_machine_pools`, `_draw_glow`, skylight) · aim/preview overlays · scan sonar · speed streaks · grapple.
- *Seams that already exist:* `LightLayer.setup(z, painter_callable, blend)` is a genuine plug point — the lighting passes are **already** injected as Callables (`world_renderer.gd:449`). Extraction is moving functions, not rewiring.
- *Safest extraction order:* (1) `scenes/render/lighting.gd` — everything reachable from `_update_veil` and `_paint_lights`, ~560 lines, moved behind the existing Callable. **Do the `surface_row` memo (P1-3) as part of this move, not before or after.** (2) `scenes/render/water_painter.gd`. (3) `scenes/render/machine_painter.gd` (`_draw_machine*`, ~600 lines). (4) `scenes/render/preview_overlays.gd`.
- *Risk of behaviour change:* Medium. Draw **order** is semantic here (z-indices 45/51, blend modes, the veil-then-pool sequence). A reordered call is a visibly different frame that no sim test can see.
- *Tests needed BEFORE starting:* a full `_moment_*` capture set on the pre-move commit as the comparison baseline, plus green `check_underground`, `check_rock_reads`, `check_contact_edge`, `check_water_reads`, `check_casing_light`, `check_machine_state`, `check_bake_idempotent`. Use the >0.20-threshold histogram + magenta diff-map protocol the repo already documents; the ~38% run-to-run animation-phase noise floor makes a naive pixel diff useless.

**`src/core/factory_sim.gd` — 2,915 lines, 157 functions (98 public)**

- *Responsibilities:* all authoritative grids (`solid`, `wall`, `deposits`, `lode`, `lode_max`, `water`, `fill`, `conduit`, `rope`, `torch`, `sapling`, `ground`, `sink`, `research`) · the machine array and cell grid · the tick loop and 11 `_BEHAVIORS` per-tick hooks · the player verb API · the pack and its cap · conservation counters.
- *Seams that already exist:* `_BEHAVIORS` dispatches by **method name string** (deliberately not a bound `Callable`, to avoid a per-sim reference cycle) — which means a behaviour can be relocated without touching the dispatch table's shape. `water_flow.gd`, `power_flow.gd`, `flora.gd`, `fine_terrain.gd` are the proof that this decomposition works.
- *Safest extraction order:* (1) `src/core/pack.gd` — the cap, `is_bulk_item`, `carried_bulk`, `pack_room`, `can_carry`, `take_into_pack`, `_spill_to_world`; small, already cohesive, and it turns P1-6's "four doors" into "one module". (2) per-behaviour modules for the four largest hooks (`_run_drill` 93 lines, `_run_h_drill` 52, `_run_drift` 45, `_run_hopper` 43). (3) `src/core/terrain_ops.gd` for `mine`/`place`/`surface_row`/foliage settling.
- *Risk of behaviour change:* **Low for (1) and (3), Medium-High for (2)** — behaviour hooks read and write sim state freely, and moving one changes nothing *unless* it changes the order in which two machines touch the same cell in a tick, which is a determinism break.
- *Tests needed BEFORE starting:* `tests/test_sim.gd` (427 assertions incl. the capture→restore→tick→signature determinism canary) and `tests/test_stress.gd` green, plus a recorded 1000-tick signature on a fixed seed as an external before/after. Note the known coverage hole: `_seep_tick` is now in `SaveGame.capture` (v2) — confirm `_rate_tick` still is not, and that it is genuinely derived, before trusting the canary over any behaviour move.

**`scenes/main.gd` — 2,864 lines**

- *Responsibilities:* input routing (the one crossing point) · camera and zoom · sim advance and the tick accumulator · **the mining/pick subsystem (~600 lines)** · dig-plan painting · layout constants · the `_craftable` registry · juice/screen-shake.
- *Safest extraction order:* (1) `scenes/digging.gd` — the mining subsystem and dig-plan painting; guarded by `check_mining`, `check_refusal`, `check_dig_hitch`, `check_spoil`, `check_carry_cap`. (2) `scenes/camera_rig.gd`. Keep input routing in `main.gd`: its single-crossing-point property is architectural and must not be diluted.
- *Risk:* Medium — `check_dig_hitch` is `add_excl` and timing-sensitive; measure it alone before and after.

---

## Test-truth audit

**Scope statement, so this is not read as a full census.** The suite registers **100 layers across
101 scripts**. I read the source of **21 layers and all 5 test-suite files** in full or in substantial
part, and ran three static scans across all of them (vacuous `>= 0` on counts, `_check(true)` without
a reachable false branch, assertions against clamp bounds, and identical-expression comparisons). The
remaining ~79 layers were **inventoried but not individually read**. That is a real coverage limit and
it is stated here rather than implied away.

### What the static scans found, across all 101 scripts

| Pattern hunted | Hits | Verdict |
|---|---|---|
| `_check(<count/size> >= 0, …)` — unfailable | 1 (`check_hud_layout.gd:1229`) | Real but harmless; the next line asserts `> 0`. **P3.** |
| `_check(true, …)` with no reachable `_check(false, …)` counterpart | **0** | All 3 `_check(true)` sites (`check_fall:92`, `check_stepup:93`, `check_walk:178`) have an `else`/timeout branch asserting `false`. **Clean.** |
| Assertion compared against a `clamp` bound | 2 (`test_worldgen.gd:66,68`) | Legitimate — they pin a *known shipped defect* in both directions (`== 0.0` and `== 1.0` are the two sides of one bug), not a clamped result read back as an answer. **Clean.** |
| `x == x` tautology | 0 | The historical one (`check_seam:88`) is **repaired**, with the repair explained at `check_seam.gd:77-79`. **Clean.** |
| Registered layers with **zero** `_check` calls | 13 | Not vacuous — they hand-roll assertions and exits. It is the P2-6 protocol divergence, and the runner explicitly works around their 4 distinct output formats. |

### The layer-by-layer table (representative, not exhaustive)

| Test / layer | Claimed guarantee | Actual guarantee | False-positive risk | Unsafe / contaminated? | Recommended change |
|---|---|---|---|---|---|
| `tests/test_sim.gd` (45 funcs, 427 assertions) | Deterministic state transitions, conservation, save round-trip | As claimed, on a node-free sim. Determinism proved by capture→restore→tick→signature | **Low** — signature comparison over a real tick pair | No — builds a sim, touches no disk | Add the 1000-tick fixed-seed signature as an *external recorded constant*, so a refactor that changes it must change a file |
| `tests/test_worldgen.gd` (128 assertions) | Generated worlds hold their invariants | As claimed **at seed 1337**; some assertions do sweep seeds | **Medium** — feel-adjacent floors are single-seed. `ORCHESTRATOR` §5 names this: a tweak leaving 1337 pleasant and 4242 oreless passes everything | No | Run every *feel* floor over ≥8 seeds and assert the **worst** seed, not the default |
| `tests/test_stress.gd` (39 assertions / 1,025 lines) | Invariants under load, flow, power | Fewer assertions per line than any other suite | **Medium** — a stress suite that asserts 39 times over 1,025 lines is mostly *setup* | No | Print and assert the workload it generated (ticks, machines, items moved), so an early-exiting stress run cannot pass quietly |
| `tests/test_power_water.gd` (56 assertions) | Field/flood behaviour | As claimed | Low | No | — |
| `check_save_isolation` | No fixture can *name* the production slot | Source scan only — **cannot** see a runtime-assembled path | Low for its actual claim | No | Correctly paired with `save_sentinel`'s empirical half. Keep both; neither alone is sufficient and both say so |
| `check_save_durability` (69 assertions) | Truncation / corruption / backup-recovery behaviour | As claimed, per-key ablation included | **Low** | No | — |
| `check_save_frontier` | Every sim field is in the envelope | Guards the coverage hole class directly | Low | No | Verify it covers `_rate_tick` and the `flow` behaviour hook, both named as historical holes |
| `check_carry_cap` (39 assertions) | The cap bites **on the verb** | Exactly that, with both-direction controls and non-vacuity fixtures. **Best-designed layer in the suite** | **Very low** | No | Its yield-path list is hand-maintained → P1-6 |
| `check_ci_coverage` (19 assertions) | Every registered layer runs in some CI job | Set equality both directions, counts asserted first | Very low | No | — |
| `check_frametime` (`add_excl`, **CI-EXCLUDED**) | 120 fps budget + hitch ratios | Real, **on one machine only**. Absolute budget fires only under a named `SF_PERF_HOST` | Low locally; **the guarantee simply does not exist in CI** | No | Correct exclusion (measured: opposite verdicts on x86_64 vs arm64 software rasterizers). Add a *relative-to-recorded-baseline* perf job that can run anywhere, so CI has some perf signal |
| `check_dig_hitch` (`add_excl`, `add_gl`) | A dig is not a stall | Real — and it once passed comparing two blank dummy-renderer surfaces. Now correctly `add_gl` | Low now | No | Keep the historical note; it is the best example in the repo of a pass that was not a verification |
| `check_rock_reads`, `check_material_grammar`, `check_contact_edge` | Rock reads as different from air / dirt from stone / edges carry a step | Real, with **demonstrated red states via knockout** and self-disqualifying cues (ANISO excluded at 80% on the null) | Low | No | Model layers. The disqualification ledger should be a tracked doc, not only comments |
| `check_grapple_reads` (`add_gl`, `add_excl`) | The rope tool reads as a tool | **Currently FAILING on the published tip** at `0.463 slack vs 0.462 taut` | — | Was intermittent under load; `add_excl` "removes the condition, not the cause", which the file says out loud | Screen the **actuator** before the renderer: prove the fixture actually pulls the rope taut |
| `check_hud_layout` (`add_gl`, 70 assertions) | No HUD panel collisions across 15 states | **Currently FAILING (2)**. Structurally it cannot see world-space overlaps — that is `check_ceremony_reads`' population | — | No | Must be green **before** any `hud.gd` extraction |
| `check_snap_frame` (`add_gl`) | Pixel snap reaches the framebuffer | **Currently FAILING**. Exists because the other half's docstring cited a file that never existed | — | No | Also on the `extends SceneTree` list (P2-6) |
| `check_ceremony_reads` (`add_gl`) | An interrupt does not print over world-space geometry | Real; the *other plane* `check_hud_layout` cannot reach | — | Reported `PASS*` in the last CI run — one assertion stood down | Close the stood-down assertion or state why it is permanent |
| `check_posed_fields` | Fixtures do not pose a field the game recomputes | Pure source scan over `scenes/`, `src/`, `tools/`. Guards a real class (10 menu captures of a counter nobody was standing at) | Low | No | **The template for P1-6's new layer** |
| `check_trailers.sh` (shell layer) | One author, no trailers, hooks installed | Real, and it refuses to report on a shallow clone rather than pass on one | Low | No | **But:** the `headless` CI job checks out at default depth 1 and runs the whole registration, which includes this layer. Verify it SKIPs (with a reason) rather than FAILs there — otherwise it is a permanent red or a permanent excused skip |
| `check_pack_layout` (47 assertions) | The counter holds 20 rows unsqueezed | Real **now** — the historical version read back a value the function under test had just clamped; the repair asks the *demand* before the clamp | Low | No | Exemplary repair; leave the explanation in place |
| `check_plunge` | A rope descent covers real rows | Real. Its own fixture once yanked the body 10.7 px sideways every 8 frames and the layer printed it as a world defect | **Medium** — it drives the game, so it measures driver∘world | No | Keep the actuator probe it now carries |
| `check_loop_health` | The first-automation arc completes and scores | **Withholds the scalar on an incomplete arc** — because an early dead-end scored 98.6/100 and was read as merge-ready. Also asserts the sampler actually sampled | Low now | No | Best example in the repo of a score that had to be *taken away* to become true |
| `play-tests` (`play_tests.gd`, 1,478 lines, 16 goals) | A scripted pilot reaches each goal through real reach-gated verbs | Real end-to-end integration. **Weakened by:** best-of-3 (the number enforced is the best of three, not the typical one) and privileged pilot inputs (`give()`, `nearest_material()`) | **Medium** | No | Report median-of-3 alongside best-of-3; split `PLAYER_LEGAL` from `FIXTURE_ONLY` and print the privileged-input count per goal |
| `measure_player` | Motion feel numbers | Runs on the spawn plateau — the surface whose integrity is `ORCHESTRATOR` trap #2 | **Medium** — one hole in that surface reds four unrelated-looking layers | No | A dedicated `check_plateau_intact` layer would make the four-red signature self-diagnosing |
| The 172 direct `sim.<grid>[...] =` writes across `tools/` | — | Fixtures pose state rather than driving verbs | **This is the suite's structural weak point** | No | Not all are wrong (posing a world to test a renderer is legitimate). But each layer should print whether it *drove* or *posed*, so the two are never conflated in a summary |

### Which green checks are trustworthy, weak, skipped, or misleading

- **Trustworthy** (assertion structure verified; failing path reachable; non-vacuity guarded): the four `tests/` suites, `check_carry_cap`, `check_save_durability`, `check_save_frontier`, `check_save_isolation`, `check_ci_coverage`, `check_posed_fields`, `check_pack_layout`, `check_loop_health`, `check_rock_reads`, `check_material_grammar`, `check_contact_edge`, `check_dig_hitch`, `check_bake_idempotent`.
- **Weak** (real, but narrower than the name suggests): `test_stress` (39 assertions / 1,025 lines), the single-seed worldgen *feel* floors, `play-tests` (best-of-3 + privileged inputs), `measure_player` and the three layers that share the spawn-plateau dependency, `check_plunge` (driver∘world).
- **Skipped by design**: 15 layers skip in the headless CI job (correctly — no display). `check_frametime` is excluded from CI entirely, and stated as such via `SF_NOT` + a structured `CI-EXCLUDED` marker that `check_ci_coverage` asserts exists. **Nothing was found silently skipping.**
- **Misleading**: none found. The one candidate — `check_hud_layout:1229` — is immediately followed by the assertion that makes it honest.
- **Currently red**: `check_grapple_reads`, `check_hud_layout`, `check_snap_frame` (at `aa52ace`; status at the pin **Unknown**).

**Do not read the layer count as coverage.** The README already refuses to: *"92 is a count of
registered layers. It is not a coverage figure, and none is claimed here."* That sentence is the
single most credible thing in the repository's self-description, and it should survive every rewrite.

---

## Public-repository review

### The first five minutes, honestly

**0:00 — the file list.** ~90 root entries. 85 of them are `_moment_*.png` and `.png.import`.
Reaction: *"this is somebody's working directory."*

**0:20 — the CI badge area.** No build badge. A red ✗ on the head commit. Reaction: *"it doesn't
build."* (The README explains why, three screens down; nobody scrolls first.)

**0:40 — clone size.** 326 MB. Reaction: *"I'm not cloning this."*

**1:00 — the README.** This is where the impression inverts. It is **excellent**: a clear technical
thesis in the first three lines (*"gravity carries a machine's output downward for free; moving
anything back up costs power; production lines therefore grow vertically"*), two screenshots that show
the game rather than decorate the page, a controls table, a precise architecture section, and — most
unusually — a *"What that run does and does not establish"* subsection that publishes the suite's own
non-claims, plus a paragraph that says **CI is currently red and names the three failing layers**.
Very few public repositories do that. It is the strongest single signal of engineering maturity in the
whole project.

**3:00 — `src/`.** 18 files, no `Node`, no `get_tree()`, a versioned save with a migration chain.
Reaction: *"whoever wrote this knows what a seam is."*

**4:00 — `tools/`.** 112 files, 33,773 lines. Reaction splits. A charitable reviewer: *"that's a
serious verification culture."* A skeptical one: *"the harness is bigger than the game — is this a
game or a test-harness project?"* Both readings are available and nothing in the repository chooses
between them for the reader.

**5:00 — `scenes/hud.gd`.** 5,098 lines. Reaction: *"and there it is."*

### What they would praise

- The simulation/representation seam, and that it is *enforced* rather than asserted.
- The README's honesty — publishing a red CI result and the suite's non-claims.
- `save_game.gd`. A reviewer who reads that file will trust the author with production data.
- Commit messages. 876 commits in a consistent prose register that state **what changed and why**,
  e.g. *"fix(water): the waterline was sampled every 32px and the ripple constant said 46"*,
  *"harness: the lesson gate had no assertion, and a gate nobody tests is a gate nobody notices
  losing"*. This is rarer than good code.
- The three-state harness protocol and `check_ci_coverage`. Both are defect *classes* being closed.
- Zero third-party dependencies with an exactly-pinned engine.

### What they would question

- *"Why is the harness bigger than the game?"* — and the honest answer (agentic development needs a
  denser safety net than human development) is **not written anywhere published**.
- *"Why is CI red, and why has it been pushed red?"*
- *"Why are there 52 screenshots in the root?"*
- *"Why does `check_frametime` not run in CI?"* — good answer, and it *is* published.
- *"Is there a release?"* — no.

### What would cause an immediate downgrade

1. **The red CI cross.** Universal, instant, pre-verbal.
2. **The root directory.** Reads as an active scratchpad, which contradicts everything the README then
   claims about discipline.
3. **`hud.gd` at 5,098 lines** — a reviewer who opens exactly one source file will often open the
   biggest one.
4. **No release, no tag, no version.** Reads as "never finished anything", fairly or not.

Everything on that list is fixable in under a week and none of it requires touching the game.

---

## A+ target state

Every target below is a command or an observation, not an adjective.

| # | Category | Observable A+ condition |
|---|---|---|
| 1 | Repository organization | `git ls-files \| grep -v /` returns **≤ 12** entries, all of them files a reviewer expects. No tracked `.import` without its image (`for i in $(git ls-files '*.png.import'); do git ls-files --error-unmatch "${i%.import}"; done` exits 0 for all). No tracked file matches a `.gitignore` pattern. |
| 2 | Architecture | `grep -rn "get_tree()" src/` = 0 **and** `grep -rn "res://scenes" src/` = 0 **and** every `src/` `extends` resolves to `RefCounted`/`Resource`/`src/` — asserted by a registered layer, not by this document. No file in `scenes/` or `src/` exceeds **1,800 lines**. |
| 3 | Modularity | `grep -rc "const CELL" scenes/ src/` sums to 1. Adding one machine touches exactly **2** files (`.tres` + one registry), enforced by a layer that fails when a `.tres` has no `MACHINE_STYLE` entry *and* no `_BEHAVIORS` row. |
| 4 | Code quality | Comment fraction of non-blank lines **< 30%** repo-wide and **< 30%** in every file over 1,000 lines; the first `func` in every file appears before line 150. `untyped_declaration=2` retained. |
| 5 | Maintainability | `wc -l docs/PRIORITY.md` **< 200**, with an append-only `docs/PRIORITY_ARCHIVE.md` beside it. Every doc carries a `Status:` line (authoritative / historical / aspirational) in its first five lines. |
| 6 | Correctness | A `check_pack_door` source-scan layer is registered, green, and demonstrably red on an unguarded-write mutant. `SaveGame` refuses rather than defaults every field whose absence changes future behaviour. |
| 7 | Reliability | Three consecutive full sweeps at the same commit, on an idle machine, exit 0 with `partial = 0` and `skip = 0` under `SF_STRICT=1`. |
| 8 | Save / data safety | Already near-target. A+ adds: a fuzz layer feeding N truncated/bit-flipped envelopes and asserting `restore()` returns `false` with the live sim byte-identical for every one; and no `.get(key, default)` in `_stage` for any field whose default changes behaviour. |
| 9 | Test validity | Zero registered layers `extends SceneTree` (all on `check_base`). Every layer prints a non-vacuity count. A tracked `docs/DISQUALIFIED_CUES.md` records every cue excluded by a null control and what it was the only instrument for. |
| 10 | Integration coverage | `play_agent` has two namespaces; every `play_tests` goal prints its privileged-input count; **≥ 8 of 16 goals at zero**. Median-of-3 reported beside best-of-3. Every worldgen *feel* floor asserted on the worst of ≥8 seeds. |
| 11 | CI quality | `gh run list --limit 10 --branch main` shows **10 consecutive successes**. Engine download checksummed and cached. All actions pinned to SHAs. A perf job exists that can run on shared hardware. `git rev-list --count origin/main..HEAD` = 0. |
| 12 | Performance discipline | A committed `docs/PERF_BASELINE.md` with host, commit and p50/p95 for IDLE/RUN/DIG/SWING. No O(cols×rows) scan on a per-frame path — asserted by a source-scan layer listing the memoized accessors. |
| 13 | Documentation | A link-check layer over tracked files resolves **100%** of `docs/…` references. Every tracked doc has a `Status:` line. No absolute personal path in any tracked file. |
| 14 | Onboarding | A timed dry run on a clean machine: clone → run → run one test layer → understand a failure, **in under 20 minutes**, using only tracked files. `CONTRIBUTING.md` opens with a ≤10-line quickstart. |
| 15 | Release readiness | `gh release list` shows `v0.1.0`; a downloaded artifact launches on Linux and macOS; `project.godot` carries `config/version`; `CHANGELOG.md` exists and the tag matches its top entry. |
| 16 | Security / data integrity | `grep -c sha256sum .github/workflows/harness.yml` = 2. No `@vN` action reference. A `SECURITY.md` stating the (small) threat model: local single-player, saves are the only untrusted input, `allow_objects=false`. |
| 17 | Dependency hygiene | `.github/dependabot.yml` present for the actions ecosystem; apt packages version-pinned; still zero third-party GDScript. |
| 18 | Development-process maturity | `git worktree list \| wc -l` **≤ 6**; `git branch --merged main \| grep -v '^\*' \| wc -l` = 0; a **tracked** `docs/PROCESS.md` (≤ 60 lines) explaining the lock, the bus and the worktree contract; `du -sh .claude` under 2 GB. |
| 19 | Portfolio presentation | Green badge; ≤ 12 root entries; a release; a 20-second GIF or 3-frame strip at the top of the README; `git rev-list --count origin/main..HEAD` = 0. |
| 20 | Technical-debt control | A registered `check_repo_hygiene` layer failing on: > 8 worktrees, any fully-merged branch, any orphan `.import`, any tracked file matching a `.gitignore` pattern, any absolute `/Users/` path in a tracked file. Green. |

---

## Remediation roadmap

Dependency-ordered. Effort: **XS** < 1 h · **S** 1–4 h · **M** 1–3 d · **L** 1–2 wk.

### NOW — release blockers (the public artifact is wrong)

| # | Action | Exact files | Owner role | Prerequisite | Expected evidence | Effort | Risk | Parallel? | Director call? |
|---|---|---|---|---|---|---|---|---|---|
| N1 | Re-run the three failing pixel layers **alone** on an idle machine; record the verdict before diagnosing | `tools/check_grapple_reads.gd`, `check_hud_layout.gd`, `check_snap_frame.gd` via `tools/with_machine.sh` | harness owner | **machine free of other agents** | three logs with `tree:`/`head:` banner at the pin | S | Low | **No — needs the machine alone** | No |
| N2 | Fix or ticket each of the three. For `check_grapple_reads`, screen the **fixture** first (0.463 vs 0.462 is a near-identity, the signature of an actuator that did not act) | the three layers ± `scenes/world_renderer.gd`, `scenes/grapple.gd`, `scenes/hud.gd` | harness + renderer owner | N1 | each layer green with a stated cause, or a ticket naming the defect | M | Medium | Partly — 3 disjoint layers, but 2 may touch `hud.gd`/`world_renderer.gd` | No |
| N3 | Full sweep, `SF_STRICT=1`, then push the 135 commits | — | director | N2 | `ALL n HARNESS LAYERS PASS`; `git rev-list --count origin/main..HEAD` = 0; `gh run list --limit 1` = success | S | **Medium — pushing is outward-facing** | No | **Yes** |
| N4 | Checksum + cache the engine download; pin actions to SHAs | `.github/workflows/harness.yml` | CI owner | — | `grep -c sha256sum` = 2; no `@vN` remains | S | Low | **Yes** | No |
| N5 | Untrack the 3 orphan `.import` sidecars (`git rm --cached`, **never `rm`**) | `_moment_water{,_body,_rock}.png.import` | repo owner | — | the orphan scan returns empty; all 3 still on disk | XS | Low | **Yes** | No |

### NEXT — foundational (make the next change safe)

| # | Action | Exact files | Owner role | Prerequisite | Expected evidence | Effort | Risk | Parallel? | Director call? |
|---|---|---|---|---|---|---|---|---|---|
| X1 | Move the 52 captures to `docs/media/moments/` | `git mv` the set; repoint `tools/capture_moments.gd`, `tools/capture_manifest.sh`, `tools/zoom.gd`, `tools/mock_bazaar.gd`, `tools/mock_settings.gd`, `README.md`, `.gitignore` | repo owner | N3 | `git ls-files \| grep -v / \| wc -l` ≤ 12; `bash tools/capture_manifest.sh --check` still PASSES (it passes today — use it as the control) | M | **Medium** — `res://` paths are literal strings in ≥5 tools | **No** — single owner, wide touch | No |
| X2 | `check_pack_door` source-scan layer (P1-6) | new `tools/check_pack_door.gd`; register in `run_harness.sh` | sim owner | — | red on an unguarded-write mutant, green on `main`, prints the site count | S | Low | **Yes** | No |
| X3 | Doc link-check layer + repair the 39 dead citations | new `tools/check_doc_links.gd`; the 14 citing files | docs owner | **director decides publish-vs-inline** | 100% of `docs/…` references in tracked files resolve | M | Low | **Yes**, after the director call | **Yes** |
| X4 | Single `CELL` constant | `src/core/factory_sim.gd` + the 7 `scenes/` files (+ tools opportunistically) | sim owner | — | `grep -rc "const CELL" scenes/ src/` sums to 1; full sweep green | S | Low — but 7 files | **No** — schedule alone | No |
| X5 | Port the 13 `extends SceneTree` layers to `check_base` | the 13 listed in P2-6 | harness owner | N2 (`check_snap_frame` is one of them) | zero registered layers extend `SceneTree`; runner's `fail_lines()` workaround can be simplified | M | Low | **Yes** — 13 disjoint files | No |
| X6 | `check_repo_hygiene` layer | new `tools/check_repo_hygiene.gd` | repo owner | X1, and the worktree prune (X7) | green; red on a synthetic orphan | S | Low | **Yes** | No |
| X7 | Prune the 20 fully-merged branches and their worktrees; write a **tracked** `docs/WORKTREES.md` disposition line for the 29 unmerged and 2 orphans | `.claude/worktrees/*`, `git branch -d`, new `docs/WORKTREES.md` | director | `git cherry main <branch>` printing only `-` for each | `git worktree list \| wc -l` ≤ 6; `du -sh .claude` < 2 GB; every remaining branch has a written disposition | M | **Medium — deletes work** | **No** | **Yes — per-item confirmation** |

### THEN — architecture and scalability

| # | Action | Exact files | Owner role | Prerequisite | Expected evidence | Effort | Risk | Parallel? | Director call? |
|---|---|---|---|---|---|---|---|---|---|
| T1 | Profile the light pass, then memoize `surface_row` (P1-3) | `tools/profile_frame.gd`, `src/core/factory_sim.gd` | renderer owner | idle machine | before/after `profile_frame` on the same host and commit; `check_frametime`, `check_dig_hitch` unchanged or better | S | Low | **No** — timing needs the machine | No |
| T2 | Extract `scenes/render/lighting.gd` (~560 lines) behind the existing `LightLayer` Callable; land T1 inside this move | `scenes/world_renderer.gd` → new `scenes/render/lighting.gd` | renderer owner | T1, full `_moment_*` baseline captured | magenta diff-map at >0.20 threshold shows no change beyond the ~38% animation-phase noise floor; all pixel layers green | L | **Medium** — draw order is semantic | **No** | No |
| T3 | Extract `scenes/ui/theme.gd`, then `settings_screen.gd`, `bazaar_screen.gd`, `dashboard.gd`, `tech_tree.gd` from `hud.gd` | `scenes/hud.gd` → `scenes/ui/*` | UI owner | **`check_hud_layout` green (N2)** + a per-state footprint baseline | `hud.gd` < 1,800 lines; `check_hud_layout` footprint identical per state | L | Medium | **No** — one file, five moves | No |
| T4 | Extract `src/core/pack.gd`, then `scenes/digging.gd` | `factory_sim.gd`, `main.gd` | sim owner | X2 (the door layer guards the move) | 1000-tick fixed-seed signature identical before and after; `check_dig_hitch` measured alone | M | Medium | **Yes** — disjoint from T2/T3 | No |
| T5 | Split `play_agent` into `PLAYER_LEGAL` / `FIXTURE_ONLY`; report median-of-3 | `tools/play_agent.gd`, `tools/play_tests.gd` | harness owner | — | every goal prints its privileged-input count; ≥8 at zero | M | Medium — may red goals that relied on `give()` | **Yes** | Partly — dropping a goal is a director call |
| T6 | Multi-seed the worldgen feel floors | `tests/test_worldgen.gd`, `tools/check_richness.gd`, `check_descent.gd`, `check_relief.gd` | worldgen owner | — | each floor asserted on the worst of ≥8 seeds, worst seed printed | M | **Medium — will red things that pass on 1337, and that is the point** | **Yes** | **Yes** — a red here is a design question |

### LATER — polish and portfolio

| # | Action | Exact files | Owner role | Prerequisite | Expected evidence | Effort | Risk | Parallel? | Director call? |
|---|---|---|---|---|---|---|---|---|---|
| L1 | Release path: `export_presets.cfg`, `config/version`, `CHANGELOG.md`, a `release` job, tag `v0.1.0` | `project.godot`, `.github/workflows/`, new `export_presets.cfg`, `CHANGELOG.md` | release owner | N3, 10 green runs | `gh release list` non-empty; artifact launches on a clean machine | M | Low | **Yes** | **Yes** — a release is outward-facing |
| L2 | `SECURITY.md`, `.github/dependabot.yml`, issue + PR templates | `.github/` | repo owner | — | files present and rendered on GitHub | S | Low | **Yes** | No |
| L3 | Split `PRIORITY.md` into a ≤150-line live board + append-only archive; add `Status:` lines to every tracked doc | `docs/PRIORITY.md`, new `docs/PRIORITY_ARCHIVE.md`, all tracked `docs/*.md` | docs owner | X3 | `wc -l docs/PRIORITY.md` < 200; every doc has a `Status:` line | M | Low | **Yes** | **Yes** — deciding what is live |
| L4 | Publish a **tracked** `docs/PROCESS.md` explaining the harness-larger-than-the-game choice, the lock, the bus, the worktree contract | new `docs/PROCESS.md` | director | X7 | a reviewer can answer *"why is `tools/` bigger than the game?"* from published files | S | Low | **Yes** | **Yes** — it is the project's self-description |
| L5 | README top-of-page 3-frame strip or short GIF; restore the CI badge | `README.md`, `docs/media/` | presentation owner | N3, X1 | badge green on the landing page | S | Low | **Yes** | No |
| ~~L6~~ | **DONE 2026-08-24** — moved to `docs/handoff/AUDIT_REPONSE.md`; spelling kept, not fixed (see line 249 above) | `AUDIT_REPONSE.md` | docs owner | X3 | root entry gone | XS | Low | — | No |
| L7 | Comment-density pass on `hud.gd` and `world_renderer.gd`: standing doctrine → `DECISIONS.md`, local why stays | `scenes/hud.gd`, `scenes/world_renderer.gd`, `docs/DECISIONS.md` | docs + UI owner | T2, T3 | first `func` before line 150 in both; comment fraction < 30% | M | **Low but easy to do badly — deleting the why is worse than the density** | **No** | **Yes** |

---

## Parallelization plan

### Safe independent tracks (disjoint files, run simultaneously)

| Track | Owns (exclusively) | Must not touch |
|---|---|---|
| **A · CI & supply chain** | `.github/workflows/harness.yml`, `.github/dependabot.yml`, `.github/ISSUE_TEMPLATE/`, `SECURITY.md` | `tools/run_harness.sh` (shared with Track B via `check_ci_coverage` — coordinate) |
| **B · Harness protocol** | the 13 `extends SceneTree` layers, new `tools/check_pack_door.gd`, `check_doc_links.gd`, `check_repo_hygiene.gd` | `run_harness.sh` **registration block only** — a single integrator applies all `add` lines |
| **C · Docs** | all tracked `docs/*.md` except `CAPTURE_MANIFEST.md` (generated), plus `CONTRIBUTING.md`, `README.md` | any `.gd`, any `.sh` |
| **D · Sim** | `src/core/factory_sim.gd`, new `src/core/pack.gd`, `src/core/save_game.gd` | `scenes/*` |
| **E · Renderer** | `scenes/world_renderer.gd`, new `scenes/render/*`, `scenes/light_layer.gd`, `scenes/terrain_painter.gd` | `scenes/hud.gd`, `scenes/main.gd` |
| **F · UI** | `scenes/hud.gd`, new `scenes/ui/*`, `scenes/settings.gd` | `scenes/world_renderer.gd`, `scenes/main.gd` |

A–F touch disjoint file sets. **Throughput is bounded by disjoint files, not by agent count** — E and
F both draw into the same `CanvasLayer` stack, so they can run in parallel only while neither touches
`main.gd`.

### Tracks that require a shared architecture decision first

- **X4 (single `CELL`)** must be decided before D, E and F start, because all three would otherwise
  edit the same seven files. Do it **first, alone, as one commit**.
- **T5 (privileged-input split)** and **T6 (multi-seed floors)** will both turn things red on purpose.
  Agree in advance whether a red there is a bug or a design question, or an agent will "fix" it by
  moving a floor — the one thing this repository forbids most strongly.
- **X3 (dead citations)** needs the publish-vs-inline call before any agent edits a docstring.

### Work that must remain sequential

1. **Anything that boots Godot.** `run_harness.sh` and `with_machine.sh` take a machine-wide `mkdir`
   lock, and the three `add_excl` layers exist because a timing layer measures the *box*. N1, N2, N3,
   T1 and every verification run are strictly serial on this machine. This is the hard throughput
   ceiling and no amount of parallelism removes it.
2. **The registration block of `run_harness.sh`.** Every new layer adds a line there. One integrator
   applies them all; agents deliver the layer file plus the exact `add` line as text.
3. **The `hud.gd` extraction (T3).** Five moves out of one file. One owner, one at a time, harness
   green between each.
4. **Pushing to `origin`.** One actor.

### Work that should not be delegated

- **The push decision (N3)** and **the release (L1)** — outward-facing and irreversible in effect.
- **The worktree/branch prune (X7)** — it deletes work, and the house rule requires per-item
  confirmation. An agent given "clean up the worktrees" will do more than was meant.
- **Deciding what `PRIORITY.md` still holds live (L3)** — that is director judgement, not editing.
- **`docs/PROCESS.md` (L4)** — it is the project's account of itself.
- **Any threshold movement.** Not delegable at any effort level.

### Integration checkpoints

| Checkpoint | Gate |
|---|---|
| **CP1 — after NOW** | Full sweep green under `SF_STRICT=1`; `origin/main` == local `main`; `gh run list --limit 1` = success |
| **CP2 — after the capture move (X1)** | `capture_manifest.sh --check` PASSES; `README` images render on GitHub; root ≤ 12 entries |
| **CP3 — after each new layer** | The layer is proved red on a mutant *before* it is registered; registration lands in one integrator commit |
| **CP4 — before any extraction** | The guarding layers for that file are green **and** a baseline (pixel set, or 1000-tick signature) is recorded on the pre-move commit |
| **CP5 — after each extraction** | Full sweep + the recorded baseline diffed with the >0.20-threshold histogram and magenta diff map, not a naive pixel diff |

### File-ownership collision risks, named

- `tools/run_harness.sh` — **every** harness track wants a line in it. Highest-collision file in the repo.
- `scenes/main.gd` — Tracks D, E and F all have a reason to reach into it. Assign it to exactly one owner for the duration, or freeze it.
- `README.md` — Track C and Track A (badge) and X1 (image paths) all edit it. Single owner.
- `.gitignore` — X1 and N5 both edit it. Single owner.
- `docs/CAPTURE_MANIFEST.md` — **generated.** No agent may hand-edit it; only `capture_manifest.sh` writes it.
- `docs/PRIORITY.md` — director-owned. Agents propose lines; the director applies them.

---

## "Do not do this" list

1. **Do not merge a stale worktree.** Thirty are ≥50 commits behind; two share **no ancestor** with `main`. `git diff main..branch` on those is dominated by main's newer work appearing as deletions — two of them would remove ~12,000 lines. The only diff that means anything is `merge-base..branch`, and for the two orphans there is no merge base at all.
2. **Do not `rm` anything the user made.** `history/`, `assets/sprites/`, the captures, saves, notes. To exclude from the published tree use `.gitignore` or `git rm --cached` — never `rm`. And note the sharper form: **`git rm --cached` is deferred deletion** if the file is later swept by a rebase. Copy outside the repo before committing any removal.
3. **Do not lower a threshold to make a red green.** Every instance of this in the project's history was wrong. A floor may move only when you can write down *why the property was never real* — and that sentence goes next to the number, dated.
4. **Do not add more tests before repairing the instruments.** The suite already has 100 layers. A 101st that cannot fail is worse than nothing, because it consumes a sweep slot and prints a green line.
5. **Do not split a file because it is large.** Split it at a named responsibility boundary with a stated payoff and a recorded before/after baseline. `hud.gd` at 5,098 lines is six screens; that is the reason, not the number.
6. **Do not add another registry.** Adding one machine already touches `.tres` + `_BEHAVIORS` + `Visuals.MACHINE_STYLE`. A fourth list makes it worse. Derive, or guard the existing three from a single source.
7. **Do not optimize without a profile.** P1-3 (`surface_row` in `_paint_godrays`) is a *structurally certain call count* and an *unmeasured cost*. Profile first. And be specific about the frame: `check_frametime` describes one machine on a real GPU and runs in no CI job.
8. **Do not hide untracked artifacts by deleting them.** `_capture_*`, `_mock_*`, `_diag_*`, `_moment_prev/`, `tools/_scratch_*` are correctly gitignored and are the developer's working record. Relocate them under a gitignored `scratch/` if the root listing bothers you.
9. **Do not rewrite history to make the repository look cleaner.** 876 commits by one author with substantive prose messages is an *asset*. A rewrite orphans every remaining worktree — this has already happened twice here — and the pre-rewrite lineage of `audio-per-material` and `presentation-glyphs` survives only as unreachable objects, one `git gc` from gone.
10. **Do not run the harness while another agent is working.** It takes a machine-wide lock for up to 900 s, its three `add_excl` layers measure the box, and a sweep over a tree that changes underneath it is a **void**, not a result. Check for a second `run_harness.sh` before believing any timing number.
11. **Do not "fix" a red timing layer without re-running it alone first.** `check_frametime`, `check_dig_hitch`, `check_grapple_reads`, `check_agility`, `check_stride`, `check_grapple`, `check_pump`, `check_traverse`, `check_plunge` and `play-tests` all go red from contention alone. An agent that fixes a spurious red destroys good work.
12. **Do not treat "the harness is green" as "the game is good".** The suite's own README section says so: *"The suite does not measure whether the game is enjoyable."* The blind-vision tier exists precisely because the gauges cannot see legibility.
13. **Do not cosmetically refactor before N1–N3.** The public tip is red. Nothing else is the highest-leverage change until that is not true.

---

## A+ acceptance checklist

For a reviewer re-auditing in six months. Every line is a command or a direct observation.

### Repository state
- [ ] `git rev-list --count origin/main..HEAD` = **0**
- [ ] `gh run list --limit 10 --branch main` shows **10 consecutive successes**
- [ ] `git ls-files | grep -v / | wc -l` **≤ 12**
- [ ] `git worktree list | wc -l` **≤ 6**
- [ ] `git branch --merged main | grep -v '^\*' | wc -l` = **0**
- [ ] Every remaining branch has a disposition line in a **tracked** `docs/WORKTREES.md`
- [ ] `du -sh .claude` **< 2 GB**
- [ ] For every tracked `*.png.import`, the image is tracked too
- [ ] No tracked file matches a `.gitignore` pattern
- [ ] `git grep -l "/Users/"` over tracked files returns **empty**

### Architecture and code
- [ ] `grep -rn "get_tree()" src/` = 0 and `grep -rn "res://scenes" src/` = 0, **asserted by a registered layer**
- [ ] No file in `scenes/` or `src/` exceeds **1,800 lines**
- [ ] `grep -rc "const CELL" scenes/ src/` sums to **1**
- [ ] Comment fraction of non-blank tracked GDScript **< 30%**
- [ ] First `func` before line 150 in every file over 1,000 lines
- [ ] Adding one machine touches exactly 2 files, enforced by a layer
- [ ] `project.godot` still has `untyped_declaration=2`

### Tests and harness
- [ ] Three consecutive full sweeps at one commit on an idle box: exit 0, `skip` = 0, `partial` = 0, under `SF_STRICT=1`
- [ ] **Zero** registered layers `extends SceneTree`
- [ ] Every layer prints a non-vacuity count
- [ ] `check_pack_door` registered, green, red on an unguarded-write mutant
- [ ] `check_doc_links` registered and green
- [ ] `check_repo_hygiene` registered and green
- [ ] Every worldgen *feel* floor asserted on the worst of **≥8 seeds**, worst seed printed
- [ ] `play_tests` prints privileged-input count per goal; **≥8 of 16 at zero**; median-of-3 reported beside best-of-3
- [ ] A tracked `docs/DISQUALIFIED_CUES.md` lists every cue excluded by a null control and what it was the only instrument for

### CI, security, release
- [ ] `grep -c sha256sum .github/workflows/harness.yml` = **2**
- [ ] No `@vN` action reference remains (all SHA-pinned)
- [ ] `.github/dependabot.yml` present
- [ ] A perf job exists that produces a signal on shared hardware
- [ ] `SECURITY.md` present with a stated threat model
- [ ] `.github/ISSUE_TEMPLATE/` and a PR template present
- [ ] `gh release list` shows a release; a downloaded artifact launches on Linux **and** macOS
- [ ] `project.godot` carries `config/version`, matching the top `CHANGELOG.md` entry and the tag

### Documentation and onboarding
- [ ] 100% of `docs/…` references in tracked files resolve
- [ ] Every tracked doc carries a `Status:` line in its first five lines
- [ ] `wc -l docs/PRIORITY.md` **< 200**, with an append-only archive beside it
- [ ] A tracked `docs/PROCESS.md` answers *"why is the harness bigger than the game?"*
- [ ] Timed dry run on a clean machine: clone → run → run one layer → understand a failure, **< 20 min**, using only tracked files
- [ ] README carries a green badge and a visual above the fold

---

## Appendix

### A · Command log (read-only unless noted)

```
git rev-parse HEAD / --abbrev-ref HEAD / status --short / worktree list / remote -v
git ls-files [various globs] | wc -l ; git ls-files -z … | xargs -0 du -ch
git ls-remote origin refs/heads/main            # network read, no ref mutation
git rev-list --count origin/main..HEAD ; git rev-list --left-right --count origin/main...HEAD
git rev-list --count HEAD ; git log --oneline --decorate -40 ; git log --format='%an <%ae>' | sort | uniq -c
git tag ; git branch --list / -r / --merged main / --no-merged main
git merge-base <branch> main                    # per branch, orphan detection
git for-each-ref --format='%(refname:short)' refs/heads/
git diff --stat aa52ace..HEAD ; git diff --numstat aa52ace..HEAD | sort -k1 -rn
git show aa52ace:tools/run_harness.sh | grep -cE '^add(_gl|_excl)? '
git check-ignore -v --no-index <paths> ; git status --ignored --short
git config --get core.hooksPath
git grep -n / -l / -ohE  [patterns for citations, secrets, personal paths]
gh run list --limit 8 ; gh run view 32321357033 --log-failed
/opt/homebrew/bin/godot --version                # version query only; no project loaded
bash tools/director_bus.sh status                # read-only subcommand
bash tools/capture_manifest.sh --check           # read-only verification mode; PASSED
find / wc -l / grep / sed / awk over src scenes tools tests docs .github .githooks
```

**Not run, deliberately:** `tools/run_harness.sh` (any mode), any `godot --script`, any
`tools/with_machine.sh` invocation, `git fetch`, `git push`, `git worktree remove`, `git branch -d`,
any write to a tracked file. **Reason:** §2 — concurrent agent edits plus the machine-wide lock. Save
safety itself was verified as a mechanism and would not have been the blocker.

### B · Files inspected (read in full or in substantial part)

`README.md` · `CONTRIBUTING.md` (headings) · `LICENSE` · `project.godot` · `.editorconfig` ·
`.gitignore` · `.github/workflows/harness.yml` · `.githooks/pre-commit` · `.githooks/commit-msg` ·
`docs/ORCHESTRATOR.md` (full, 738 lines) · `docs/handoff/NEW_SESSION_PROMPT.md` (full) ·
`docs/ARCHITECTURE.md` (structure + numeric claims) · `docs/PRIORITY.md` (head + heading census +
supersession-marker census) · `docs/HARNESS_LAYERS.md` · `docs/CAPTURE_MANIFEST.md` (head) ·
`src/core/save_game.gd` (full) · `src/core/factory_sim.gd` (constants, verb API, pack subsystem,
`surface_row`, `take_lode`, `collect_ground`, `remove_sapling`, `craft_item`, `take_into_pack`) ·
`src/data/mining_rules.gd` (tool tables) · `tests/test_base.gd` · `tools/run_harness.sh` (full,
1,013 lines) · `tools/save_sentinel.gd` · `tools/check_base.gd` · `tools/check_carry_cap.gd` ·
`tools/check_ci_coverage.gd` · `tools/check_frametime.gd` (gates) · `tools/check_pack_layout.gd`
(the repaired assertion) · `tools/check_seam.gd` (the repaired tautology) ·
`tools/check_loop_health.gd` (the withheld scalar) · `tools/check_plunge.gd` (the repaired vacuity) ·
`tools/check_fall.gd` · `tools/check_stepup.gd` · `tools/check_walk.gd` · `tools/director_bus.sh` ·
`scenes/light_layer.gd` (full) · `scenes/world_renderer.gd` (`_process`, `_paint_lights`,
`_paint_godrays`, redraw sites) · `scenes/hud.gd` (prologue, function census) ·
`tests/test_worldgen.gd` (the clamp assertions).

### C · Harness inventory

| | |
|---|---|
| Registered layers | **100** (`add` 83 · `add_gl` 14 · `add_excl` 3) |
| Distinct scripts | 101 (100 `.gd` + `tools/check_trailers.sh`) |
| Layers using `check_base.gd` | 84 of 97 `check_*.gd` |
| Registered layers bypassing it (`extends SceneTree`) | 13 |
| Registered layers with zero `_check(` | 13 (the same set + `check_frametime`, `check_opening`, `check_underground`) |
| Test suites | 4 (`sim`, `stress`, `worldgen`, `power_water`) · **64 `_test_*` functions** (88 functions in total, the rest being fixtures and helpers) · 651 `_check` calls. The README's "64 test functions" is the correct figure; an earlier draft of this table said 88, which counted helpers as tests. |
| Tracked `tools/` | 112 files, 33,773 lines · 10 shell scripts |
| Gitignored scratch in `tools/` | 35–36 `_scratch_*.gd` (knockout/mutant controls — a real and unusual practice, currently invisible to any reviewer) |
| Highest-assertion layers | `check_hud_layout` 70 · `check_save_durability` 69 · `check_lode` 53 · `check_pack_layout` 47 · `check_binding_persistence` 41 · `check_head` 40 · `check_carry_cap` 39 |

### D · Stale references and contradictions found

| Where | Claim | Reality |
|---|---|---|
| `docs/ORCHESTRATOR.md` §4 | "~19,000 lines of GDScript" | 64,907 tracked lines |
| `docs/ORCHESTRATOR.md` §4 | `tests/ 5` and "history/ GITIGNORED archive of ~124" | 5 files (correct); `history/` is **tracked**, 166 files / 228 MB |
| `docs/ORCHESTRATOR.md` §12 | "THIRTEEN AGENT WORKTREES" | 42 worktrees, 50 branches |
| `docs/handoff/NEW_SESSION_PROMPT.md` | "58-layer harness… Main is green: 58/58 locally and CI is passing… last commit `10641ac`" | 100 layers; CI red on the published tip; pin is `e9f23e2` |
| `.gitignore` (moments block) | "51 `_moment_*.png` on disk and 48 of them are tracked" | 55 on disk, 52 tracked. The *delta* of 3 is still right; the absolutes drifted — the exact failure mode the same file warns about two paragraphs above |
| `docs/PRIORITY.md:1064` | cites `docs/REPOSITORY_MAP.md` | Does not exist (conditional plan, reads as a broken link) |
| `docs/DIRECTOR_BUS.md:35,44`, `docs/PRIORITY.md:409` | absolute `/Users/thondascully/...` paths | Machine-specific, in tracked public docs |
| 14 tracked files (39 instances) | cite `docs/ORCHESTRATOR.md`, `docs/PEER_SESSIONS.md`, `docs/DIRECTOR_BRIEF.md`, `docs/AGENT_PLAY_EVALUATION_PROTOCOL.md`, `docs/handoff/*`, `docs/tracelog/*`, `AUDIT_REPONSE.md` | All gitignored — dead on GitHub |
| `src/core/factory_sim.gd:1695` | "THE ONE DOOR INTO THE PACK" | Four doors: `take_into_pack`, `take_lode`, `remove_sapling`, `collect_ground` (+ `craft_item` exempt). All correct today; the sentence is not |
| `AUDIT_REPONSE.md` | filename | misspells "RESPONSE" |
| `docs/ORCHESTRATOR.md` §13 item 11 | "`SaveGame.VERSION` has never been bumped" | It is at **2**, with a real migration chain — the backlog is stale in the project's favour |

### E · Unresolved questions

1. Do `check_grapple_reads`, `check_hud_layout` and `check_snap_frame` still fail at `e9f23e2`? 135 commits have landed, several directly on those files. **Unknown — requires a display run.**
2. Is the full harness green at the pin? **Unknown — not run.**
3. Does `check_trailers.sh` SKIP (with a reason) or FAIL inside the `headless` CI job, whose checkout is depth 1? It refuses to report on a shallow clone; the `authorship` job supplies `fetch-depth: 0`, the `headless` job does not, and the layer is registered in the sweep both jobs run. **Unknown — needs one line of the headless job's log.**
4. Is the `world_seed → 0` fallback reachable by any envelope that exists on disk anywhere? **Unknown** — depends on whether a real v1 save predates the `world_seed` key.
5. What is the actual per-frame cost of `_paint_godrays`? **Unknown — never profiled.** The call count is certain; the milliseconds are not.
6. Bus directive `0056` (*"reconcile lane identity and history rewrite"*, priority P0, `all`, `c1=ACCEPT`) is the only OPEN entry of 56. Whether it is live or forgotten is **Unknown** to a read-only auditor.
7. Do the two orphaned branches (`audio-per-material`, `presentation-glyphs`, 402 and 399 commits) contain work worth re-deriving? **Unknown — a director judgement, not an audit finding.**

### F · Evidence index — file:line for every load-bearing claim

| Claim | Evidence |
|---|---|
| Sim/representation seam enforced | `grep -rn "get_tree()" src/` = 0 · `grep -rn "res://scenes" src/` = 0 · all 18 `src/` `extends` lines |
| Only engine call in `src/` | `src/core/save_game.gd:273,275,277` |
| Transactional restore | `src/core/save_game.gd:_stage` → `_commit` → `restore` |
| Readback-verified atomic write | `src/core/save_game.gd` `write()`, the `_valid_envelope(_read_file(tmp))` gate |
| Backup may not be a damaged primary | `src/core/save_game.gd`, the `if _valid_envelope(_read_file(path))` branch |
| Fixture write refusal | `src/core/save_game.gd:_fixture_may_not_write` (267–277) |
| No object deserialization | `src/core/save_game.gd:_read_file` — bare `f.get_var()`, `allow_objects` default false |
| HOME isolation during a sweep | `tools/run_harness.sh:148-166` |
| Sentinel never opens the real slot for write | `tools/save_sentinel.gd:_production_digest()` |
| Three-state protocol + partial stand-down | `tools/run_harness.sh:29-61`, `tools/check_base.gd:_skip_layer` / `_stand_down` |
| Runner self-checksum | `tools/run_harness.sh:112-122`, `harness_cleanup` |
| Machine-wide lock | `tools/run_harness.sh:635-651` (`LOCK`), `787-819` |
| `add_excl` contention measurement | `tools/run_harness.sh:208-222` (IDLE p95 15.59 → 20.70 ms) |
| CI join-defect closed | `tools/check_ci_coverage.gd:1-40`; `.github/workflows/harness.yml` `SF_GL_ONLY` / `SF_NOT` |
| `check_frametime` CI exclusion, measured | `.github/workflows/harness.yml` header + the structured `CI-EXCLUDED` marker |
| No engine checksum | `.github/workflows/harness.yml:89,160`; `grep -c sha256` = 0 |
| `surface_row` is O(rows) | `src/core/factory_sim.gd:541-546` |
| Godrays call it 3×/column | `scenes/world_renderer.gd:4459-4465` |
| Light layer redraws every frame | `scenes/world_renderer.gd:575-578`; `scenes/light_layer.gd:_draw` |
| No `surface_row` cache | `grep -rn "_surface_cache\|surface_cache"` → empty |
| Cap enforced at 4 sites | `factory_sim.gd` 1437 (`take_lode`), 1167 (`remove_sapling`), 2905 (`collect_ground`), 1709 (`take_into_pack`); exemption at 1583 (`craft_item`) |
| Cap tested at the verb | `tools/check_carry_cap.gd:1-33`, 39 `_check` calls |
| Vacuity repairs | `check_pack_layout.gd` (the pre-clamp demand), `check_seam.gd:77-79`, `check_plunge.gd:120`, `check_loop_health.gd:127-140`, `check_mining.gd` |
| `_check(true)` sites all paired | `check_fall.gd:92` ↔ `:106`; `check_stepup.gd:93` ↔ `:96`; `check_walk.gd:178` ↔ `:180` |
| 13 layers bypass `check_base` | listed in P2-6; runner's `fail_lines()` comment at `run_harness.sh:713-723` documents the cost |
| Manifest is accurate | `bash tools/capture_manifest.sh --check` → `PASS`; 52 rows = 52 tracked captures |
| No registered layer reads a capture | scan of all 101 registered scripts for `Image.load`/`load_from_file` against `_moment_` → 0 |
| 39 dead citations | `git grep -ohE '(docs/(ORCHESTRATOR\|PEER_SESSIONS\|DIRECTOR_BRIEF\|AGENT_PLAY_EVALUATION_PROTOCOL)\.md\|docs/handoff/…\|docs/tracelog/…\|AUDIT_REPONSE\.md)' -- '*.md' '*.gd' '*.sh' '*.yml' \| wc -l` |
| Orphan sidecars | `_moment_water{,_body,_rock}.png.import` tracked; images untracked per `.gitignore:103-106` |
| Two orphaned branches | `git merge-base audio-per-material main` and `… presentation-glyphs main` both fail |
| Hooks installed | `git config --get core.hooksPath` → `/Users/thondascully/Projects/sinkforge/.githooks` |
| Single author, 876 commits | `git log --format='%an <%ae>' \| sort \| uniq -c` |
| Comment density 35.8% | per-file `grep -cE '^[[:space:]]*#'` vs non-blank, summed over `git ls-files '*.gd'` |

### G · Confidence rating per major finding

| Finding | Confidence | Basis |
|---|---|---|
| Published tip 135 commits stale, CI red | **Certain** | `git ls-remote` + `gh run list` |
| Three pixel layers failed at `aa52ace` | **Certain** at that commit; **Unknown** at the pin | CI log |
| 71 MB of root captures, no layer reads them | **Certain** | `git ls-files` + full scan of 101 registered scripts |
| `tools/` (33,773) > game (26,670) | **Certain** | `git ls-files … \| xargs wc -l` |
| 42 worktrees / 8.5 GB / 2 orphans | **Certain** | `git worktree list`, `du`, `git merge-base` |
| Sim/representation seam holds | **Certain** | four independent greps |
| Save/data safety is A-grade | **High** — code read in full; **not empirically exercised** | `save_game.gd` + 3 guarding layers read |
| `_paint_godrays` call count | **Certain**; its **millisecond cost is Unknown** | call chain read end to end; never profiled |
| Cap invariant holds today | **High** | all four sites traced by hand |
| A fifth uncapped path would escape | **Inferred** | the enumeration in `check_carry_cap` is manual, and this class has re-opened twice |
| 39 dead citations | **Certain** | git grep against `git ls-files` |
| No secrets / no shell-out / no object deser. | **High** | pattern scans across tracked source; absence of evidence over a targeted grep, not a proof |
| No P0 data-loss path exists | **Medium-High** | I traced the save write/read/restore paths and the harness isolation. I did **not** run a corruption fuzz, and I did not read all 97 `check_*` layers — a fixture that assembles a path at runtime would be invisible to both `check_save_isolation` and to me |
| Comment density 35.8% | **Certain** | line counts |
| Grades in the scorecard | **Judgement** | reasoned from the evidence above; another reviewer could defensibly move any single category by ±5 |

---

*This audit modified no source, no test, no threshold, no branch, no worktree and no history. It
created exactly one file: this one. Every number in it is pinned to `e9f23e2` and should be
re-derived, never quoted, once the tree has moved.*
