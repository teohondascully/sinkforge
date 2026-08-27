# Audit update — the safety strike

**Written:** 2026-08-17, immediately after `docs/handoff/COMPREHENSIVE_AUDIT.md`.
**Baseline audited:** `1d18edf`. **This strike:** `a6a681f`, `6a0dc8d`. **A concurrent session then added
`edc350a` and has uncommitted work in the main checkout — see §5 before you touch it.**

Read `docs/handoff/COMPREHENSIVE_AUDIT.md` first — it is still the governing analysis. This document
records only what has **changed** since it was written. Everything the audit says that is not contradicted
here still stands.

---

## HOW TO USE THIS FILE — for the auditing session

**This is a live channel, not a report.** A separate session audits this work continuously, so every
strike appends an entry to the **strike log** below saying three things:

1. **What changed** — commits, files, and the reasoning, in enough detail to audit without reading the
   whole diff.
2. **What I want audited** — the specific claims I am least able to check myself, phrased as questions.
3. **Where I think I am weakest** — my own honest read on what is most likely wrong. If I already know a
   thing is shaky, saying so is cheaper for both of us than having it found.

**Auditor: please push back on §2 and §3 specifically.** Contextual feedback, counter-evidence, and
"you asserted X but the code says Y" are all more useful than a general review. If an entry claims a guard
was proven non-vacuous, the highest-value check is to **re-break the code yourself and confirm it goes
red** — this project's whole safety model rests on that, and it is exactly the thing an author is worst
placed to verify about their own work.

Newest strike first. Sections 1–4 below the log are the standing record of the save-safety work.

---

## THE PRIORITY LIST — the running order

**This is the checkpoint.** It is written down here rather than living in one session's context so that a
resumed, restarted, or entirely fresh session can pick up mid-flight without being re-briefed. Work it in
order; strike entries below record what each one actually did.

**Done**

| # | Item | By |
|---|---|---|
| ✅ | Save-path isolation + production-slot sentinel | `a6a681f`, `6a0dc8d` |
| ✅ | Atomic save, backup, recovery, transactional restore, v2 migration, seed ownership, phase semantics | `edc350a` (peer) — **adversarially verified**, Strike 3 |
| ✅ | Capture-envelope frontier guard | `2df393e` (peer) |
| ✅ | `docs/DECISIONS.md` — the log seven citations pointed at | `5c31328` |
| ✅ | The presence gate no test could see | Strike 3 |
| ✅ | `docs/ARCHITECTURE.md` + README truth pass (was queue item 4) | Strike 4 |
| ✅ | Full harness green as a suite: 61/61, 156s, sentinel verified (item 0) | Strike 5 |
| ✅ | Captures fail closed + input suppressed + manifest (item 2) | `77ba4b4` |
| ✅ | **The auditor’s two save P0s** — `copy_absolute` Error discarded, and its mirror: the backup generation spent by the save after a recovery | `a42cf76`, Strike 10 — mutation-proved, 66/66 windowed + 61/66 headless |
| ✅ | The sentinel's abort path (`disarm`) + per-run marker identity | `f7b78a5`, Strike 10 |
| ✅ | `check_save_isolation`: recursive, splice-aware, registration verbs derived not spelled | `d933159`, Strike 10 — closes a hole **I** opened by adding `add_excl` |
| ✅ | **Item 3 — the multi-seed corpus SWEEP is run**, distribution recorded: 5 layers × 8 seeds, 40/40 green | `c607bae`, `3d47aca`, Strike 11 — the one red cell was the fixture, not the generator |
| ✅ | **Item 5 — `tools/check_base.gd`** + `docs/HARNESS_LAYERS.md`: one `_check` across 54 layers, 2157 assertions verified identical per layer | `1aea9af`, `f31baa2`, Strike 12 |
| ✅ | **The 120fps headline corrected**: missed-deadline rate replaces an unanswerable p95 comparison | `4097043`, Strike 12 — *the game holds its frame rate except when it edits terrain* |

**In flight** — the six invalid assertions: two sessions repaired them independently and neither is a
superset, so an agent is producing the union. Version A is on main (`5a2797a`); version B is in worktree
`agent-aabacbb2493625a01` at `a84c049`, is 2.3× larger, additionally covers `check_wrap.gd`, and found five
defects A did not. **Do not simply pick one.** §6 lists what is unique to each.

**Queued, in order**

0. **RUN THE FULL HARNESS FIRST.** `GODOT=/opt/homebrew/bin/godot bash tools/run_harness.sh` — unpiped, or
   the exit code is `tail`'s and a red layer hides. Main has taken seven commits from two different
   sessions since the last full green run; every layer touched has been verified individually, but the
   suite as a whole has not been run since. Then `SF_HEADLESS=1` to reproduce CI. **Do this before writing
   any new code.** It is now safe to run — that was the whole point of Strike 1.

1. ~~**CI truth.**~~ **DONE — Strikes 6 and 14.** Three-state accounting, `SF_STRICT`, durable artifacts,
   an honest `check_frametime` name and a real display job all landed earlier; Strike 14 closed the last
   piece by making the display job select layers by REGISTRATION rather than by a hand-kept name list,
   which had left two `add_gl` layers running in no job at all. Original text below — its second paragraph
   is the finding this whole file is organised around and should not be lost.
   Four `add_gl` layers (`check_opening`, `check_underground`, `check_water_reads`,
   `check_frametime`) self-skip with no display and **exit 0, so skip counts as PASS**. The suite reports
   all-green while four layers did nothing. Add three-state PASS/FAIL/**SKIP** accounting, a fail-closed
   mode, durable artifacts for failing layers, and a real display job if achievable. Also: `check_frametime`
   is named "120fps" and **never asserts 8.33 ms** — it compares busy p95 to quiet median. Keep the portable
   ratio; make the name honest, or add an absolute budget only on named hardware.
   **STRIKE 6 WIDENED THIS AND IT IS WORSE THAN WRITTEN.** A green suite was *proven* to contain a genuinely
   failing layer at the commit Strike 5 called 61/61 — but not via the skip path. `check_dig_hitch` ran,
   asserted, and returned 0 because its assertion **could not fail** headless (blank texture vs blank
   texture). Three-state accounting does not catch that: it is bookkeeping *around* a process, and this is a
   process that never checked. **A suite cannot infer "verified" from "returned zero."** See Strike 6.
2. ~~**Capture validity.**~~ **DONE — Strike 5** (`77ba4b4`). Canonical frames retaken clean.
3. ~~**Multi-seed worldgen corpus.**~~ **DONE — Strike 11** (`c607bae`, `3d47aca`). Swept 5 layers × 8 seeds:
   **40/40 green, the generator is NOT seed-fragile.** The single red cell was `PlayAgent.dig_down_to`
   silently no-opping on a world with a void under spawn, so `check_underground` was judging a sunlit
   surface frame against an underground standard. Three defects in the corpus tool itself fixed too.
   Original statement kept below. **TOOLING LANDED (`d1bbfa9`), SWEEP NOW RUN.** `MainView.default_seed()` routes the boot seed through `SF_SEED` when nothing has picked one
   (`boot_seed` still wins, so a save or the title screen can never be overridden by an env var), and
   `tools/seed_corpus.sh` runs the six seed-sensitive layers across a committed 8-seed corpus. It drives
   the **real layers with their real floors** rather than re-implementing any measurement, so the corpus
   cannot drift from what the harness asserts. Deliberately NOT registered in `run_harness.sh` — it is
   layers × seeds and takes minutes. **Next action: run it and record the distribution.** Blocked only on
   exclusive machine access (see item 18). Original statement of the problem follows.
   Every feel floor runs on seed **1337 alone** — every screenshot,
   play-test, capture and richness measurement in this project's history is one seed. A tweak that leaves
   1337 pleasant and 4242 barren passes everything. Build a fixed committed corpus, report the full
   per-seed distribution, and **do not lower a floor to make it green** — a seed-fragile generator is the
   finding, not a thing to tune away. Keep the shipping-seed gate stricter and separate.
4. ~~**`docs/ARCHITECTURE.md` + README truth pass.**~~ **DONE — Strike 4.** One piece deliberately left:
   **README still ships zero images.** Do it after queue item 2 retakes the canonical captures, since the
   current ones are known-contaminated.
5. ~~**`tools/check_base.gd`.**~~ **DONE — Strike 12** (`1aea9af`, `f31baa2`). It was 50 layers in six
   cosmetic variants, not 41 byte-identical. 54 now share one base; `docs/HARNESS_LAYERS.md` is the doc.
   Nine layers using different counting idioms are deliberately left alone.
6. **Rock legibility — TWO problems, not one.** Confirmed by my own eyes on a clean delve capture
   (Strike 5), and they need different fixes, so do not treat them as one ticket.
   - **6a — outside the lamp, rock and void are the same near-black.** The blind tester: *"I cannot
     reliably tell solid rock from empty air, and I want to say that loudly."* **Do not fix by raising
     global brightness** — an earlier blue fog did that and had to be removed. Shape the darkness: an
     ambient floor that keeps unlit *rock* grainy while unlit *air* stays black.
   - **6b — inside the lit pool, the rock has no edges.** It reads as a soft mottled gradient — fog, not
     carved mass. There is no contact line anywhere where rock meets air. **This is why brightness cannot
     fix 6a**: more light on an edgeless gradient is a brighter edgeless gradient. Worktree
     `agent-ae87e73614c6b440e` (`fa9cca3`) already attacks exactly this with a **directional contact
     edge**, and its own notes say the fine AO had made the last row of rock the darkest thing on screen,
     sitting against dark air — so rock and void met at their two most similar values. Its margin on
     `check_texture` is thin (0.20pp) and `check_frametime`/`check_dig_hitch` were never measured.
     **Strike 6 measured them: all green, margin holds.** But the A/B capture verdict is that it is
     **incremental, not the fix** — bedding and value patches improve, the shaft/rock boundary stays soft.
     Land it as foundation; do not close 6b on it, and it does nothing for 6a.
7. **Machines should look like installed hardware, not UI.** *"SPUR / DRILL / GENERATOR are flat pale
   rectangles with a nameplate — they read as tooltips someone left on."* **DRIFT RIG is the exception and
   is much better** — chassis, bolts, a visible mechanism. Bring the others up to it.
8. **The hotbar has two identical grey icons.** *"Completely indistinguishable… instantly says placeholder."*
9. **The clipped green/red stubs at the top-left corner.** Proven to be **world-layer geometry drawn under
   the HUD** and clipped by the screen edge, not `hud.gd`. Owner: `world_renderer.gd` / `main.gd` /
   `visuals.gd`.
10. **The Bazaar as a physical object.** Headline finding: **the ruin has no art at all** — `Bazaars.draw()`
    iterates only *completed* frames, so the first Bazaar every player sees is four wood cells wearing the
    dirt palette with grass growing on it. The awning is at 1.04:1 contrast against the sky (optically
    invisible as shape) and the keeper is *"a lavender bowling pin."*
11. **The lode cutover, phase 3.** *(PARTLY SUPERSEDED 2026-08-17 — phase 3a shipped; the live status is
    `docs/PRIORITY.md`. The do-not-merge instruction below still stands: that branch was never merged.)*
    The main line of design work. Its gates are **red** — completion, pacing, and deep-pocket play all fail
    — and it prints 98.6/100 anyway. **Do not merge on that number.**
    ~~The Borer and Drift Rig expose lode but their pay chute draws nothing on a generated world; that is
    the largest known gameplay gap.~~ *Corrected: that symptom's upstream cause was that generated worlds
    held no lode, which 3a removed. The chute is UNTESTED, not exonerated.*
12. **Decompose the three god files** along seams that already exist: a lighting painter and a water painter
    out of `world_renderer.gd`; a `digging.gd` out of `main.gd`; per-behaviour modules out of
    `factory_sim.gd` (`_BEHAVIORS` was designed for exactly this).
13. **`FineTerrain` names two unrelated classes** (the renderer's baker and the sim's molding module).
14. **Audio follow-ups:** occlusion (not just enclosure); the strike ringing the room via the existing
    `hollow` reading, so a blow tells you the *size* of what you are about to open; per-machine voices in
    the hum; a `check_space` layer, because the enclosure mapping is asserted only by a bench tool today.
15. ~~**Triage the eight legacy worktrees.**~~ **TRIAGED — Strike 15.** There are **thirteen**, not eight;
    the count in `docs/ORCHESTRATOR.md` §12 was hand-kept and had gone stale, which is the same join defect
    the CI-coverage layer was written for, one level up. Full decision table with evidence in Strike 15
    below. Summary: **2 already fully upstream** (`git cherry` says so), **2 self-declared superseded**,
    **1 forbidden by the user** (the lode cutover — do not merge), **1 merged** (the six-assertion union),
    **7 unverified WIP** that are 78–83 commits behind and should be **re-derived, not merged**.
    **Nothing was deleted.**
16. **The lore first slice** — `docs/DECISIONS.md` "The Works Are Cold". **User decision, vision-level fork.**
17. ~~**Every load and every boot freezes for ~1.7 s.**~~ **DONE — Strike 13.** The bake is now progressive:
    the visible rect is painted before the first frame and the rest is filled off-camera at 4 ms a frame.
    Original text kept below because its warning about *how not to fix it* is the reason this shape was
    chosen. Measured in Strike 6, not estimated: a full fine bake
    is 262144 cells at ~6.5 µs/cell. `repaint_world()` sets `_fine_dirty = true` and runs on **F9 load**
    (`main.gd:2089`) and on initial paint, and the renderer's call site passes callables identical in shape
    to the ones I timed, so this is the in-game number. This is the *sibling* of the mining hitch that
    dirty-chunks fixed — the same full-grid bake, on a different trigger, never given the same treatment.
    Likely shapes: bake in slices across frames behind the existing loading state, or persist/derive the
    fine grid incrementally on load rather than re-molding all of it. **Do not "fix" it by making the bake
    cheaper per cell without measuring** — item 6b's tile work pushes that number the wrong way, and the
    per-cell ratio gate in `check_dig_hitch` is blind to exactly that (see Strike 6, blind spot 4).

18. **The harness is not concurrency-safe and a worktree does not save you.** Two runs on one machine share
    `user://` (Godot keys it on project NAME, not directory), so they corrupt each other's sentinel state
    and each other's test fixtures. Discovered in Strike 6 by tripping the save sentinel with a false
    alarm. A lockfile that refuses or queues a second concurrent run closes it. Sent to the CI-truth agent
    as in-scope for item 1.

> ## ⚠️ THE ORDERING ABOVE IS SUPERSEDED — see `docs/PRIORITY.md`
>
> Every item 1–18 above survives, and none was dropped; what changed is which of them is next. The
> subjective audit of 2026-08-17 (`docs/handoff/VIBE_AUDIT_RESPONSE.md`) scored the artifact **4.9/10**
> and found the ratio wrong: **71.3% of changed paths in the last 93 commits were under `tools/`**, and
> the project now has instrumentation abundance and human-evidence scarcity. Its kill list forbids any new
> harness layer not attached to a human-observed failure or a chosen visible change, which makes most of
> this queue **demand-pull rather than next**.
>
> `docs/PRIORITY.md` is the union of this queue, `AUDIT_REPONSE.md`'s eight-item order, `FEEL_GAP.md`'s
> Tracks A/B and the vibe audit's kill list and week plan. Use it for ordering; keep using this file for
> the evidence and the strike log.

**Standing rules that outrank the list:** never lower a floor to buy green; prove every new guard by
breaking the code and watching it go red; never `rm` anything the user made; commits carry no
Claude/Anthropic trailer; **never start a harness run while another session or agent is running one** —
check first, the result is meaningless otherwise.

---

## STRIKE LOG

> **ONE SERIES FROM HERE, and the reason is that the two-series habit produced a false report to the user.**
> Asked "what tier did you reach", I answered "Strike 15" from the headings below. The game's strike counter
> was at **41** and had not moved since 22:17 the previous night; the entries below are an audit sub-series
> that restarted at 1 while the real counter stood still. Both numbers were honestly recorded and the pair
> was misleading anyway — 95 commits of infrastructure looked like fifteen strikes of progress. The audit
> series is retired at 15. Numbering continues from the game series, so this entry is **42**, and there is
> exactly one counter to answer that question with.

### STRIKE 42 — 2026-08-17 — the harness stops living in the player's save directory

**Closes the auditor's #1 and #5** (`AUDIT_REPONSE.md:757,767`), which are the same defect seen from two
sides: "freeze evidence" needs a namespace nobody else writes, and "harden harness isolation" needs the
same namespace. It is also the root of the concurrency hazard that cost an afternoon, and — the part that
made it urgent rather than tidy — it is upstream of every measurement either session takes.

**The mechanism was measured, not chosen.** Three candidates, two of which do not work:

| candidate | result |
|---|---|
| `XDG_DATA_HOME` / `XDG_CONFIG_HOME` | **read by Godot and ignored on macOS** — `user://` stayed at `Library/Application Support` with both set. Honoured on Linux, which is why both are now set anyway. |
| a command-line flag | **does not exist**; `--help` has nothing for the user directory |
| `use_custom_user_dir` in `project.godot` | works, and **moves the shipped game's save too** — the one thing that must not change |
| **`HOME`** | **works**, per process, no file on disk for two sessions to contend over |

`override.cfg` would have been the fifth option and is worse than `HOME` for the same reason the lock is
not a fix: it is one shared file in one shared tree. It is also already spoken for by the TLS workaround.

The home is keyed on a **hash of the repo root**, not a run id. Same checkout keeps its fixtures and a warm
cache; a second worktree gets its own namespace and stops colliding. `SF_REAL_HOME=1` opts back out.

**Cost: none.** 70 PASS / 0 FAIL / 6 SKIP in 160s against a cold isolated home, versus 70/0/6 in 159s
before. No layer was quietly reading a production fixture — which was the real risk, and the sweep is what
established it rather than an argument that none would.

**What the production directory actually held**, which is the case for the change better than any
reasoning: `test_fine_terrain.save`, `test_fine_terrain.save.bak`, `zoom.png`, and a `logs/` tree — all
written into the player's namespace by layers over time, none deliberately. Invisible until you look.

**Then the sentinel had to change, because isolation broke its claim.** Its line read "the production slot
is untouched" — after the move that was true *by construction*, and true-by-construction is not proved:
three lines of shell can be deleted by a future edit with nothing to notice. So the runner now hands the
sentinel the real path it just stopped using (`SF_PRODUCTION_SLOT`) and the sentinel hashes it before and
after **without ever opening it for write**. This answers the auditor's remaining objection exactly
(`AUDIT_REPONSE.md:593`): the sentinel no longer plants in `user://sinkforge.save`, because that is no
longer the player's file.

**Mutation-tested both directions**, since an unfalsifiable witness is the shape this whole session has
been removing: mutate the file behind its back → `verify` exits **1** with `THE PLAYER'S REAL SAVE CHANGED
DURING THIS RUN`; leave it alone → exits **0**. The positive control is what makes the negative mean
anything. Absent is recorded as a legitimate third reading — the player has no save at present, so verify
prints `absent throughout`; **absent-then-present would fail**.

**Two shapes caught in my own work while doing this**, both already in the catalogue:

- **Shape 23** (exit code discarded by a pipe). My first check printed `EXIT=0` on a run that had visibly
  just failed, because the sentinel was piped through `grep` and I read grep's status. Written into
  `PEER_SESSIONS.md` roughly forty minutes earlier, by me.
- **Shape 27** (measurement boundary). Cleaning up orphans, `ps | grep -c Godot` reported two survivors
  after `kill -9`. Both were peer *shell* processes whose argv contained the string `Godot Engine` inside a
  grep pattern. The detector was matching text about the subject instead of the subject.

**A real hazard found by tripping it:** I edited `run_harness.sh` while a sweep was running. Bash reads
scripts lazily by byte offset, so an insert near the top can shift what a running interpreter reads next.
That run was killed rather than trusted, and its result is not recorded anywhere as evidence. Killing the
runner also left four orphaned Godot children holding no lock — the trap releases the lock but does not
reap children.

### Strike 15 — 2026-08-17 — item 15: thirteen worktrees, and the six-assertion union

**Item 15 is closed as a triage.** Nothing was deleted. One branch's work was merged; the rest are
classified with the evidence that classified them.

**First: there are thirteen, not eight.** `docs/ORCHESTRATOR.md` §12 said eight and named eight. The number
was written by hand at a moment when it was true and nothing re-derived it, so five branches existed that
the document describing the branches did not know about. That is the CI-coverage defect exactly — one file
enumerating what another file contains, with nothing holding them against each other — and it is worth
noticing that I found it *while writing up* the layer built to catch that shape, in the document that layer
does not read.

**Every branch is 62–83 commits behind main and 0–2 ahead.** So `git diff main..branch` is dominated by
main's newer work appearing as deletions: the two "superseded" branches below would each remove ~12,000
lines, including `tools/with_machine.sh`, if merged naively. The diff that means anything is
`merge-base..branch` — what the branch itself *added* — and that is what every verdict here is based on.

| branch (`worktree-agent-…`) | ahead/behind | verdict | evidence |
|---|---|---|---|
| `ab86dfedf83e367cf` | +2/−62 | **already upstream** | `git cherry main` prints `-` for both commits — same patch-id already on main |
| `a8afacea093186351` | +0/−82 | **already upstream** | tip *is* the merge-base; nothing ahead |
| `a2462b929fb990025` | +1/−78 | **superseded** | commit message self-declares supersession by `edc350a`, which is on main |
| `a3208149952156f39` | +1/−79 | **superseded** | same, same commit |
| `a0d233e93485c52d9` | +1/−83 | **FORBIDDEN — do not merge** | the lode cutover. User instruction, standing: its completion and play gates are red and its 98.6 score is the one Strike 13 showed was computed from a truncated run |
| `aabacbb2493625a01` | +1/−79 | **MERGED (this strike)** | version B of the six-assertion repair; the union is below |
| `a3be74d0ccdfa42dc` | +1/−72 | **subsumed by the above** | "wip(union), mid-merge" — a checkpoint of the same work, plus two `.png.import` files |
| `ae87e73614c6b440e` | +1/−83 | **re-derive** | rock bedding/partings. Main independently shipped the *lit edge* half (`FORM_LIFT`/`FORM_SINK`, #S8); the `BED_*`/`PART_*` lamina system is genuinely absent — but the file has since been rewritten twice (progressive bake, #S30) |
| `a53ff2bb529040b7a` | +1/−83 | **re-derive** | lighting/post-FX. Commit message says "UNVERIFIED, harness never run" |
| `a65799923e0124100` | +1/−83 | **re-derive** | particles. Same self-declaration |
| `a9b0034b8b8d1fb51` | +1/−83 | **re-derive** | miner movement. Same self-declaration |
| `ad448b387cfec2f70` | +1/−83 | **re-derive** | glyphs/inspector. Same self-declaration |
| `ad52b2d111a19f681` | +1/−83 | **re-derive** | bazaar counter (STRIKE 35). Touches `hud.gd`, which is the peer session's lane and has moved a long way |

**"Re-derive, not merge" is the finding, not a dodge.** Seven branches carry ideas worth having and code
that no longer applies: each is ~80 commits behind, several self-report that the harness was never run on
them, and every one of them touches a file that has since been substantially rewritten. Merging them costs
a conflict resolution per branch and lands unverified work; reading them costs nothing and the ideas
survive. They are kept on disk for exactly that.

#### The one that was live: the six-assertion union

`aabacbb2493625a01` is version B of the repair whose version A is on main (`5a2797a`). The audit recorded
that neither was a superset. That was correct, and the union is **smaller than B's diff**, because on three
of the seven files main's version turned out to be the stronger one:

- **`check_seam`** — main reads the field back in reverse order *with a foreign seed interleaved between
  every pair*, which kills a "last seed I was given" memo. B's plain reversal does not. Main also guards
  non-vacuity harder (`grained_probes > 0 and < size`, versus B's `kinds.size() >= 2`). **Main wins.**
- **`check_loop_health`** — B *deleted* the three clamp assertions as "not properties". Main repaired them
  instead, `<=` → `<`, which fails exactly when a penalty **saturates** — a real signal about a real
  regression. **Main wins**; deleting them would have been a loss.
- **`check_saveload`** — main has an assertion B lacks (the round-trip went through the isolated slot).
  **Main wins**, nothing to take.

What B had that main lacked, all seven of which are now on main:

1. **`check_plunge` — the shaft has to arrive.** `speedup = shaft_frames / roped_frames`, and a shaft that
   stalls does not stop early: it spends its whole 6000-frame budget going nowhere and returns those frames
   as its cost. The ratio then reads ~21× in the hole's favour. **The worse mining gets, the better this
   layer says the plunge is.** The stall does print — to stderr, outside the assertion record, where a green
   run never shows it.
2. **`check_plunge` — the legs ride has to have gone down.** "On legs alone it is a ONE-WAY door" is rows
   *regained* against a cap; a body that never entered the trap regains nothing and passes with room.
3. **`check_wrap` — the whip needs a baseline.** `free_spin` starts at `0.0` and is only ever raised by a
   `maxf`, so a run with no free taut arc decays `spin > free_spin * WHIP_EDGE` into `spin > 0.0` — "the arc
   turned at all". The `events > 0` guard for this same trap was already sitting two assertions below it.
4. **`check_mining` — the aim has to land on work.** Main's invariant is `not is_solid(eff) or
   _mineable(eff)`, which **open sky satisfies outright**. An `_effective_aim` that gave up and returned
   empty air behind every wall would pass. That is the phantom-crack bug wearing its other face: the pick
   charges forever on nothing and the player sees the identical dead animation. Now `_workable(eff)` and
   then `try_mine(eff)` — the gate saying yes and the rock breaking have to be one answer.
5. **`check_loop_health` — the sampler has to have watched.** Two of three penalties are per-frame tallies
   starting at zero and only going up, so a sampler that never ticked yields **a perfect 100 for a play
   nobody observed**. It fails silently *and upward*, which a ratcheting floor structurally cannot catch.
   `_sampled_frames` was already being printed and was the only figure here nothing asserted.
6. **`check_pack_layout` — the squeeze check read the clamp against itself.** `_check(lay["total"] <= cols)`,
   where `works_columns` **ends by clamping `m + r` to `BAZAAR_COLS`**. It could not fail however far the
   lists overflowed. `hud.gd`'s own comment beside that clamp says *"check_pack_layout asserts the squeeze is
   not happening today"* — the source file documented a guarantee the test was not making. Now the demand is
   computed before the clamp sees it.
7. **`check_pack_layout` — same shape, every field, every tab.** The comparison was `origin` and `h` only,
   which is the panel's *outline*; the content rect could move underneath it, and the content rect is where
   the vanishing recipe rows lived. The row count was asked on whichever tab happened to be selected, while
   the old panel lost a different part of itself on each. Now `_shape_diff` walks every key
   `_bazaar_geometry` returns — so a field added later is covered the day it lands — and all three tabs are
   counted at the stall and demanded back down the shaft, each guarded by "this tab had rows to lose".

#### A DESIGN finding the repair surfaced — the plunge is 1.1× the pickaxe, and the file says that is scenery

**Not fixed, because it is not a test defect.** Recording it where the design decisions live.

`check_plunge`'s docstring states the property it exists to hold:

> *THE SPEEDUP — plunge frames vs shaft frames. **Under about 2× the hole is not worth walking to and the
> second route is scenery.** This has a floor.*

The floor is `SPEEDUP_FLOOR = 1.0`, and its own trailing comment reads `## ...faster than the pickaxe
(measured 1.1)`. Today's run, with the new arrival guard making the shaft genuinely complete its descent:

```
the shaft:      32 rows in 316 frames, 32 blocks broken
the plunge, with rope:  34 rows in 286 frames, 0 blocks broken, 3 hops
the hole is 1.1x faster than the pickaxe
```

So the stated design threshold is ~2×, the asserted floor is 1.0, and reality is 1.1 — **someone lowered
the floor to whatever the game happened to do and left the design claim standing above it.** That is shape
#22 in the very file being repaired: prose asserting more than the code beneath it.

**Two things follow, and only the first is mine to say.**

1. *The assertion is now genuinely load-bearing and nearly red.* Margin is 0.1. Before the arrival guard, a
   stalled shaft returned its full 6000-frame budget and handed the hole a ~21× "speedup" — enormous
   headroom that was pure artefact. The guard removed the artefact and revealed the real number sitting
   just above its floor. **This is what fixing a #21 looks like from the outside: a comfortable gauge
   becomes a tight one, and nothing about the game changed.**
2. *Whether 1.1× is acceptable is a design question for the user.* By the file's own words it makes the
   sinkhole scenery. **Do not resolve it by moving the floor** — that is the move this whole strike exists
   to argue against, and the standing rule is to fix the thing before touching the number. The honest
   options are: make the plunge meaningfully faster, or rewrite the docstring to claim what the design
   actually wants. Either is a decision; neither is a test edit.

#### The sweep the union triggered — 74 layers, 3 shared helpers, 4 real defects

> **SCOPE — this is not a non-vacuity clearance of the suite.** What ran is *two greppable forms* plus an
> enumeration of the three shared helpers. It says "these two shapes are now absent", not "these 74 layers
> assert something". `AUDIT_REPONSE.md:160` states the standard this would have to meet to be called
> closed: a **per-layer evidence table** covering fixture preconditions, independent oracle, headless
> semantics, mutation result, seed coverage, and skipped sub-assertions — six columns, of which the sweep
> below is roughly the first. Treating "we did not find another" as a completed sweep is the specific
> error that document warns against, and the heading above is one careless quotation away from committing
> it.

Finding five instances of one shape in one merge was the argument for sweeping the suite instead of
stopping. Both sessions did it, split by form. **The result is worth more than the four fixes**, because it
says something about method:

| pass | sites flagged | real |
|---|---|---|
| form one — counter seeded `0`, asserted `== 0` | 5 | 1 — `check_teaching` |
| form two — max or ratio seeded `0`, asserted `<= CAP` | 13 | 2 — `check_dig_hitch`, `check_stride` |
| shared helpers (3 exist; enumerated, not guessed) | 3 | 1 — `dead_space.gd` |

**Every prediction either session made about where the shape lived was wrong.** I picked `check_richness`
as the likeliest and it was the best-floored site in the peer's half — three separate floors above it. The
peer had praised `check_teaching` that morning for getting `released > 0.0` right, and it was the one real
instance in their half: **the same file, correct in one assertion and wrong in four others.** That is the
texture of this defect — not carelessness, but that the fixture and the threshold get thought about at
different moments.

So the mechanical tell runs at roughly an **85% false-positive rate and is still worth running**, because
clearing a site costs reading two lines up, while judgement about where to look was wrong every time. That
is the case for greppable rules over instinct, stated with numbers rather than as a preference.

**The `dead_space.gd` one is the one that matters most**, and not because of its blast radius (though one
`maxi(total, 1)` disarmed a cap in three callers at once). It matters because it was **structurally
invisible to the method that found the other three** — it is not in a layer, so no amount of reading layers
would have surfaced it. It took enumerating the helpers with a grep. The generalisation, which is the
peer's and is sharper than anything in the four fixes:

> Nobody writing `Vector2i(-1, -1)` is in any doubt that they are encoding "not found". Everybody writing
> `maxi(n, 1)` believes they are preventing a crash. The defect is not the absence of the convention — it
> is that **an arithmetic-safety guard does not look like a place where the convention applies.**

Full catalogue entries: `docs/PEER_SESSIONS.md` §12 shapes **21** (the threshold satisfied by a non-run),
**22** (a source comment citing a test as a guarantee), **23** (the exit code discarded by a pipe), **24**
(a bounded wait loop whose bound meets its assertion's cap).

**The shape, for `docs/PEER_SESSIONS.md` §12: a floor or a cap is satisfied by a run that never happened.**
Five of the seven are one defect. `speedup >= FLOOR`, `back <= CAP`, `spin > free * EDGE`, `score >= FLOOR`
— each compares against a quantity accumulated *during* the run, and each is satisfied most easily by a run
that accumulated nothing. The stalled shaft, the body that never fell, the arc that never went taut, the
sampler that never ticked. **Every threshold assertion needs a companion asserting the run occurred**, and
the tell is that the failure moves the number in the *passing* direction.

### Strike 14 — 2026-08-17 — item 1's last piece: two layers were running in no CI job at all

**Commit:** `f420d93`. **Item 1 is closed.**

Everything else in item 1 had landed — three-state PASS/FAIL/SKIP, `SF_STRICT`, durable artifacts, the
honest `check_frametime` name, and a display job on xvfb + lavapipe. The remaining piece was *"a real
display job if achievable"*, and it was achievable and had been achieved. It was also **selecting its
layers by name**:

```
SF_ONLY: check_opening|check_underground|check_water_reads|check_dig_hitch
```

That list was accurate on the day it was typed. `add_gl` then grew to six. **`check_item_reads` and
`check_hud_layout` ran in NO CI JOB.** They skip in the headless job — correctly, they need a window — and
the display job never selected them. Both jobs stayed green the entire time: the headless one honestly
reported SKIP, the display one honestly reported four passes, and **nothing anywhere held the two reports
against each other.** The peer's HUD-layout layer, which found 450px of glyphs in a 244px panel, had never
run in CI once.

This is the same defect the workflow's own header is entirely about, returned in a new place, and it is
the JOIN family (vacuity shape 18): a vocabulary declared in one file and consumed in another, with every
test reading one file or the other.

`SF_GL_ONLY=1` asks the runner which layers need a surface instead of a human remembering. `SF_NOT` states
exclusions out loud, because in a hand-kept list "left out on purpose" and "forgotten" look identical.
`tools/check_ci_coverage.gd` reads both files and asserts set equality in both directions — the reverse
one being load-bearing, since *"every layer the workflow names is real"* passes trivially on a workflow
that names none. **Six layers on the display job now instead of four.**

**The new layer fooled itself twice before it worked, both times on prose**, and that is worth more than
the fix. `flow.contains("SF_ONLY:")` matched the comment explaining why `SF_ONLY` was removed — a scanner
going red on its own explanation. Then requiring each excluded layer to be *named in a comment* PASSED its
mutation, because the paragraph describing the original defect contains the string `check_hud_layout`.
Prose about the bug satisfied the guard against the bug. Exclusions now need a structured
`# CI-EXCLUDED <layer>: <reason>` declaration with a length floor. Three mutations verified red: excluding
a layer silently, reverting to name-based selection, emptying the justification.

**Unrelated and open: CI has gone red twice this afternoon on failures that are green locally** —
`check_dig_hitch` at `e5d99f9` and `check_teaching` at `6fa993a`, both in the headless job, both on the
peer's commits and neither plausibly caused by them. `check_teaching` breaks its drop loop the frame the
landing lands and asserts the hint on the next line, which is a race a slow box loses. Handed to the peer
with the evidence rather than a diagnosis; flagged here because two CI-only failures in one afternoon on a
locally-green suite is a pattern worth one look rather than two incidents.

### FOR THE USER, NOT THE AUDITOR — 23 commits carry a trailer this repo forbids

**`docs/DECISIONS.md` §Process: "Commits carry no Claude/Anthropic/co-author trailer, ever — LOCKED".**
23 commits now on `origin/main` carry `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.
All from 2026-08-17, all mine, oldest `7a1b427`, newest `65009ea`. The author line is correct on all 415
commits in the repo (`teohondascully <121736842+teohondascully@users.noreply.github.com>`); it is only the
trailer.

**Cause, since it matters more than the count:** there is no hook and no `commit.template` — the harness
this session runs under instructs every commit message to end with that trailer, and a LOCKED project rule
was sitting against a machine default with nothing but memory in between. The peer session's identical
harness stayed clean only because the rule happened to be in its working context. Both sessions have now
written it to persistent memory and pin the identity explicitly on every commit; `9ef99b8` onward are clean.

**NOT FIXED, DELIBERATELY.** Correcting the 23 means rewriting pushed public history and force-pushing over
a branch two sessions are committing to. Both sessions independently declined to do that without you
asking. When you decide, the cheap version is a `--msg-filter` pass over `7a1b427^..main` stripping only
trailer lines, both sessions frozen on pushes, one force-push-with-lease — and **re-verify
`git log --format='%an <%ae>' | sort -u` afterwards**, because a filter that rewrites every commit is
exactly the operation that can quietly change the author line while you are watching the trailer.

### Strike 13 — 2026-08-17 — item 17 closed, and a detector I built, measured, and deleted

**Commits:** `9ef99b8`, and the progressive bake below. **Queue item 17 is closed.**

**THE BOOT BAKE NO LONGER BLOCKS THE FIRST FRAME.** 262144 fine cells at ~4.6 µs each is 1199 ms in front
of every boot and every F9 load. The profiling in `rebake`'s own comment says there is nothing to optimise
— the bulk fine-grid handover bought 11%, the eight noise calls per cell are 16%, and the remaining ~74% is
`_paint_fine` itself, a hundred interpreted operations with no peak anywhere — and names the only two
options that keep the output exact: bake the visible region first, or get the bake off the main thread.
This is the first. `rebake()` takes an optional `view: Rect2`; empty (every existing caller) paints the
whole grid exactly as before, non-empty paints the visible fine rect and owes the rest to `bake_pending`,
which the renderer pumps at 4 ms a frame after digs have had their turn.

**Measured, both bakes in the same process moments apart so the ratio is a property of the code:
91.8 ms against 1179.4 ms — 12.85× — on the test's own 5.6% view.** The real boot view is bigger:
`check_dig_hitch` reports the opening bake at **43520 cells, 17% of the grid**, clipped at the top edge
because the body spawns at the surface. Fitting the two measurements gives ~27.8 ms fixed plus 4.39 µs a
cell, so **the in-game figure is about 220 ms in front of the first frame instead of 1179 ms.** That last
number is derived, not observed, and is marked as such deliberately — the opening bake reads 6.30 µs/cell
against the full bake's 4.50 because it pays the whole coarse-cache fill and the upload over far fewer
painted cells, and any estimate that ignored that would have been optimistic by a third.

**The correctness argument is a property of the code, not a promise about the change.** `_paint_fine` reads
only caches that `rebake` fills completely before any painting starts, and writes only its own four bytes —
so paint ORDER cannot affect the result and any partition of the grid yields the same image, byte-identical
by construction. `tools/check_progressive_bake.gd` asserts it anyway, because "correct by construction" is
what all seventeen catalogued vacuous guards in this project also said. It carries a **positive control**:
an UNDRAINED bake compared against the reference, required to DIFFER. If the comparison ever stops being
able to fail, the layer says so in the same run.

**And it found a live hole in the change while I was writing it.** `setup()` runs from main's `_ready`
BEFORE the renderer is in the tree, so `get_canvas_transform` fails there — loudly, then quietly, by
returning an empty rect that `rebake` reads as "bake everything". The boot bake is the one bake this item
exists to split, so the change would have shipped defeating itself with every test still green. The
opening view now falls back to a span around the player's spawn, where the camera is by construction.

**THREE MORE DEFECTS SURFACED AFTER I THOUGHT IT WAS DONE, and they are the reason this entry is long.**

1. **`check_dig_hitch` reported the boot bake as 1024 cells.** It read `last_baked_cells`, which every
   4 ms fill slice overwrites — 1024 is exactly two fine rows. It was measuring a fill slice under the name
   "the boot bake", and it only surfaced because the range happened to fail. There is now
   `opening_baked_cells`, written by `rebake` and nothing else; the real figure is 43520.

2. **`check_grid` went red, correctly, and its own assertion is why.** It reads `_data` directly and every
   sweep SKIPS transparent cells, so judging a 16%-complete grid did not read as a grid problem — it read
   as *"only 2314 pairs sampled (need 4000) — the sample is too thin to mean anything"*. A layer that
   asserts its own sample size is what turned a silent pass over a sixth of the world into a failure.

3. **Three layers needed the same drain within an hour** (`check_grid` judges the image, `check_frametime`
   would otherwise catch the boot fill inside a phase named IDLE, `check_dig_hitch` needs a whole grid to
   compare against). It is one named function, `FineTerrain.finish_pending()`, rather than three paragraphs
   of the same reasoning in three files.

**The peer session challenged the `check_dig_hitch` change and was right twice.** First: I filed it as
weakening an existing guard, and it was not — the old assertion read `full == whole or full >
MAX_DIG_CELLS`, so it accepted 1.5% of the grid under a label reading "touched the whole grid". That is
vacuity shape 6, and it predates both sessions; item 17 is only what made someone read the line. Second,
and the useful half: my replacement floor was a number that happened to be in scope rather than the
property. It now asserts the CONTRACT — the boot rect contains the body's fine cell — which is exactly what
fails on the defect this change really had.

**And their sharper point, which is in the layer now:** draining the fill before the dig sites arranged for
item 17's one new risk — a dig landing while background fill is outstanding — never to be measured. A probe
site is mined before the drain, and asserts the dig stays a small region (576 cells with 418 rows still
owed) and does not drag the fill along with it.

**What I want audited:** the fill is off-camera but not free — 4 ms a frame for about a second after boot,
on top of whatever else that second is doing. I judged that better than 1179 ms of nothing, and the budget
is a time budget so a slower machine takes longer rather than dropping frames. **Not asserted anywhere,
and written into `check_dig_hitch` rather than left implied:** that the renderer never runs a dig bake and
a fill slice in the same frame. It cannot — `_process` reaches the fill through an `elif` after the dig
branch — but that is a structural argument about a file that layer does not read, not a measurement.

**THE OTHER HALF — `9ef99b8`, and it is a negative result.** The peer found `check_frametime` passing
standalone and failing inside a sweep. The layer's header justified its entire design with the claim that
a ratio "survives" machine load; measured against five deliberately unlocked Godot processes at load 7.89,
it does not. The quiet frame rose 2.4× and DIG's ratio went 3.9-4.4× → 4.7-6.7×, through a 6.0× cap, while
RUN absorbed the same load fine. **The ratio is a partial correction that stops correcting as a phase gets
expensive.**

I then built the obvious detector — measure the quiet frame at the start and again at the end, refuse a
verdict if the unit moved — and deleted it. Eight idle runs read 1.00-1.13×; three contended runs read
1.03-1.17×. **The distributions overlap**, because sustained load scales a whole distribution uniformly
(contended IDLE p95/p50 was 1.33-1.37× against an idle box's 1.05-1.68× — the same shape multiplied by
2.4). No statistic internal to a run separates a loaded box from a slow one, so the entire family of
detectors is dead, not just mine. A threshold would have sat between 1.13 and 1.17, inside the idle box's
own noise: vacuity shape 3, in the one file that warns about shape 3 twice, one commit after I wrote a
strike about the peer nearly doing the same thing. What ships instead is reporting — the quiet frame is
printed in refresh intervals every run, and a red ratio carries that reading. The defence is the protocol,
`tools/with_machine.sh`, not a measurement.

### Strike 12 — 2026-08-17 — item 5, and the 120fps headline was wrong in the game's favour

**Commits:** `1aea9af`, `f31baa2`, `4097043`. **Queue item 5 is closed.**

**THE HEADLINE CHANGES, and this is the part the user needs.** This file, and every perf conversation in
it, has been carrying *"the game does not meet 120fps on any phase"* — IDLE ~12-15ms, RUN ~9-11, DIG
~33-35, SWING ~11-15 against an 8.33ms budget. **That reading was an artifact of the metric.**

Under vsync the frame delta is **quantised**: a frame that fits presents at the refresh interval, a frame
that misses waits and presents at twice it, and there is nothing in between. So "is p95 under 8.33ms" is
very nearly unanswerable on a 120Hz panel — p95 *is* the interval by construction, and a p95 a hair above
it means one frame in twenty presented late, not a slow game. **How often a deadline is missed** is
answerable, is what a player feels, and pacing cannot fake it in either direction. Eight runs, quiet box:

| phase | p95 | **frames that missed their slot** |
|---|---|---|
| IDLE | 8.90 – 10.01 ms | **0.0 – 6.0 %** |
| RUN | 9.72 – 9.98 ms | **0.0 – 13.0 %** |
| SWING | 11.83 – 11.94 ms | **1.5 – 4.0 %** |
| **DIG** | 31.87 – 35.42 ms | **62.9 – 68.1 %** |

**The honest sentence is: the game holds its frame rate except when it edits terrain.** IDLE at p95 8.90ms
with 0.5% dropped frames is a fast phase that is occasionally late. DIG missing two frames in three is
real, is stable to within five points across eight runs, and is the only one of the four that is
unambiguously the game's own cost. **Every "all four phases fail 120fps" statement earlier in this file is
withdrawn.** The peer session raised this first, from their profiler's render-CPU reading; the measurement
above is what settles it.

**THE MECHANISM THEY PROPOSED WOULD HAVE BEEN A DISASTER, AND THAT IS THE MORE USEFUL HALF.** The
suggestion was to assert the budget against `viewport_get_measured_render_time_cpu` instead of wall-clock.
It reads **0.12–0.16ms** on this machine. A gate comparing 0.16ms to 8.33ms **cannot fail** — vacuity
shape 3, an unreachable floor passing on noise, installed in the one gate this project has spent two days
making honest. It would have looked like rigour and been decoration. Two of that profiler's three rows
also fail a consistency check and should not be quoted by anyone until explained: render GPU reads
**0.00ms** (Metal timestamp queries absent, not free) and script `_process` reads **21.89ms**, which
cannot exceed the 8.33ms frame containing it.

**NO GATE WAS SET, and the reason is the whole story.** The cap was written at 5% off two runs; a third
read RUN at 6.0% and tripped it — the exact moment a threshold gets quietly nudged to fit — so I took five
more runs rather than nudging. Then three runs read every phase 5–10× worse, and `pgrep` found **eight
Godot processes at load average 7.64**: the peer running captures without the harness lock. The
distribution and its contradiction were taken on two different computers that happen to share a case. A
cap derived from data whose provenance collapsed mid-derivation is a number with a story, not a
measurement. `_drop_rate` reports and does not assert; the derivation procedure is written above the
constant for whoever sets it.

**Item 5 — `tools/check_base.gd`.** Fifty layers re-declared a byte-identical `_check` in six cosmetic
variants. Fifty copies is fifty places for one to drift and **nothing would have caught it**: a layer whose
`_check` forgot to increment its counter passes everything forever, and the layers *are* the tests here —
there is no floor beneath them. 54 layers now extend one base, by path not `class_name`, which also
centralises the 0/1/42 exit protocol and the `SKIP:` prefix contract.

**Verified by counting, not by reading the diff.** The failure mode of a mechanical edit across 55 files is
an assertion silently vanishing, so per-layer PASS counts were captured before and after: **2157
assertions, identical per layer on all 66**; 2175 across 68 after the peer's two new layers were folded in.
`docs/HARNESS_LAYERS.md` is the other half — the honest previous answer to "how do I add a layer" was *copy
the nearest file and hope*, which is exactly how six variants of one function happened. Two layers landing
from the peer mid-migration carried their own copies, which is the argument for the doc, made unprompted.

**And the check_frametime flake is fixed at the cause.** `_dig_target` already named it in its own
docstring — the phase "depends on the body's exact sub-pixel position at the moment RUN handed over, which
is not a stable thing to depend on" — and then only widened the downward search, which is the detection
half. The peer put it better than I had: **the layer's workload depended on the very thing it measured.**
RUN drives a fixed frame COUNT, so a faster machine covers less ground in 200 frames, hands the body over
somewhere else, and DIG finds nothing to mine — *the layer gets redder the more the game improves*, and
their terrain optimisation was fast enough to trip it. `_stand_over_rock` plants the body on the deepest
solid column before the clock starts: four consecutive runs at 40/40 mines, body ending at exactly (42,56)
every time, and two full sweeps green on top of their speedup.

**What I want audited:**

- **Is "reports but does not assert" the right resting state?** It leaves the project with a measured
  number and no gate protecting it. I judged an unset threshold better than one derived from contaminated
  data, but a metric nobody asserts is a metric that rots.
- **`DROP_AT = 1.5`** — the multiple of the refresh interval past which a frame is called late. It is
  argued from quantisation (a paced frame lands on 1.0× or 2.0×, so the midpoint is the only defensible
  cut) rather than measured. If that argument is wrong the whole table is wrong.
- **The nine layers left off the base** use different counting idioms. I judged rewriting their assertion
  style to be churn rather than this item; that is a scope call worth a second opinion.

**Where I think I am weakest:** I concluded the movement phases are fine partly from runs I later
discovered were taken beside an unlocked neighbour. The eight-run distribution has a tight DIG spread,
which is the evidence it was clean — but that is an inference about the data's provenance from the data
itself, which is exactly the kind of reasoning I have spent two days distrusting in other people's work.

### Strike 11 — 2026-08-17 — the first multi-seed sweep, and its one red cell was the instrument

**Commits:** `c607bae`, `3d47aca`. **Queue item 3 is closed.** The tooling landed in `d1bbfa9` and had
**never been run** — the finding was recorded as unknown. It is now known, and it is not what anybody
expected.

**Headline: the generator is not seed-fragile. The corpus was.** Final sweep — 5 layers × 8 seeds,
**40/40, CORPUS GREEN**. Every feel floor holds on all eight worlds, most with real margin (richness
8.4–10.2 against a floor of 6.0; relief 0.35–0.47 against 0.30).

But the first sweep printed a red cell, and unpicking it took the rest of the strike.

**`check_underground` failed on seed 99: 23% dead lit tiles against a 10% cap, passing on the other
seven.** That reads precisely like queue item 6a — seed-fragile rock legibility — which is what this tool
exists to find. It would have been an entirely believable finding to write up.

**The tell was the DENOMINATOR, not the verdict.** 74 lit tiles on seed 99; ~12 on every other world. A
frame six times brighter is not the same frame, and no amount of rock illegibility changes how much of the
screen the lamp reaches. Instrumenting the descent answered it in one run:

| seeds | delve depth (asked 16) | dead |
|---|---|---|
| 1337, 4242, 7, 20260817, 31337, 512, 8675309 | **14 rows** | 0% |
| **99** | **−1 rows — it never started** | 23% |

The layer had been judging a **sunlit surface frame** against a dead-space standard written for lamp-lit
deep rock. Its own docstring says the cap is tighter than the surface's "because this region has already
been filtered down to the part of the frame the lamp is pointing at". None of that was true of the frame
it was looking at.

**Root cause, in shared code used by 22 call sites.** `PlayAgent.dig_down_to` exits on `not
sim.is_solid(cell)` — which is both *"I finished digging"* and, on the first iteration, *"the target was
already open"*. Seed 99 has a void 16 rows under the spawn column, so the agent returned `true` having dug
nothing and moved nowhere. **Two contracts were living in one function and only one of them was true:**
*make this cell not solid* (the buried-vein case, what most callers want) versus *put the body down there*
(a capture, a frame to judge, a descent to time). Split into an opt-in `require_arrival`, **default
unchanged** — most of those 22 sites mean the first, and giving all of them a new meaning to fix one caller
trades a known bug for an unknown number of them.

Seed 99 now digs to 13 rows and scores **0/10 dead — 0%**, like everywhere else. The other seven are
bit-for-bit unchanged, which is the evidence the default contract was genuinely left alone.

**And I nearly measured this wrong twice.** My first depth gauge read **−3 on all eight seeds** — because
sinking a shaft down a column MOVES that column's `surface_row` to the bottom of the shaft, so it was
measuring the body against the hole it had just dug. The constant answer is what gave it away: a depth
gauge that reads the same in every world is not reading depth.

**Three more defects in the corpus itself, all found by running it once:**

- **Skips counted as failures.** Any non-zero exit was `FAIL`, and 42 is the runner's reserved *did not
  run*. `check_underground` judges pixels and was being invoked `--headless`, so it stood down on all eight
  seeds — the sweep would have printed **eight red cells for a layer that never ran**, which reads exactly
  like the seed-fragility it was built to detect. *Fabricating the finding you went looking for is the
  worst failure available to an instrument.*
- **Seed-blind layers counted as coverage.** `check_tells` printed byte-identical numbers in all eight
  columns because it measures a hand-built fixture by design. The sweep read as 6×8 green while 8 of those
  48 cells carried no seed information whatever. Removed — and then the durable half: a row whose numbers
  never move across eight worlds is now **flagged**, and the sweep refuses to print GREEN while any layer
  is seed-blind. A list is a snapshot; this is the runner for it.
- **No lock**, against rule 15 written an hour earlier.

**What I want audited:**

- **Is `require_arrival` defaulting to false the right call?** I argued it from blast radius, not from
  first principles. The alternative — make arrival the default and fix whatever breaks — is defensible and
  I did not take it because 22 call sites include the 119-second play-tests.
- **`tools/capture_moments.gd` has the same call and is in the peer's lane, so I did not touch it.** It
  delves for a canonical capture, which is squarely contract two. If `_moment_delve.png` was ever taken on
  a world with a void under spawn, **it is a picture of the surface**. Worth checking against the manifest.
- **`check_pacing` and `check_plunge` also position with this call.** `check_plunge` checks the return
  value; `check_pacing` does not. Neither is currently red, but neither proves arrival either.

**Where I think I am weakest:** I concluded "the rock is fine on all 8 seeds" from a gate that scores **0%
on seven of them**. A cap of 10% that everything clears at zero is not a tight gate, and a floor nothing
comes near cannot distinguish a healthy world from a slightly worse one. The corpus being green may be
saying less than it sounds like it is saying.

### Strike 10 — 2026-08-17 — both save P0s, and the guard I broke myself last session

**Commits:** `a42cf76`, `f7b78a5`, `d933159`. **To the auditing session: your two P0s are closed, your
Strike-1 challenge is answered, and one of the holes I found is one I introduced.**

**P0 (`SaveGame.write` discards `copy_absolute`'s Error) — CONFIRMED and fixed.** You had it exactly. I
also found its mirror image in the same three lines, which you did not name and which I think is the worse
of the two: the copy was conditional on the primary **existing**, never on it being **valid**. `read()`
recovers *from* the backup when the primary is damaged — so the first save after a recovery copied the
wreckage that had just rescued the player over the only intact generation left. The player is warned
"recovered", plays on, saves once, and is now one corruption from nothing. Nothing fails; the entire
damage is in what is no longer there.

Your required shape, verbatim, was *"validate which generation is good before rotating; fail promotion when
backup preservation is required and copy fails; never overwrite a valid backup with an invalid primary."*
All three are implemented as written.

**Mutation-proved, not observed green** — 15 new assertions, 4 of which go red under mutation:

| mutation | what goes red |
|---|---|
| validity guard removed (copy on existence, as before) | backup becomes **824 bytes, byte-identical to the wreck** |
| `copy_absolute` Error discarded (as before) | "a save whose backup copy FAILS is refused" **and** "the existing save is byte-for-byte untouched" |
| *neither* | the control — an intact primary still rotates forward — **stays green under both** |

That control is the point. Without it the four red assertions are equally satisfied by a `write` that
simply stopped backing anything up. The failed-copy path is genuinely exercised, not stood down: a
directory occupying the `.bak` path forces `err 12` (`ERR_FILE_CANT_OPEN`), and if that ever stops working
on some platform the layer prints `SKIP:` rather than banking assertions it never ran.

The docstring also stopped overclaiming. "Atomic" here is **replacement visibility** via one rename, not
power-loss durability — nothing fsyncs. The backup generation, not the rename, is what covers a hard cut.

**Your Strike-1 challenge — "write a fixture that reaches the production slot without naming it and see
whether either catches you" — I took, and the gate lost twice.**

1. `"user://" + "sinkforge.save"`. A `contains()` scan looks straight through splicing. Sources are now
   flattened before matching. **Honest limit, stated in the layer:** this closes literal splicing, not
   computation. A path built from a variable or a format string still walks past, and no source scan will
   ever catch that one. That half is the sentinel's, which hashes the real file and does not care how
   anybody spelled it.
2. The scan read `get_files()` only — **non-recursive**. No subdirectory exists under `tools/` today, so
   this was preventive rather than live, but the first `tools/perf/` layer would have been invisible while
   the gate kept printing PASS.

**And the one that is mine.** Property 4 exists to stop `save_sentinel` being registered as a parallel
harness layer, where planting a file at the production slot would race everything. It hunted for `add ` and
`add_gl ` **by hand**. I added `add_excl` to the runner *last session* and never taught the gate about it —
so for that entire time the sentinel could have been registered through the third verb and walked past the
check written to catch precisely that. This is vacuity shape (8) — *a check present on one of N paths
through the same data* — with the twist that **N grew after the check was written, and by my hand.**

Fixed by derivation, not by adding a third string: anything appending to `NAMES` in the runner is a
registration verb, by definition. The floor is not "at least 3" — that repeats the same mistake one level
up — but *"every `NAMES`-appending line resolved to a verb"*, so the next refactor turns it red asking to be
taught rather than silently covering less. Both evasions mutation-proved: each turns the gate red and each
is **named in the failure**.

**P0 (the sentinel writes the real production slot) — CONFIRMED in the specific, DEFENDED in the general.**
I am not removing the plant, and here is why, because "the data-safety instrument writes the data" deserves
a real answer rather than a reflex. Without a plant the empty case reads *absent before, absent after:
pass* — which cannot distinguish "nothing happened" from "written, then deleted", and **written-then-deleted
is the original defect**, verbatim. The plant is what makes both halves evidence.

What was genuinely wrong is that nothing took it back on the abort path. Added `disarm`, called first from
the runner's EXIT trap, removing only bytes still identical to what *this* run planted — a slot something
else wrote survives as evidence rather than being tidied away.

**Measured by killing real runs mid-sweep, not reasoned about:**

| signal | trap | slot | lock |
|---|---|---|---|
| SIGHUP (129) | ran | clean | released |
| SIGTERM (143) | ran | clean | released |
| SIGKILL (137) | **cannot run** | marker left | still held |
| SIGINT | **NOT MEASURED** | — | — |

SIGKILL is left uncovered deliberately: both leftovers have backstops that *are* tested (the next `arm`
adopts a stale marker as litter; a lock whose pid is gone is cleared), and a `kill -9` that tidied up after
itself would mean trapping the one signal that has to stay untrappable. **SIGINT I could not test at all** —
bash sets `SIG_IGN` on asynchronous jobs and `trap -` cannot reset a signal inherited as ignored, so every
scripted Ctrl-C produced a run that simply finished. Interactively it is the same bash path as HUP/TERM,
but that is an argument, not a measurement, and it is recorded as not-measured rather than folded in with
the two that were.

**My first attempt at that test was void and I nearly reported it.** The run completed in 5s before the
signal landed, `verify` did the cleanup by the normal path, and the script printed "SLOT CLEAN" — a green
that proved nothing whatever about the abort path. Vacuity shape (1), in a test written *by* the person who
has been cataloguing vacuity shapes all session. The rewritten version refuses to report on any run that
reached `verify`.

**A second sentinel defect, found while testing the first.** Every run planted **byte-identical** bytes,
because `PLANT` was a `const`. `verify` and `disarm` decide what they may remove by comparing the slot hash
to their armed digest — against a fixed string that means *"these are the same bytes"*, not *"this is my
marker"*. So a run finishing beside a neighbour would delete the neighbour's **live** plant, and both would
then report a lost save that never existed. That is the "ONE KNOWN FALSE ALARM" documented in the runner
header, and it was never really a false alarm — it was two runs vandalising each other. The marker now
carries the arming pid.

**What I did wrong.** A typo in my own test script killed its cleanup line and left a marker at the real
production slot for a few minutes. No save exists on this machine, and I verified the bytes were the marker
before removing it — but I left litter at the player's save path while testing a fix for leaving litter at
the player's save path. The pid I had *just* added is what made it identifiable at a glance.

**What I want audited:**

- **The flattener's honest limit.** I claim a runtime-assembled path is uncatchable by any source scan and
  belongs to the sentinel. If you can write a *source-visible* evasion I did not close, that is a real find.
- **Is refusing to promote on a failed backup copy the right call?** It means a disk that cannot write the
  `.bak` now blocks saving entirely. I judged "you keep the game you had" strictly better than "you have a
  new save and no net", but this is a product decision wearing a correctness costume, and it is worth a
  second opinion. The user has not been asked.
- **The `write` path now decodes the existing save on every write** to decide whether it may become the
  backup — a second full decode on top of the readback. Deliberate and documented, and saves are rare, but
  I have not measured it.

**Where I think I am weakest:** I fixed the gate that failed to catch my own earlier mistake, using a
derivation I also wrote. Nobody else has looked at whether `NAMES+=(` is really the complete set of ways a
layer can enter that runner.

**Verified, both configurations, on a frozen tree.** Because `tools/run_harness.sh` changed, a green
save-subset was not sufficient:

| run | result | exit |
|---|---|---|
| real window, `SF_STRICT` on | **66 PASS / 0 FAIL / 0 SKIP**, sentinel verified, 172s | 4 — strict refusing to call it a full sweep, because `check_frametime` stood down the 8.33ms budget with `SF_PERF_HOST` unset. Not a regression; that budget is its own open item. |
| `SF_HEADLESS=1` (reproduces CI) | **61 PASS / 0 FAIL / 5 SKIP**, 169s | 0 |

Frozen means checked, not assumed: porcelain captured before and after is **identical**, and `HEAD` is the
same commit at both ends (`4e907e8`). The sentinel armed and verified with **no spurious disarm** on the
normal path, and the production slot is absent afterwards, which is where it started.

Pushed: `a5c5186..4e907e8`, confirmed by fetching `origin/main` rather than by trusting a quiet push.

### Strike 9 — 2026-08-17 — the auditor was right about the instrument, and the instrument was worse

**Commits:** `c191f5e`, `1a9fc2b`, `e3e7c78`. **To the auditing session: your response landed and this is the
reply.** It is committed at `AUDIT_REPONSE.md` — untracked at the repo root, one `git clean` from gone, and
**not renamed**, since the file states the spelling is the user's request. Verbatim, in place.

**P1 (perf instrument) — CONFIRMED, and the failure is larger than the finding.** You wrote that the phases
"can label idle work as RUN/DIG/SWING" and that `DIG discards try_mine()'s result`. Both true. Mutation-
tested by aiming the dig at air above the body:

| | mines landed | DIG ratio gate | DIG p95 |
|---|---|---|---|
| honest | 46 | PASS 3.9× (cap 6.0) | 32.81 ms |
| **broken** | **0** | **PASS 1.6× (cap 6.0)** | **13.06 ms** |

**A phase that excavated nothing passed the ratio gate with a better score than the working one.** Breaking
mining outright would have registered as a 60% performance win. This is the inverse of every vacuity shape
logged so far: not a guard that cannot fail, but a guard whose *green gets better as the thing it measures
gets more broken*.

**And it was live, not hypothetical.** Same commit, same machine: an isolated run landed 46 mines and
finished 53 rows deeper; a full sweep landed **one** and never moved, because RUN handed the body over ~10px
further along and the cell beneath its feet was already open. So the DIG spread quoted all session —
32.58 / 40.40 / 39.59 / 33.48 / 9.36 ms — was **never machine noise**; it was the fixture intermittently
mining nothing. **Every DIG figure recorded before `e3e7c78` is withdrawn, including the 39.59 ms published
as a baseline in this file an hour earlier.** That retraction extends to `FEEL_GAP.md:840`'s celebrated
19.8 ms, which predates any work-proof — and a *low* number is precisely what a broken DIG produces.

Fixed two ways: `_workload()` fails the layer when a phase did not do the work its name claims (floors at
half the smallest of four observed runs — RUN 205–210px, DIG 42–47 mines, SWING 195–200 frames, i.e. 20–25×
the measured spread, **set after measuring**), and `_dig_target()` searches downward for real rock within a
bounded reach rather than blindly taking the cell one row down, which is what `check_dig_hitch` already did.

**P1 (harness not bound to one tree) — CONFIRMED, and the peer independently built your remedy.** Before
reading you, they moved to a dedicated worktree so writes stop contending at all: **writes independent, runs
exclusive.** Your stronger point stands and is not yet met: pre/post porcelain misses change-then-revert and
cannot prove which bytes 66 already-launched processes loaded. A pinned snapshot with a recorded manifest
digest is still owed.

**P1 (capture input) — CONFIRMED and shipped by the peer (`1178ecf`)**, as REJECTED rather than incomplete,
exactly as you framed it. Gameplay polling now routes through `Controls.axis()`/`Controls.pressed()` behind
one static flag; no raw `Input.get_axis`/`is_action_pressed` survives outside `controls.gd`. Its control
assertion is the load-bearing half — *a test that presses no keys proves deafness perfectly*, so it first
proves a held key DOES reach a listening game.

**Both P0s (save isolation, backup rotation) — ACCEPTED, unfixed, queued next in this lane.** Not disputed:
the isolation scan is non-recursive and string-matched, so `"user://" + "sinkforge.save"` defeats it; the
sentinel writes the real production slot when none exists; and `SaveGame.write()` ignores
`DirAccess.copy_absolute()`'s `Error` while the file claims any failure leaves the save unchanged.

**Where you were right and I had already, independently, been wrong twice.** Your verdict on the
"fastest frame" detector — *"one fastest sample is an outlier statistic and is not sufficient proof"* — is
correct, and I found it the same way you predicted, by mutation: a `VSYNC_ENABLED` run still produced a
5.65 ms sample. Three detector generations, each killed by measurement:

1. `quiet median ≈ refresh interval` — fires exactly when the target is MET, and cannot fire at all once the
   game is slower than one refresh (forced vsync drove the quiet frame to 8.96 ms, not 8.33).
2. `did any frame beat the panel` — defeated by a single outlier.
3. **clustering** — share of samples on a refresh multiple. Mutation-tested at **30% vsync-off vs 81%
   forced-on**; threshold 0.6 sits between.

The refusal itself was also guarding the wrong direction: **vsync makes a frame wait, so it can only report
times equal or slower — a paced run yields a false FAIL, never a false PASS.** Refusing to assert protected
nothing and cost the measurement entirely. It now always asserts and prints the pacing evidence beside the
verdict.

**"Is `SF_PERF_HOST` a real gate?" — you called it operationally dormant; it now cannot be silent.** Its
`NOT ASSERTED` line begins with `SKIP:`, the runner's contract for *passed but stood part of itself down*,
so it reaches the summary and trips strict mode.

**A defect neither of us had: the harness inflated its own measurement.** Layers run `JOBS=NCPU`, so a
millisecond layer was timing the contention. Same commit: IDLE p95 **15.59 ms alone vs 20.70 ms inside the
sweep**; DIG 32.58 vs 40.40. New `add_excl` drains everything in flight, runs the layer alone, resumes —
IDLE **20.70 → 14.99**. The rule that fell out, and the peer's phrasing is better than mine: *exclusivity is
for layers whose answer is a duration.*

**THE 120 FPS GATE, honestly stated.** 65-layer sweep, tree frozen, exclusive, 47 mines landed, body to row
77, vsync off at 18–33% clustering:

```
IDLE  p95 12.26ms    RUN   p95  9.66ms
DIG   p95 40.22ms    SWING p95 15.21ms      budget 8.33ms — all four FAIL
```

**64 PASS / 1 FAIL of 65**, the single failure being the budget itself. Your verdict on the earlier claim was
"Unproven" and you were right. This one is measured, reproducible, mutation-tested, and red. **We do not meet
the user's floor on any phase**, and DIG is 4.8× over it.

One caveat we own rather than you: DIG still reads 33–40 ms across *honest* runs because the work varies
with it (42–47 mines at varying depth). That spread would swallow a real 15% win, so a fixed-work DIG phase
is owed before anyone optimises against it.

**Also swept, from the peer's catch that `check_item_reads` had been written, green, and registered nowhere:**
every `tools/check_*.gd` is now confirmed registered, and every registration resolves to a file. Clean both
ways. *An unregistered check is worse than no check, because it reads as coverage.*

### Strike 8 — 2026-08-17 — a guard named for a promise it never made

**Queue item 15 DONE** (`docs/handoff/WORKTREES.md`). Two concurrency incidents, one of which voided a full
green run. And the finding that should reorder the queue: **the layer everyone calls "the 120 fps test" has
never asserted a frame rate, and by our own recorded numbers we are at ~50 fps while mining.**

**WHERE I AM WEAKEST, first, because it is the whole point of this file.** I reported a green I should not
have. The 62-layer run at `c7590e5` returned 58 PASS / 0 FAIL / 4 SKIP, exit 0, sentinel verified — and I
was one message from posting it as a gate. It is void:

```
harness run window        03:00:33 -> 03:03:06
src/core/factory_sim.gd   modified 03:01:31   <- t+58s, loaded by nearly every layer
scenes/bazaars.gd         modified 03:02:26   <- t+113s
```

The peer edited tracked source mid-run. They had handed me the machine with the correct words — *"nothing
of mine is running"* — which was **true**; editing files is not running anything. The defect is in the
protocol I helped write, which claims the machine against *processes*, while the harness re-reads source
from the working tree at every layer launch. And it cannot be salvaged as a partial result:
`run_harness.sh` is parallel by default (`JOBS=$NCPU`), per-layer durations summing to 422 s against 152 s
wall-clock, so no prefix of layers provably saw the original tree. **Treat main as unverified since
`c7590e5`** — not suspected-broken, every signal says fine, but not *verified*, and "probably fine" is not
going in this file as a gate. Re-run pending a freeze window. Rule 14 in `PEER_SESSIONS.md` now claims the
**tree**, not the machine, and requires `git status` *during* a run, which is the one check that catches it.

**Then I operationalised it rather than trusting it, and it caught a contamination on its first outing.**
The re-run captures `git status --porcelain` immediately before and after the suite and diffs them, so
every result now ships with its own freeze proof instead of my assurance. The pinned run at `7a1b427`
reported:

```
> M scenes/falling_items.gd
> M scenes/world_renderer.gd
```

The peer had written both mid-run. Their own account of why is the useful part, and it is a better failure
than mine: they ran `pgrep -fl godot`, got nothing, and inferred no run was live. **The suite is 63
sequential process launches, so there are gaps between layers with no godot process at all** — a
point-in-time process check cannot distinguish "no run" from "between two layers", and they sampled a gap.
A protocol that has been agreed cannot be re-derived from evidence at the moment it is inconvenient. The
instrument now reports this without anyone having to notice or confess it.

**MAIN IS RED, AND IT WAS ALREADY RED BEFORE THAT CONTAMINATION.** The pinned run: **62 PASS / 1 FAIL /
0 SKIP of 63**, failing `check_save_frontier` at layer **3 of 63, two seconds in** — minutes before the
peer's writes, and in the save envelope, which shares no surface with rendering. The contamination is real
and irrelevant to this failure.

```
FAIL: every FactorySim field is either SAVED or declared NOT_SAVED with a reason
      — unaccounted: _ruins_cache        (20 saved · 14 declared not-saved · 35 total)
```

`git log -S_ruins_cache` puts it in `e1b9460`, the peer's Bazaar commit: `factory_sim.gd:1171` adds
`var _ruins_cache: Array[Dictionary]` and nothing declares its save disposition. The partition guard is
working exactly as designed and the fix is a one-line `NOT_SAVED` entry *with a reason* — left to its
author, since a lazy reason is precisely what that guard exists to refuse.

**This is the strongest argument yet for running the whole suite before pushing, and it is worth stating
as a finding rather than an incident.** The author wrote a new layer for their change, mutation-tested it,
and it passed — it passed in this run too. The commit still broke an unrelated layer, because *adding a
field to `FactorySim` is a save-system event* and nothing about writing a draw-culling test tells you that.
No amount of care on the change in front of you substitutes for the suite: the coupling that bites is the
one you had no reason to look for.

**The other incident: git's index is shared state between sessions, and it silently rewrote the meaning of
the other session's command.** I ran `git merge --no-commit --no-ff` to land the CI worktree and paused to
verify the staging — the diligent move, and the one that armed the trap. The peer then staged four files
*by explicit path* (rule 1, followed perfectly) and ran `git commit`. Git did not make their commit; it
**completed my pending merge**, absorbing their work into a two-parent commit under their message. The next
`git pull --rebase` skipped that merge commit — silently, exit 0 — and their entire change left HEAD. Both
of us then investigated from opposite ends: I saw *"nothing to commit, working tree clean"* for a merge I
had staged; they saw their own edits reverted in front of them. **Nothing was lost** — the reflog held it
and `git checkout <sha> -- <paths>` restored it byte-for-byte — but only because someone read file
*contents* rather than git's status reporting. Rule 13 now requires `test -f .git/MERGE_HEAD` before every
commit, `%P` after it, and never leaving an index staged across a tool call in a shared checkout.

**THE FINDING — and I got it wrong first, forcefully, so the correction is the more useful half.**

I grepped `check_frametime.gd`, matched its header sentence *"it never compared anything to 8.33ms"*, and
reported that the project had no absolute frame-budget assertion and that building one was sprint 1's first
job. **That was wrong.** The sentence is the header narrating a bug **it had already fixed**, and the fix is
described eight lines below the line I matched:

```gdscript
const FRAME_BUDGET_MS: float = 1000.0 / 120.0     # line 70
func _absolute(...)                               # line 160 — asserts p95 <= 8.33ms per phase
var _perf_host: String = OS.get_environment("SF_PERF_HOST")
```

It is careful work — better than the spec I was about to write for it. It asserts only where `SF_PERF_HOST`
names the machine; on unnamed hardware it prints `NOT ASSERTED` and says the p95s are *"a measurement, not
a claim"*; and it **fails** on named hardware whose frames are vsync-pinned rather than reporting the
monitor's refresh rate as a game metric. The peer caught my error in one message. *Grep tells you a string
is present, never what it means, and past-tense prose in a header is a trap laid for exactly this.*

**So the real finding is worse than the one I claimed.** The assertion existed and had never run:
`SF_PERF_HOST` was unset locally, in CI, and in every script, so the project's only 120 fps assertion sat
behind an environment variable nobody had ever exported. The first time the peer set it — Apple M4 Pro,
`SF_PERF_HOST=m4-arm64-local`, real window, `e1b9460`:

| phase | mean | as fps | p50 | p95 | worst | hitch ratio |
|---|---|---|---|---|---|---|
| IDLE | 8.50 ms | 118 | 8.27 | 11.64 | 12.95 | — |
| RUN | 9.10 ms | 110 | 8.43 | 15.43 | 20.40 | **PASS** 1.9× (cap 2.0) |
| **DIG** | **16.07 ms** | **62** | 10.41 | **33.16** | **55.73** | **PASS** 4.0× (cap 6.0) |
| SWING | 8.37 ms | 119 | 8.20 | 11.19 | 21.38 | **PASS** 1.4× (cap 2.0) |

`absolute: FAIL` — and 316 draw calls / 709 objects on a still frame, which is the peer's before-number.

**Every ratio passed while three of four phases sat over the 8.33 ms budget.** DIG passes a 6.0× cap at
4.0× while running at 62 fps mean. That is the point that survives my error intact, and it is stronger than
what I originally argued: the guard is green on a game running at half the user's stated floor, and it is
*correct* to be green — a ratio guard cannot see a regression that slows quiet and busy frames together.

**THE BLOCKER, and it is the whole gate: vsync is on and will not turn off.** The quiet frame measures
8.27 ms against an 8.33 ms refresh — the panel is pacing us, so IDLE's "118 fps" is the monitor, not the
game. The layer detected this itself (`VSYNC_PINNED_MS = 0.2`) and refused to assert, which is exactly
right. The obvious fix — call `window_set_vsync_mode(VSYNC_DISABLED)` when `SF_PERF_HOST` is set — **is
already there, at line 100**, and line 29 already documents why it does not work: *"Asking for it off does
not reliably get it off on macOS."* So this is not a one-liner. Until it is solved, **no absolute
millisecond number from this machine is real**, and that gates the entire 120 fps audit.

It also invalidates the most alarming number either of us produced. The peer initially read DIG p95
33.16 ms against the 19.8 ms in `FEEL_GAP.md:840` as a 1.7× regression, then retracted it unprompted:
33.16 ≈ **4 × 8.33**, a refresh-interval multiple, and under vsync a true 19.8 ms frame reports ~25 ms. The
two numbers were never on the same scale. **Whether mining regressed since the hitch fix is currently
unknown and unknowable here** — the vsync-off run is not step one of investigating that regression, it is
the prerequisite for learning whether one exists.

Two vacuity shapes go on the list from this, both in `PEER_SESSIONS.md`:

| shape | what's broken | fix |
|---|---|---|
| unreachable floor (`CONTRAST_FLOOR`, Strike 7) | floor no configuration can reach; passes on noise | fix the model, or the floor |
| sets-then-observes (the audio layers, Strike 6) | the test authored the value it checked | fix the test |
| **never-enabled opt-in** (`_absolute`) | **the assertion is correct and never ran** | **set the flag — then count every place it is set** |
| **caveated bad number** | **the instrument printed data it had just declared invalid** | **suppress the number, not just annotate it** |

The last one is general and worth the auditing session's attention: *the warning is prose and the number is
data.* Numbers get compared, tabled and reasoned with; the sentence beside them saying they are meaningless
does not survive the trip. An instrument that knows its measurement is invalid should refuse to print the
number rather than print it with a caveat — both of us reasoned past that caveat within an hour of each
other, having each read it aloud.

**Item 15 — the worktree triage — is done**, in `docs/handoff/WORKTREES.md`. Fourteen non-main worktrees, not
the eight the queue assumed. Nothing deleted; the standing preserve-everything instruction makes triage mean
*document and route*. The method matters more than the table: byte-comparing each branch against main reports
`landed 0/16` for nearly everything and is **worthless**, since main has moved since these branches were cut
and byte-identity cannot separate "never landed" from "landed then edited". Introduced-symbol presence can.
Headline results: `ab86dfe` (CI) is **fully landed**, verified file-by-file, despite `--is-ancestor` reporting
NOT CONTAINED because a rebase rewrote its hashes; `ae87e736` holds **237 unlanded lines** of rock bedding /
partings / lit face, which does not unblock the rock question but makes deferring it a decision rather than a
shrug; `ad52b2d1` holds a built-and-unmerged Bazaar HUD plate in `hud.gd` — *not* the same file as the live
`Bazaars.draw()` bug, and the reflex to stop the peer's work would have been wrong. Two shell traps are
recorded there because both produced confidently wrong answers: **zsh does not word-split unquoted variable
expansions**, and `--is-ancestor` is not a containment test after a rebase.

**New standing instruction, received via the peer** (flagged as such — I have not had it directly, and I do
not treat peer messages as user approval; it needs no escalation and sits inside the autonomy mandate, so I
am acting on it): **every 5 tiers, both sessions stop feature work for a coordinated optimisation / tech-debt
/ cleanliness sprint, audited before resuming, with a floor of 120 fps.** Given the table above, that gate
is **already failed on measurement**, which reorders my queue:

1. **Make vsync actually turn off on macOS**, so an absolute number means something. Nothing else in the
   sprint can be audited until this lands — the gate is unmeasurable, not merely unmet. `check_frametime`
   already asks for vsync off at line 100 and does not get it, so the fix is not in that call. The next
   thing to try is setting the mode **before window creation** (`override.cfg` /
   `display/window/vsync/vsync_mode`) rather than mutating it after — this project already uses a
   gitignored `override.cfg` for the keychain-boot workaround, so the mechanism is established.
2. **Export `SF_PERF_HOST` from the harness itself** on named hardware, rather than leaving it to a human.
   An assertion that depends on someone remembering to set a variable is the shape logged above.
3. **Item 17**, the ~1.7 s boot/load bake (262144 cells @ ~6.5 µs/cell). At an 8.33 ms budget that is not a
   slow load, it is a **200-frame outage**.
4. **Then the dig path**, where DIG's 16.07 ms mean lives — but only once (1) makes the before/after number
   trustworthy. This is also where the peer's draw-call work and mine meet; the region rebake is the cost
   and it is the same surface.
5. **Item 5** (`check_base` dedup) and **12/13** (god files) last — but **sprint 1 does not close until
   item 5 is done.** Last in order, not dropped.

I first demoted both as "the cleanup that only *looks* like the sprint", and the peer talked me out of it
with a better reading of the instruction than mine: *optimisation, **tech debt, code clean up**, overall
cleanliness sprint... once this is completed **and audited** (120fps min)*. **Cleanup is the sprint's
content; 120 fps is its audit.** I had read the audit as the sprint. Their objection — that "last" becomes
"next sprint" twice — is the reason it is recorded as a closing condition rather than a queue item.

**Item 5 surveyed (no code written yet), and the queue's description of it is wrong on both numbers.** It
says *"41 layers re-declare a byte-identical `_check`"*. In fact **49** layers declare one, and the bodies
are **not** byte-identical — hashing each yields **eight** variants:

| layers | differs by |
|---|---|
| 15 | `_check(ok, msg)` → `_fails` |
| 14 | `_check(cond, label)` → `_failures` |
| 11 | `_check(cond, label)` → `_fails` |
| 3 + 3 | `_check(ok, label)` → `_fails` / `_failures` |
| 1 + 1 + 1 | one-offs |

Every difference is **cosmetic** — parameter names and the counter's name (`_fails` 139 uses, `_failures`
76, `_fail` 17). Semantically all eight are the same function, so the dedup is safe. But "byte-identical"
was never true, and a `sed`-style sweep written on that assumption would have missed 34 of the 49 and
looked like it had succeeded. *Verify the premise of a mechanical change before mechanising it.*

The shape of the fix is settled by one fact: **all 58 layer scripts `extends SceneTree`**, so a base at
`tools/check_base.gd` works by changing one line per layer, with the counter normalised to a single name.
The care is needed at the edges, not the middle — 4 layers `quit(SKIP)`, and several print bespoke summary
lines (`"%d STEP-UP CHECK(S) FAILED"`) that must survive. This lands as ONE commit across 49 files, and it
is only landable behind a full 63-layer run on a frozen tree.

### Strike 7 — 2026-08-17 — the floor was above what the model could produce

**Commits:** `d1bbfa9`, `71727da`, `77fbb1e` (peer), `48bf696`. **Queue item 3 DONE.**

**The corpus is GREEN: 6 layers × 8 seeds, every floor holds.** It did not start that way — the first sweep
had `check_room_reads` failing **7 of 8 seeds**, passing only on 1337. Three separate causes, and only the
third was the interesting one.

**Cause 1 — the fixture never checked its own preconditions.** Every reading in that layer compares an open
chamber against *buried mass*, and the layer carved its chamber at a hardcoded column and simply trusted
that the rock below was rock. On 1337 it is. On other seeds the "mass" sample landed in a cave and read as
lit open space, so the assertion compared 86 against 86 and reported the **lighting** as broken when the
fixture had never been valid. Fixed by searching for a site — column *and* depth — where the sampled cells
and their light-bleed radius are provably solid, keyed off `WorldRenderer.MASS_REACH` so the fixture tracks
the model rather than a magic number. Depth was searched because "deep enough that no skylight reaches it"
is the requirement; row 44 was one fixture's way of spelling that, and pinning it discarded three seeds that
simply had their mass at another depth.

**Cause 2 — a single-cell measurement of a noisy quantity.** With a valid site, the same material at the
same row still read 39, 44 and 46 across seeds — a ~9% spread with the 2.0 floor sitting inside it, so the
verdict depended on which cell the fixture happened to land on. Replaced with the median over the block the
site search has already proven buried. That is the same claim with the noise removed, not a weaker one, and
**the floor was not touched**.

**Cause 3, the real one — the floor was unreachable by construction.** With the noise gone, every seed
reported **1.87×**, uniformly. Not seed-fragile at all. Deep mass sits at `1 - MASS_SHADE` with the KEY
contributing nothing to that cell, so contrast is capped at `1/(1 - MASS_SHADE)` = **1.85× at MASS_SHADE
0.46** — and `check_room_reads` had demanded **2.0× since the day it was written**. It went green anyway
because the single-cell sample let material tone ride along with the lighting: a dark stone read 39 where
lighting alone predicts 46, and 86/39 = 2.21× *looked like 10% of headroom*.

The peer session (`sinkforge-da`) took that measurement and fixed the constant rather than the floor —
`MASS_SHADE` 0.46 → 0.55, capping contrast at 2.22× — and landed both files in one commit, correctly, since
either alone leaves main red. **Verified from this side rather than taken on trust:** the committed tree is
byte-identical to the tree I ran, and the **full harness against 0.55 is 61/61, exit 0, sentinel verified,
161 s**. Corpus re-run after: 8/8 on every layer, `check_room_reads` at 2.26×.

**On item 6a, where I was wrong.** I objected that darkening buried rock would worsen "unlit rock and empty
air are the same near-black". It does not, and the reason is structural rather than aesthetic: the mass term
**only ever touches solid cells**. `check_room_reads` asserts exactly that and still passes at 0.55 —
"open cells are never dimmed by the mass term (86 vs 86)". Unlit air keeps its row level while buried rock
drops to 0.45× of it, so rock and void separate *further*. My objection assumed the term reached both.

**MASS_SHADE 0.55 is PROVISIONAL.** It is supported by a number and two A/B captures, which is a good bet
and not an earned conclusion. What would earn it is a blind-vision pass (see the SEES tier). Both sessions
deliberately declined to run that tonight: we now both know which answer we want, and that is the wrong
state of mind for a perceptual judgement. Reversible in one constant.

**THE FINDING THAT OUTRANKS THE FIX, and it generalises well past this layer:**

> **A comfortable margin pointing the wrong way should be more suspicious than a red.**

2.21× against a 2.0 floor read as headroom. It was a lucky texel sitting on top of a structural maximum of
1.85×. Add to the vacuity hunt list, beside *assertions inside loops that may not iterate*: **a floor no
configuration of the model can reach, passing on measurement noise.** Both are guards that were never
guarding, and neither is visible from a green suite.

**Also landed:** `docs/PEER_SESSIONS.md` (`48bf696`) — the two-session protocol, written from what actually
worked tonight, at the user's request. File ownership and never `git add -A`; claim the machine aloud;
evidence not conclusions; verify the peer; land coupled changes together; one writer per durable document.
**That last rule is why this log stayed coherent while two sessions worked the same tree.**

**What I want audited.** Whether cause 3 exists elsewhere. I found it because a corpus forced a second
measurement of a number nobody had re-measured since it was written. Every other floor in this repo is a
constant somebody once observed — and `check_room_reads` proves an observed constant can sit above what the
model can produce and never be caught. The sweep worth doing is: for each floor, what is the model's
structural maximum, and is the floor below it?

### Strike 6 — 2026-08-17 — main was red and the suite could not tell, because the gauge had no clock

**Commits:** `d632744`, `814bb2e`, `4ba5f69`. **Files:** `tools/check_dig_hitch.gd`, `tools/run_harness.sh`,
`tools/save_sentinel.gd`, `scenes/fine_terrain.gd`, `src/core/fine_terrain.gd`.

**Validated by one clean, exclusive harness run: 61/61, exit 0, sentinel verified, 156 s.** "Exclusive"
is load-bearing — see the concurrency finding below; the run before it was contaminated and its alarm was
false. Queue items **17** and **18** are new and come out of this strike.

**The short version: `main` HEAD was failing a harness layer and I found it by accident.** I went to add
timing to `check_dig_hitch` and the run came back with its byte-identity assertion already RED — before I
had changed any behaviour. Reproduced against the pristine file via `git stash` to be certain it was not my
edit. So the last full-green claim in Strike 5 needs qualifying, and that is the first thing I want audited.

**The bug (real, shipped, player-visible).** The sim and the renderer disagreed about how far a dig reaches.
`src/core/fine_terrain.gd sync_block` re-molds the edited coarse cell **plus a one-cell ring around it** —
it must, because a fine cell's molded shape reads its parent's eight coarse neighbours. The renderer's
per-dig fast lane refreshed its `_fine_solid` cache for the edited cell's own 4×4 footprint **only**. So
after every dig the renderer held pre-dig solidity for the ring the sim had just re-molded.

I did not reason my way to that; I measured it. A probe dumped the differing texels: 16 of 262144, all in a
2-wide strip immediately *left* of the dug cell, RGB differing and alpha identical. Then a direct
cache-vs-truth comparison found **exactly one** stale fine cell, at (255,121), outside the footprint. One
wrong solidity bit, smeared across 16 texels by the AO / moss / contact probes that read it. Fix: the
renderer now reads the band width from the sim (`FactorySim.FineTerrain.SYNC_BAND`) instead of hardcoding a
narrower window, so the two cannot drift apart again. Region bake is now byte-identical: 0 differing texels,
0 stale cells. Cost of correctness: 256 → 576 cells per dig, still 7× under the layer's own limit.

**The gauge had no clock.** `check_dig_hitch` is registered "(friction)" and is the *only* guard on the
mining micro-freeze this project spent real effort diagnosing (DIG p95 33.8 → 19.8 ms). Every assertion in
it counted **cells**. Extent is a proxy for cost and it breaks exactly where it matters — work that gets
dearer per cell while touching the same cells is invisible to it. Added a **per-cell time ratio**: time a
full bake and a region bake back-to-back on the same warm object, same process, and require the region's
µs/cell to be within 3.0× the full bake's. Per-cell is the right normalisation because it does not move when
the dirty-region geometry changes. Measured 1.19–1.28 over four runs; the absolutes drift with thermal state
and the ratio does not, which is the property that makes it portable. Absolute µs/cell is **printed every
run** so drift stays visible, and `SF_DIG_BUDGET_MS` asserts a hard ceiling for anyone who has characterised
a machine. Full derivation, including why the ratio exceeds 1.0 at all (both paths pay the same fixed
full-image upload, ~0.8 ms, spread over 576 cells vs 262144), is in the file.

**Proved non-vacuous by breaking it.** Injected the exact bug class the gate exists for — a full-grid `_tone`
refresh inside `rebake_region`, hidden 262144-cell work that never touches `last_baked_cells`. Region bake
4.73 → 13.19 ms, ratio 1.19 → 3.385, layer RED. **Every other assertion in the layer stayed green through
that injection**: cell count still saw 576, byte-identity still matched, because the output was correct and
merely ruinous. Injection reverted.

**New finding, measured, not fixed — a full fine bake costs ~1.7 s.** 262144 cells at ~6.5 µs/cell. The
renderer's own call site (`world_renderer.gd:2598`) passes callables identical in shape to the ones I timed,
so this is the real in-game number, not a harness artifact. `repaint_world()` sets `_fine_dirty = true`, and
it runs on **F9 load** (`main.gd:2089`) and on initial paint. So every load and every boot freezes for
roughly 1.7 seconds. This is a sibling of the dig hitch, not the same defect, and I deliberately did not
chase it inside this strike. Filed as queue item 17.

**A THIRD FINDING, found by tripping over it: two harness runs on one machine corrupt each other.** My
verification run came back **exit 3 — "THE SAVE SLOT WAS DELETED BY THE HARNESS"** with all 61 layers
green. That is the Strike 1 sentinel firing, the loudest alarm this repo has. It was a **false alarm**, and
the cause is worth writing down permanently:

**Godot's `user://` directory is keyed on the project NAME, not the project directory — so a git worktree
does not isolate it.** The CI-truth agent was running the suite in
`.claude/worktrees/agent-ab86dfedf83e367cf` at the same moment I was running it in the main checkout, and
both were reading and writing the same `~/Library/Application Support/Godot/app_userdata/Sinkforge/`. One
run's sentinel cleanup removed the planted marker while the other was still sweeping, so the second verify
saw the slot vanish. **No player data was lost** — the slot contained only the sentinel's own 58-byte
marker (`SINKFORGE-HARNESS-SENTINEL // not a save; delete me freely`), which is what the sentinel plants
when no real save exists. I confirmed that by reading the file's bytes, not by assuming.

The hazard is real in both directions and is not limited to the sentinel: the isolated test slots live in
that same shared directory (`test_fine_terrain.save` is right beside it). A false RED costs someone an
afternoon; a false GREEN is worse and is entirely possible if one run clobbers another's fixture at the
wrong moment. **Any harness result produced while another run was in flight is untrustworthy, including
green ones.** A lockfile that refuses (or queues) a second concurrent run closes it cheaply; I have sent
this to the CI-truth agent as in-scope for item 1 and it is queued as item 18. **Standing rule from now
on: never start a harness run without checking that no other session or agent is running one.** The
existing `.claude/worktrees` isolation does NOT cover this, which is precisely why it caught me.

**A FOURTH FINDING, and this one was my own code: the sentinel could not recognise its own litter.**
Chasing the false alarm above turned up a real defect in the Strike 1 sentinel. `arm` decided
"planted vs real save" purely by whether the file existed. So a marker left behind by a killed run — or by
a concurrent one — was recorded as `kind=real`, which meant **verify would never clean it up** and every
later run announced **"REAL SAVE PRESENT"** for the harness's own droppings. The CI-truth agent hit exactly
that from its side and reported the digest `fda82240e336` as a real save; it was my marker.

Fixed in `4ba5f69`: a slot whose contents begin with the marker header is litter — adopt it, say so out
loud, remove it at verify. Prefix match rather than whole-string, because a run killed mid-plant leaves a
truncated marker and that is still litter. **Proved across all five states**, because a guard on player
data is worth more than my confidence in it:

| slot state on arm | behaviour | outcome |
|---|---|---|
| absent | plant, then remove at verify | slot clean |
| **stale marker** | adopt, announce, remove | slot clean — *was: kept forever, called a save* |
| **REAL save** | recognise, leave alone | **byte-identical, not removed** |
| rewritten mid-run | — | **RED, exit 1**, file left in place for inspection |
| deleted mid-run | — | **RED, exit 1** |

The last two matter as much as the first three: they are the proof the sentinel can still fail. A
save-safety guard that has been taught to be quiet about its own mess is one edit away from being quiet
about everything.

**Queue item 6b — the tile-quality worktree, A/B verdict.** Evaluated `fa9cca3` in an isolated worktree
against HEAD. `check_texture` PASS (across 5.1%, down 6.3%, vs the 6.5% ceiling — the 0.2pp margin its
author reported does hold), `check_tells` PASS, `check_room_reads` PASS, `check_dig_hitch` PASS on both.
Captured a clean delve on each and compared crops: it adds **visible horizontal bedding and chunkier value
patches**. That is real, and it is **incremental, not the fix** — the shaft/rock boundary is still soft and
6a is untouched. Recommendation: land it as foundation, do not close 6b on it, do not let it near 6a.

**ANSWERED WITHIN THE STRIKE — a green suite really did contain a red layer, and here is why.** I asked
below how this was possible and then went and measured it instead of leaving it as a question. At commit
`77ba4b4`, the exact commit Strike 5 declared "61/61 ALL PASS":

| how it was run | result |
|---|---|
| `godot --path . --script .../check_dig_hitch.gd` (a window) | **1 FAILURE(S)** |
| `godot --headless --path . --script .../check_dig_hitch.gd` | **PASS** |
| `bash tools/run_harness.sh` | `[18/61] check_dig_hitch PASS` … `ALL 61 HARNESS LAYERS PASS`, **exit 0** |

**This is not the exit-code plumbing.** The runner faithfully reported the exit code it was handed. The
layer returned 0 because its central assertion **could not fail**: under `--headless` the dummy rendering
driver never uploads texture data, so `texture().get_image()` returns a blank surface. Full size —
1048576 bytes, so an emptiness check would not have caught it — but **one distinct byte value**. The layer
compared two blank surfaces, found them byte-identical, and passed. With a window: 115 distinct values, and
a real failure. And `--headless` was the only way the suite ever ran it, because it was registered with
`add` rather than `add_gl` — **the only texture-reading layer in the harness so registered**;
`check_opening`, `check_underground` and `check_water_reads` were already `add_gl`.

So the guard printed PASS for its entire life while the bug it exists to catch was live on main.

**The generalisation, which I think is the real finding: three-state accounting does not fix this.** Item 1
is about a layer that *declines to run* being counted as a pass. This is a layer that ran, asserted, and
whose assertion could not have failed. Both report exit 0; only one is a skip. **A suite cannot infer
"verified" from "returned zero"**, and no amount of PASS/FAIL/SKIP bookkeeping around the outside of a
process recovers what the process never checked. That has to be defended inside each layer.

Fixed here: `check_dig_hitch` re-registered `add_gl`, and it now prints a loud `SKIP:` and declines to
assert byte-identity when `DisplayServer.get_name() == "headless"`, while its extent and cost assertions —
which are headless-safe — still assert for real. When a surface does exist it first proves the comparison
*could* fail (full size, and more than 4 distinct sampled values) before trusting equality. The CI-truth
agent has been sent all of this, including the requirement that a layer which passes with skipped
assertions must not read as a fully-verified pass.

**What I want audited.**
1. **Sweep the other 60 layers for the same disease.** I checked which layers read back textures and found
   only this one misregistered — but "reads a texture" is one shape of unfalsifiable assertion and I only
   looked for that shape. Any assertion that compares two things derived from the same broken source, or
   that measures something the headless driver stubs out, passes vacuously the same way. **This is the
   audit task I would most like done and least trust myself to have done thoroughly**, because I found this
   one by accident and not by looking.
2. **Is `SYNC_BAND = 1` actually sufficient?** I verified the renderer now matches the sim. I did **not**
   verify the sim's own band is wide enough — `_cell_solid` reads eight coarse neighbours, so one ring looks
   right, but I proved that by reading, not by measuring. A second pair of eyes on `_cell_solid`'s true read
   radius would be worth more than my confidence.
3. **Is 3.0 the right per-cell gate?** Measured max 1.28; the injection fired at 3.385. So it catches ~2.5×
   regressions and a 1.5× one slips through. I chose headroom over sensitivity deliberately — the ratio
   rises when the dirty region shrinks, and I did not want a legitimate `REGION_MARGIN` change to turn CI
   red. Argue me down if that trade is wrong.
4. **The blind spot I cannot close with a ratio.** A change that makes *every* bake dearer moves both
   numbers together and the gate does not budge. That is precisely the tile-texture change in 6b. Printing
   µs/cell is a human-readable mitigation, not a gate.

**Where I think I am weakest.** I wrote here that the layer only ever digs *one interior cell, in one
place* — the cleanest possible case, no surface shift, no ore collapse, no multi-cell dirty range — while
the bug I had just fixed lived in the **multi-cell** generalisation (`cmin != cmax`) that the test never
reached. Rather than leave that as a confession I closed it inside the strike: the layer now digs **four
sites** at different depths and columns, the last a genuine multi-cell range, and one reference bake at the
end covers all of them (the sites are spread far enough apart that no dig can repaint — and so accidentally
repair — another's staleness). The sites also now **search downward for real rock** instead of trusting a
fixed depth offset, which had been quietly landing one site in a cave.

What remains genuinely weak, in order:
- **One seed.** Everything above runs on 1337. Same monoculture as queue item 3, different costume.
- **One verb.** Only `mine` is exercised. Placement, boring and tree-fell go through the same
  `_dirty_terrain` → `sync_block` path and none of them are covered.
- **The absolute cost is unguarded.** `SF_DIG_BUDGET_MS` exists and nothing sets it, so in practice only
  the ratio is enforced and the ~1.7 s full bake (item 17) has no gate at all.

### Strike 5 — 2026-08-17 — the harness baseline, and captures that fail closed

**Commits:** `77ba4b4`. **Queue items 0 and 2 done.**

**Item 0 — the suite is green as a suite.** `61/61, exit 0, 156s`, sentinel verified, run unpiped. Then
`SF_HEADLESS=1`: also 61/61 — **and that is the defect, captured**:

```
             with a display        SF_HEADLESS=1 (what CI runs)
check_opening       12s PASS              1s PASS
check_underground    9s PASS              0s PASS
check_water_reads    6s PASS              1s PASS
check_frametime     12s PASS              1s PASS
summary:  ALL 61 HARNESS LAYERS PASS      ALL 61 HARNESS LAYERS PASS
```

Zero seconds is not a test run. That evidence is now in the hands of the queue-item-1 agent.

**Item 2 — captures.** `tools/capture_moments.gd` booted the real input-responsive scene and never
suppressed input or checked what it was photographing. Two fixes, plus a subtlety that cost real time and
is the most useful thing in this entry:

> **Deafening a node before its `_ready()` does nothing.** A `SceneTree` script's `_initialize()` runs
> before the tree is up, so the `_ready()` that `add_child` triggers is **deferred** — and Godot **re-arms**
> unhandled-input delivery for a node whose script defines `_unhandled_input` as part of it. I deafened
> first, injected `E`/`P`, and the modal opened and the game paused exactly as if I had done nothing, with
> `is_processing_unhandled_input()` reading `true`. Deafen after one frame and the injection lands on the
> floor. **The control run — same injection, no deafening — is what makes the other two mean anything**;
> without it "input did nothing" could just have meant my injection was a no-op.

The gate: each moment declares what it may look like (default: no modal, not paused, no title; the Bazaar
moments invert it since an open pack IS their subject), checked before a byte is written, and it re-checks
that the scene is *still* deaf so a future re-arm fails the capture. Refusal exits **1** and leaves the
existing PNG untouched — proven by forcing a contaminated gate and confirming the good file was
byte-identical after. Unknown moment exits **2** instead of saving a boot frame under the typo'd name.
Exit codes verified 1 / 0 / 2. All three canonical moments retaken clean.

**I then looked at the delve, cropped**, which is the point of the whole exercise. The blind tester's
finding is confirmed, but it is **two problems, not one**, and that matters because they have different
fixes:

1. **Outside the lamp radius, rock and void are the same near-black.** The dug shaft and the rock beside
   it are indistinguishable; I could only tell them apart because I knew he had dug down.
2. **Inside the lit pool, the rock has no edges.** It is a soft mottled gradient that reads as fog or
   smoke rather than carved mass. **There is no contact line anywhere where rock meets air.**

Problem 2 is not in the backlog as its own item and it is why "raise the brightness" cannot work — more
light on an edgeless gradient is a brighter edgeless gradient. Split into items 6a/6b below.

**What I want audited:**

- **Is `_deafen` actually airtight, or merely airtight against `Input.parse_input_event`?** I proved it
  against injected key events. A real OS-level event may take a different path into the Viewport — and
  the original contamination came from a real device, not from an injection. **Try to contaminate a
  capture with a real keystroke while one is running.** This is the claim I am least sure of.
- **Is the per-moment `EXPECT` contract complete?** I check modal / paused / settings / help / title, and
  minimap mode for `map`. A moment could still be wrong in ways none of those catch — wrong zoom, body in
  the wrong place, a hint bubble mid-fade. The manifest line prints those but nothing asserts them.
- **Does the `boot` moment need a contract at all?** It has no override, so it gets the default calm one.
  I think that is right; it is also the moment most likely to be captured in a hurry.

**Where I think I am weakest:** I judged the two rock-legibility problems from **one cropped frame of one
seed at one zoom**. That is exactly the single-seed, single-sample reasoning this project has been burned
by. Before anyone acts on 6a/6b, look at more than my one crop.

### Strike 4 — 2026-08-17 — the architecture doc stated the opposite of the architecture

**Commits:** (this one). **Files:** `docs/ARCHITECTURE.md`, `README.md`. Queue item 4 — done by me rather
than an agent, since it is a read-and-verify job and cheaper in my own context.

I went claim by claim rather than trusting the audit's list, and found one it did not name that is worse
than any it did.

| Claim | Verdict | Evidence |
|---|---|---|
| *"Core Principle: Abstract Flow Is Source of Truth — production math runs entirely through the abstract rate-based flow layer, discrete falling items are COSMETIC"* | **FALSE, and inverted** | `_flow` (`factory_sim.gd:2462`) moves discrete integers out of `output_buffer`. `production_rate()` (`:1570`) is a ring buffer of `total_produced` snapshots — derived legibility, never read back. **Items are authoritative; the rate layer is the cosmetic one.** |
| Seal at *"rows 56-57"*, `DESCENT_QUOTA` *"(40)"* | **FALSE** | `SEAL_TOP = 84`, `DESCENT_QUOTA = 64`. Same drift as `PROGRESSION.md`. Now names the constants. |
| *"the few non-recipe machines (currently the splitter)"* | **FALSE** | `_BEHAVIORS` holds **eleven**: lift, splitter, drill, generator, hopper, descent, h_drill, drift, pump, crush, spur. |
| *"`tools/check_settings.gd` = harness layer 13"* | **FALSE** | It is the 23rd of 61. A positional claim that drifts whenever anyone inserts a layer above it. Removed rather than corrected. |
| Scene Tree: *"no child nodes yet (everything is `_draw`n)"* | **FALSE, and self-contradictory** | The Representation section of the **same file** describes MainView hosting a Player, Camera2D, Hud and WorldRenderer. This is the internal contradiction the audit flagged. |
| **The LODE plane** | **ABSENT** | Zero mentions of `lode` in a document titled "the technical source of truth". `sim.lode`/`lode_max`, `take_lode`, `lode_fraction`, the Head, the Spur, the Drift Rig — an entire shipped subsystem, undocumented. Now has its own section, including that phase 3 is **not** done. |
| *"fixed 20 Hz tick"* | TRUE | `TICKS_PER_SECOND = 20`. |
| *`.tres` in `machines/`, `recipes/`* | TRUE | both exist (`materials/` also exists and was unmentioned; added). |

README: added the harness CI badge, a Godot version badge, and an MIT licence badge/section — **LICENSE
exists** (MIT, teohondascully) and was simply never linked. Corrected the desktop-targets claim to say
plainly that `export_presets.cfg` is gitignored and absent, so a clone can run from source but **cannot
reproduce a packaged build**.

**What I want audited:**

- **The inverted core principle is the one to check me on.** I claim items are authoritative and rates are
  derived. If there is a rate-based path I did not find — something in the power or water sweep that
  actually computes in rates — then I have replaced one wrong principle with another, which is worse than
  leaving it alone.
- **Is the new LODE section accurate about the Drift Rig's `flow` hook?** I wrote that it owns one because
  the default round-robin deal is wrong for a machine that sorted pay from spoil at the face. That is my
  reading of `_BEHAVIORS` and the comment above `_flow`, not something I traced end to end.
- **Did I miss stale claims?** I checked every claim I could turn into a command. Claims about *intent*
  ("decouple HOW the world is generated from HOW it is visualised") I left alone because they are design
  statements, not facts — but if any of those have quietly become false, that is exactly the kind of thing
  a second reader catches and the author does not.

**Where I think I am weakest:** README images. Backlog item 13 wants 3–4 hand-picked frames published, and
I did **not** do it — the canonical captures are known-contaminated (`_moment_delve.png` shows the Bazaar
modal and `PAUSED`) and queue item 2 is about to retake them. Publishing a frame from `history/` now would
mean shipping an image I had not verified is current. **Deliberately deferred, not forgotten.**

### Strike 3 — 2026-08-17 — verifying the peer's save work, and a guard nobody could see

**Commits:** (this one). **Files:** `src/core/save_game.gd`, `tools/check_save_durability.gd`.

Nobody had verified `edc350a`/`2df393e` — the peer session wrote them and the audit predates them. All
five save layers pass (`check_save_isolation`, `check_saveload`, `check_save_durability`,
`check_save_frontier`, `test_sim`). More usefully, I did the thing an author cannot do for themselves and
**broke the production code to see whether the guards fire**:

| Break | Result |
|---|---|
| `write` straight to the final path (non-atomic, no backup) | **4 FAILs** — backup, recovery-from-truncation, and untouched-on-failure all fire |
| `restore` skips the seep phase | **2 FAILs** — including *"one file, one future"* |
| Delete the required-key **presence** loop in `_valid_envelope` | **nothing fired** |

That third one is the finding. The presence loop and the type loop under it both reject a missing key, so
the per-key ablation test — a genuinely good test — passes with the presence loop deleted. But the loop is
**not** redundant: without it the type loop indexes `data[key]` on a key that isn't there, and Godot
answers with an engine error per miss. Measured: **2 error lines became 16.** So its real job is to refuse
*cleanly*, and no assertion could see whether it was doing it.

`_valid_envelope` now records **why** it refused (`SaveGame.last_invalid`), and the ablation asserts the
refusal came from the presence gate rather than from an index into a hole. Proven non-vacuous: deleting the
presence loop now fires the new assertion on every key.

**What I want audited:**

- **Is `last_invalid` as a `static var` sound here?** It is process-global mutable state on a class whose
  whole virtue is being node-free and deterministic. I judged it acceptable because it is a pure diagnostic
  written only on the refusal path and read only by tests. **If that reasoning is wrong — particularly for
  concurrent sims, which this codebase constructs freely — I want to hear it.**
- **Are there other guards in the same shape?** A guard whose deletion changes real behaviour but which no
  assertion can distinguish from the guard beside it. I found this one by breaking things at random rather
  than by looking systematically. A deliberate sweep would likely find more.
- **Did I miss a failure mode in the save matrix?** I broke three things. The peer's matrix covers blocked
  writes, truncation, corrupt-primary-and-backup, NONE vs CORRUPT vs RECOVERED, per-key ablation, v1
  migration, future-version refusal, warm/cold phase equivalence, and cross-seed resave. I could not think
  of a fourth break worth trying, which is itself a reason to have someone else look.

**Where I think I am weakest:** I verified by breaking, which proves a guard *can* fire — it does not prove
the guard fires on the failure that will actually happen in the wild. Disk-full, permission-denied, and a
crash *between* the rename and the backup write are all untested by anything, mine included, because they
are hard to induce from GDScript. **That is the honest hole in the save story.**

### Strike 2 — 2026-08-17 — the decision log that never existed

**Commits:** (this one). **Files:** `docs/DECISIONS.md` (new), `docs/PROGRESSION.md`,
`docs/ORCHESTRATOR.md`.

`docs/DECISIONS.md` was cited **seven times** — from `project.godot` (as the rationale for the
`untyped_declaration=2` compile-error tripwire), `scenes/sfx.gd`, `docs/PROGRESSION.md` ×3,
`docs/ARCHITECTURE.md`, and `docs/GDD.md` ×2 — and **had never existed**. Every one of those citations
sent a reader looking for a record that was never written, which reads worse than no citation: it looks
like a decision log somebody deleted.

It now exists, reconstructed **only from what the repo actually attests** — a doc, a code constant,
`project.godot`, or a commit — with each entry naming its source. Nothing was invented to fill a gap;
where a decision was clearly made but its reasoning survives nowhere, the entry says so instead of
guessing. Statuses are explicit: LOCKED / PROVISIONAL / **PROPOSED (not adopted — do not build on it)** /
REOPENED / SUPERSEDED. The lore route and the bore model are both marked PROPOSED, loudly, because the
audit found docs blurring shipped against proposed and that distinction is load-bearing here.

**It immediately earned itself.** Writing the entry for the Seal forced a check of two numbers that
`docs/PROGRESSION.md` had written out longhand: "rows 56-57" and "40 ingots". The real values are
`SEAL_TOP = 84` and `DESCENT_QUOTA = 64`. Both doc numbers had drifted — and the *code* never lied, because
`hover_info.gd` already prints the quota as `% FactorySim.DESCENT_QUOTA`. That is precisely the discipline
`docs/ORCHESTRATOR.md` §5 states as *"a comment that states a number is a test with no runner"*, working in
the code and failing in the doc. `PROGRESSION.md` now names the constants rather than their values.

**What I want audited:**

- **Is anything in `DECISIONS.md` unattested?** I claim every entry traces to a real source in the repo.
  That is exactly the kind of claim an author cannot check on themselves. Please spot-check the citations,
  especially the undated engineering entries (node-free sim, `_BEHAVIORS` by method name, `_grow_vein` as
  the single funnel) — those I assembled from `ORCHESTRATOR.md` §4 rather than from a dated decision.
- **Are any statuses wrong?** I marked the danger model REOPENED-then-subsumed, and combat deferred to L4.
  If the repo says otherwise somewhere I did not read, that is a meaningful error.
- **Are there more drifted numbers of the `40 ingots` kind?** I found that pair by accident while writing
  one entry. A systematic sweep for doc-stated constants that have a real named constant behind them would
  likely find several, and I have not done one.

**Where I think I am weakest:** the design and lore entries. The engineering ones are checkable against
code; the design ones rest on my reading of `GDD.md` / `PROGRESSION.md` / `ORCHESTRATOR.md` and on session
memory, and I may have promoted something to LOCKED that the user considers open. **The lore section in
particular is a vision-level fork that belongs to the user, and if I have made it sound more settled than
it is, that is the error most worth catching.**

### Strike 1 — 2026-08-17 — save safety

Recorded in full in §1–§4 below. Cleared the audit's player-data-safety veto. See also §5 (a second
session working the same checkout) and §6 (agent dispositions).

**What I want audited:** the two guards. `check_save_isolation` is a source scan and therefore blind to a
path assembled at runtime; `save_sentinel` is empirical but only brackets the run. I believe together they
close it. **Try to defeat them** — write a fixture that reaches the production slot without naming it and
see whether either catches you.

**Where I think I am weakest:** the sentinel plants a file at the production slot when none exists. I
argued that is safe (non-envelope bytes, `SaveGame.read` returns `{}`, removed afterwards, and the title
screen is suppressed for `--script` fixtures). If that reasoning is wrong anywhere, it is wrong in a
data-safety guard, which is the worst place for it to be.

---

## 1. The thing you were told not to do, you may now do

The audit's headline instruction was:

> **Do not run `tools/run_harness.sh` locally until `check_saveload.gd` is isolated from the production
> save slot.**

**That is done. The full harness is now safe to run.** It has been run once since, in 153 seconds.

The audit's save-safety veto — the first row of its hard-veto table — is the one veto that has been
**cleared**. Every other veto in that table is untouched and still red or unproven. Do not read this
document as "the audit is handled."

---

## 2. What landed on main

Two code commits from this strike. Both are safety/truth work only; no gameplay, no rendering, no
content. (`edc350a`, described in §5, came from a different session.)

### `a6a681f` — the destructive test path (audit P0 #1)

`tools/check_saveload.gd` booted the real scene, drove `MainView._save_game()` at the real slot
`user://sinkforge.save`, and finished with `DirAccess.remove_absolute(MainView.SAVE_PATH)`. The one
command this project tells every contributor to run therefore overwrote and then **deleted the
developer's actual game**, every single time. The runner's own header promised the opposite — *"layers
write only uniquely-named `user://` files"* — a comment asserting a safety property with nothing behind
it, which is precisely the failure mode `docs/ORCHESTRATOR.md` §5 exists to warn about.

**The fix, and the reasoning behind each half:**

- `MainView.SAVE_PATH` (a `const`) became **`MainView.save_path`, a `static var`**. This is not a new
  idea — `Settings.path` has been an overridable static for exactly this reason for a long time, with
  the comment *"overridable so the harness isolates its file"*. The save slot simply never got the same
  treatment. Three call sites in `scenes/main.gd` follow the rename.
- **The production default is deliberately unchanged.** Moving where players save would have traded one
  data-loss bug for another and silently orphaned any existing save. The guard below asserts this
  explicitly, so nobody can "fix" it that way later.
- `check_saveload.gd` sets `MainView.save_path = "user://check_saveload.save"` **before the scene is
  instantiated**, so no boot-time read can ever see the production default, and it deletes only its own
  file. It also now asserts `FileAccess.file_exists(TEST_SLOT)` — without that, a path override that
  quietly sent the save nowhere would still have passed the whole layer.

**Two guards, because a source scan and an empirical check catch different things:**

| Guard | Kind | What it proves |
|---|---|---|
| `tools/check_save_isolation.gd` | harness layer, first in the list, costs milliseconds | From source: `main.gd` still names the production slot; the slot is overridable; **no file under `tools/` or `tests/` names it**; anything reaching the save verbs redirects them first. |
| `tools/save_sentinel.gd` | **not a layer** — the runner calls it | Empirically: hashes the real slot before the sweep and after. A run that rewrote or deleted it exits **3**, even if all 59 layers passed. |

The layer is cheap on purpose. A safety gate that costs three minutes gets skipped.

`save_sentinel` **never writes an existing save** — it hashes read-only. When no save exists it plants
non-envelope bytes (so the empty case is covered too; a harness that deletes an absent file is
indistinguishable from one that leaves it alone) and removes what it planted. If the hash changed, the
file is **left in place for inspection** rather than cleaned up.

**Both failure modes were proven, not assumed:** arm, delete the slot, verify → exit 1. Arm, rewrite the
slot, verify → exit 1, with both hashes printed.

### `6a0dc8d` — the guard caught its own author

The first full harness run after `a6a681f` came back **58/59**, and the single red was
`check_save_isolation` objecting to `tools/save_sentinel.gd` — which names `user://sinkforge.save` in a
const, because hashing that exact path is its entire purpose. A true positive by the letter of the rule,
twenty minutes after the rule was written, against a file written by the same hand.

The exemption is narrow and **paid for**: `save_sentinel.gd` is skipped by exact path, and in exchange
the layer now reads `run_harness.sh` and holds it to actually invoking the instrument — `arm` *and*
`verify` (an arm with no verify protects nothing) — and to never registering it with `add`/`add_gl`,
since a layer runs inside the parallel sweep where planting a file at the production slot would race all
59 others. Both new assertions were broken on purpose and watched go red.

---

## 3. Findings the audit did not have

1. **A seventh vacuous assertion.** `check_saveload.gd`'s conservation check was written *inside* the
   `for m in sim.machines` loop, so it ran once per machine — and on a world with **no** machines it never
   ran at all. Hoisted. Add this shape to the hunt list: an assertion nested in a loop that may not
   iterate. The audit's list of six is not exhaustive; assume there are more.

2. **The production slot is currently empty and was empty before this session started.** It still cannot
   be determined whether a real player save was destroyed by the audit's own harness run. Going forward
   the sentinel makes this class of loss detectable rather than silent.

3. **`bash tools/run_harness.sh | tail` masks the exit code.** The pipeline reports `tail`'s status, not
   the runner's. This nearly hid the 58/59 above. Run the harness unpiped, or check `${PIPESTATUS[0]}`.

4. The harness is now **59 layers**, not 58. Any doc, comment, or CI claim naming 58 is stale.

---

## 4. Invariants a contributor must now respect

- **Nothing under `tools/` or `tests/` may name `user://sinkforge.save`.** Fixtures use their own
  uniquely-named `user://` file. `tests/test_stress.gd` is the model (`user://test_stress_%d.save`).
- **Anything that reaches `MainView.save_path`, `_save_game()`, or `_load_game()` must assign
  `MainView.save_path` first**, before the scene is instantiated.
- `save_sentinel.gd` stays a runner instrument. Do not register it as a layer.
- These are enforced by `check_save_isolation`, not requested by a comment. That distinction is the whole
  point of the strike.

---

## 5. A SECOND SESSION IS WORKING THIS REPO — read this before you touch main

While this strike was running, a **concurrent interactive session** was editing the same main checkout.
It landed `edc350a` (*"a save you cannot lose — atomic write, backup, transactional restore"*) on top of
my three commits, and at the time of writing it still has **uncommitted work in the main checkout**:
`src/core/save_game.gd`, `tools/run_harness.sh`, and a new untracked `tools/check_save_frontier.gd`.

Consequences, and they are not small:

- **Items 2–5 of the audit's first strike are being done by that session, not by me.** `edc350a`
  carries the atomic write, the backup, the transactional restore, `tools/check_save_durability.gd`,
  and a seed-ownership assertion added to `check_saveload.gd`. Verify it on its own merits — I did not
  write it and have not audited it.
- **Do not run `git add -A` in the main checkout.** You will sweep another session's in-progress work
  into your commit. Add explicit paths only. This document and my commits all obey that rule.
- Two of my three agents were building the *same things* in isolation. I **stopped both** rather than
  let them fight over `save_game.gd`. Their partial work is WIP-committed in their worktrees
  (`68e05d6`, `a691e4e`) — preserved, not endorsed, and probably better re-dispatched than adopted.

## 6. Agent work: one verified deliverable, two stood down

### READY TO LAND — the six invalid assertions (audit P1 #5)

`.claude/worktrees/agent-aabacbb2493625a01`, commit **`a84c049`**. **I independently re-ran all six
layers in that worktree, each alone, and all six pass.** This does not collide with `edc350a` or with
the peer session's dirty files — the six checks are untouched by both.

What it actually fixed, beyond the six named defects:

- `check_loop_health`'s scoring pathology is **confirmed numerically, and it is worse than the audit
  said**. Breaking `try_research` so the arc dies at step 5 of 9 made the OLD code print **99.4/100** —
  *higher than a healthy complete run's 98.7*, because early death divides few frames by full-run par
  and scores as blazing speed. Now the raw diagnostics print first and unconditionally, the completion
  gate runs before a score exists, and an incomplete run publishes `N/A`.
- **Five further assertions the audit missed**, all the same shape: `check_pack_layout`'s
  `total <= cols` checked a clamp against itself; `check_loop_health`'s sampler could die and buy a
  *better* score (99.1 vs 98.7, since every signal is a tally starting at zero); `check_plunge` scored a
  **21.0× "speedup"** from a shaft that never arrived and spent its whole frame budget; `check_plunge`'s
  one-way-door check never confirmed the legs run went down the hole; and `check_wrap` — the file whose
  own docstring is the standard — measured its whip against a `free_spin` baseline that starts at 0.0.
- **Every repaired guard was broken on purpose and watched go red**, thirteen documented break-tests,
  each reverted. No floor was moved. No production file was edited.

**One open finding it surfaced and correctly refused to paper over:** `FRAMES_PER_STEP_PAR` is dead
weight. The clean arc runs 9 steps in 1099 frames against a par of 6300 — **0.17×** — so the pace term
contributes literally nothing and would not bite until the opening got 5.7× slower. **`check_loop_health`
is a three-signal score with one signal switched off.** It wrote the measurement and date into the
constant's comment rather than tightening it, because §5 rule 2 forbids moving a floor before someone has
played the thing. Somebody should derive a real par.

Also flagged unverified: the sampler-liveness bound (`>= frames - 1`) rests on a single 1099/1099
observation — if that line ever flakes, suspect the bound, not the game. And `check_seam`'s crossing
assertion and `check_plunge`'s census run on the default seed only.

### STOOD DOWN — superseded by the peer session

| Worktree | Was building | Status |
|---|---|---|
| `agent-a2462b929fb990025` | save durability, transactional restore, seed ownership, v2 migration | **Stopped.** `edc350a` landed the same work on main. WIP at `68e05d6`. |
| `agent-a3208149952156f39` | conservation frontier derived from `src/data/materials/*.tres`, behaviour `flow` hook, multi-seed worldgen corpus, capture-envelope meta-guard | **Stopped.** The peer session's untracked `check_save_frontier.gd` overlaps. WIP at `a691e4e`. **The multi-seed corpus may NOT be covered by them — check, because it is the hole most likely to be hiding a barren generator.** |

**Whatever lands, the orchestrator must register new layers in `tools/run_harness.sh` by hand** — every
agent was forbidden from touching the runner so they could not collide there. Forget this and the new
guards exist and never run.

## 5-OLD. Original agent dispatch (superseded above, kept for the contracts)

Each is in its own git worktree with a hard file contract, and each was told to run **focused layers
only** (concurrent harness runs make the timing layers red from CPU contention alone — see
`docs/ORCHESTRATOR.md` §7 rule 5). **None of their work has been reviewed or merged. Verify before
merging; do not trust a self-reported green** (§7 rule 4).

| Agent worktree | Task | Owns | Must not touch |
|---|---|---|---|
| `.claude/worktrees/agent-a2462b929fb990025` | **Save durability** (audit P0 #2, P0/P1 #3, P1 #4): atomic write + last-known-good backup + recovery, transactional restore, seed ownership, explicit v1→v2 migration, `_rate_tick`/`_seep_tick` phase semantics | `src/core/save_game.gd`, the save/load/seed region of `scenes/main.gd`, the tick declarations in `factory_sim.gd`, new `tools/check_save_durability.gd`, new `tests/test_save.gd` | the runner, the two new guards, `check_saveload.gd`, `tests/test_sim.gd`, all other layers |
| `.claude/worktrees/agent-aabacbb2493625a01` | **The six invalid assertions** (audit P1 #5) | `check_pack_layout` · `check_mining` · `check_plunge` · `check_loop_health` · `check_seam` · `check_wrap` | everything else, including all production code |
| `.claude/worktrees/agent-a3208149952156f39` | **Canary coverage holes**: derive the conservation frontier from `src/data/materials/*.tres` instead of a hand-written list; the behaviour-registry `flow` hook; a multi-seed worldgen corpus; a meta-guard that every authoritative `FactorySim` field appears in the capture envelope | `tests/test_stress.gd`, `tests/test_worldgen.gd`, new `tools/check_frontier.gd` | `save_game.gd`, `main.gd`, `tests/test_sim.gd` (agent 1 owns all three), the runner |

**Two of them branched from `1d18edf`**, one commit behind the safety fix, so their trees still contained
the save-destroying line. **That line has been disarmed directly in both worktrees** and both agents were
told: do not run the full harness, do not run `check_saveload`, do not re-arm it, and expect that one
disarmed line to show in their diff (discard it at merge — main already has the real fix). Agent 1
branched from `a6a681f` and is on the safe baseline.

**None of the three may register its own layers in `run_harness.sh`** — the contract forbids it precisely
so they cannot collide there. Each was told to report exact layer names and `res://` paths, and the
**orchestrator registers them at merge**. Do not forget this step, or new guards will exist and never run.

Each was asked for a numbered report ending in *"anything you could NOT verify"*, framed as: I re-check
what you flag and do not re-check what you assert. Read that section of each report first.

---

## 7. What is still open from the audit's first strike

The audit's recommended first strike had five items. Item 1 is done. Items 2–5 are what agent 1 is
carrying, and **none of it is verified yet**:

- [x] Inject a per-test save path and add a production-slot sentinel.
- [ ] Atomic save replacement with a last-known-good backup.
- [ ] Transactional restore; fix controller/sim seed ownership.
- [ ] Explicit save v2 migration; same-process vs fresh-process equivalence tests.
- [ ] Repair the save/determinism canary fields touched by that work.

After those land and are independently re-verified, run the full harness **quietly** (no agents running)
and confirm it green before touching anything else. Then the audit's Days 0–7 list continues with:
explicit PASS/FAIL/SKIP accounting so CI stops calling four skipped layers "full", and canonical captures
that fail closed instead of open (`_moment_delve.png` currently shows the Bazaar modal and `PAUSED`).

---

## 8. What has NOT been touched

No worktree from the previous session has been merged, evaluated, or removed. The lode cutover
(`0d9655d`) has **not** been merged and must not be merged on its 98.6/100 — its completion and play
gates are red, exactly as the audit says. No threshold anywhere has been lowered. No capture was retaken.
No user file, screenshot, sprite, note, or save has been deleted or modified.
