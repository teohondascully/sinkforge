# DECISIONS — the log

Seven places in this repo cite this file, including `project.godot`, which names it as the rationale for a
compile-error tripwire. Until now it did not exist. Every one of those citations sent a reader looking for
a document that was never written, which is worse than having no citation at all — it reads as a decision
record that someone deleted.

So this is the reconstruction. **Every entry below is attested somewhere in the repo** — a doc, a code
constant, `project.godot`, or a commit — and each one names its source so you can check it. Nothing here
was invented to fill a gap. Where a decision was clearly made but its reasoning is not recorded anywhere,
the entry says so rather than guessing.

**How to read the status column:**

| Status | Meaning |
|---|---|
| **LOCKED** | Decided, built, and load-bearing. Changing it breaks things on purpose. |
| **PROVISIONAL** | Decided *for now*, deliberately reversible. The working model prefers these (see 2026-06-28). |
| **PROPOSED** | Written down, argued for, **not adopted**. Needs the user. Do not build on it. |
| **REOPENED** | Was settled, has been deliberately re-opened. |
| **SUPERSEDED** | Replaced by a later entry, kept because the reasoning still matters. |

When you make a real decision, add an entry. An undocumented decision gets re-litigated every session, and
this project has already paid that cost more than once.

---

## Engineering

### The sim is node-free, and that seam is enforced — LOCKED

`FactorySim` is `RefCounted`, has no engine dependencies, and cannot see a scene tree. `tests/test_base.gd`
builds one with no tree at all. The README's claim — *"you could delete the player entirely and the
production numbers would be identical"* — is architecturally enforced, not aspirational.

**Do not put a `get_tree()` in the sim.** Most codebases that claim this seam have already broken it; this
one has not, and the only reason it has not is that every contributor has treated the rule as absolute.

*Attested: the architecture handover §4; `src/core/factory_sim.gd`; `tests/test_base.gd`.*

### Adding content is a data file, not a class — LOCKED

A machine is a `.tres` in `src/data/machines/` (20 of them); a material is a `.tres` in
`src/data/materials/` (16). The sim is generic over them. the architecture handover §4 calls this a
"load-bearing decision" and it is: it is why content can be added without touching the sim.

**The known cost, and it has bitten:** registration is still split across several hand-maintained lists —
the renderer, the sim's behaviour table, the craftable registry, save filename construction, and
hand-written test frontiers. `WorldRenderer._material()` falls back to `earth` on a miss, so a material
missing from its list renders as **dirt with no error** — `rich_ore`, the deep treasure, did exactly that
for as long as it existed. `check_material_registry.gd` and `check_craftable_registry.gd` now guard both
lists. **Any new hardcoded registry needs a guard.**

*Attested: the architecture handover §4 and §9 trap 4; `src/data/`; the two registry check layers.*

### 2026-06-27 — the provisional machine model: a thin `behavior` tag, not a type enum — PROVISIONAL

A machine is a named recipe-runner; a source is a recipe with no inputs; and a thin
`behavior: StringName` tag (default empty) lets the few genuinely non-recipe machines — the splitter was
the first — branch inside the sim **without introducing a type enum**. Every def carries a stable
`id: StringName` for save and reference safety.

The reason it is provisional rather than locked: an enum would have forced every future machine to declare
which of N kinds it is, before anyone knew what the kinds were. A tag defers that until the shape of the
content is known.

*Attested: `docs/ARCHITECTURE.md` §"Data Resources", which cites this entry by date.*

### Machine behaviours dispatch by METHOD NAME, not `Callable` — LOCKED

`FactorySim._BEHAVIORS` maps a behaviour tag to a method **name**. This looks like the worse option and is
not: a `Callable` bound to `self` stored on `self` **leaks a reference cycle per sim**, and this project
constructs a lot of sims (every test, every harness layer, every seed in a corpus).

*Attested: the architecture handover §4; `src/core/factory_sim.gd`.*

### Static typing everywhere, enforced as a compile error — LOCKED

`project.godot` sets `gdscript/warnings/untyped_declaration=2`, where 2 means **error**, not warn. Every
declaration needs a type; `:=` inference satisfies it. `project.godot` calls this "Enforcement tripwire #1"
and the phrase is the point — the rule is self-enforcing rather than a style note somebody has to remember
to police in review.

*Attested: `project.godot` `[debug]`.*

### `_grow_vein` is the single funnel every ore body is born through — LOCKED

Every ore body in the game is created through one function in `src/core/layered_world_gen.gd`. This is what
made the lode migration tractable at all: moving ore out of the terrain plane meant changing one funnel,
not auditing every generator site.

*Attested: the architecture handover §4; `src/core/layered_world_gen.gd`.*

### Same seed means an identical world — LOCKED

Moving or adding an `rng.randf()` call reshuffles everything downstream of it. A documented bug of exactly
this kind once let iron crest through the seal onto the pre-breach shelf.

**Consequence for the harness:** every worldgen fixture must use fixed, committed seeds. A randomly-seeded
worldgen check is worse than none.

*Attested: the architecture handover §9 trap 5.*

---

## The harness and how this project trusts itself

### A green harness bought by moving a threshold is worse than a red one — LOCKED

The single most important rule in the project. It has its own long section
(the architecture handover §5); the short form:

1. **Guard against the vacuous pass.** An assertion that is trivially true because the fixture never
   created the condition proves nothing. Assert that the fixture *did the thing* first.
2. **Never lower a floor to make a red test green.** Guessing a harness floor before *playing* the thing
   has been wrong every time it was tried. A floor may only move if you can write down **why the property
   was never real**.
3. **Thresholds carry their derivations** — the measurement, the date, and what the number's job is.
4. **Prove a new guard is non-vacuous by breaking the code and watching it go red.** Every time.
5. **A comment that states a number or a behaviour is a test with no runner.** Either derive the fact
   (`% DESCENT_QUOTA`) or put it where the harness checks it.

Rule 5 is why `hover_info.gd` prints the ingot quota with `% FactorySim.DESCENT_QUOTA` instead of typing
"64". It is also why the entry below exists.

*Attested: the architecture handover §5; `tools/check_lode.gd`, `tools/check_wrap.gd`, `tools/check_texture.gd`
each state the discipline in their own words.*

### Build playable loops validated by agent play-tests, not systems validated by unit tests — LOCKED

`tools/play_agent.gd` exposes the real verbs and drives `MainView`'s actual input path, not the sim
directly. `tools/play_tests.gd` sets goal rungs with **friction ceilings** — a goal is met only if it
completes *and* stays under its ceilings. **A failing play-test IS the spec.**

*Attested: the architecture handover §6; `tools/play_agent.gd`, `tools/play_tests.gd`.*

### The blind-vision tier: a zero-context agent judges from pixels alone — LOCKED

A fresh vision agent with **no access to code, docs, or commit messages** judges the game as a first-time
player. That ignorance IS the instrument — it is the only judge that does not already know what everything
means. It is the fix for gauges that read the sim and miss visual legibility.

It works. Its most recent pass produced the most valuable finding of that session: *"I cannot reliably tell
solid rock from empty air, and I want to say that loudly."*

**The naive agent is the judge, not "it looks better to me."**

*Attested: the architecture handover §6.*

### 2026-08-17 — the harness may never touch the player's save — LOCKED

`tools/check_saveload.gd` drove the real `user://sinkforge.save` through `_save_game()` and then deleted
it, so the one command the project tells every contributor to run destroyed the developer's game every
time. The runner's own header promised the opposite.

`MainView.SAVE_PATH` became `MainView.save_path`, a `static var` — the same treatment `Settings.path`
already had, for the same reason. **The production default was deliberately left unchanged**, because
moving where players save would have traded one data-loss bug for another. Two guards enforce it:
`tools/check_save_isolation.gd` (a source scan, first layer, milliseconds) and `tools/save_sentinel.gd` (a
runner instrument that hashes the real slot before and after the sweep).

*Attested: commits `a6a681f`, `6a0dc8d`; `the audit notes` §2.*

---

## Design

### 2026-06-28 — the progression spine, and the working model that governs it — PROVISIONAL by design

A guided brainstorm resolved the long-open "what is the Sinkforge / tech graph / endgame" question and
unblocked the crafter modules and ore quality, both of which had been waiting on a recipe graph.

The meta-decision matters more than the content: **names, counts, and per-layer twists can change; the
SHAPE is what's locked.** Two sub-systems — **combat feel** and **power mechanics** — were deliberately
left open to get their own brainstorm before being built.

This is the project's general working model, and it exists because the user freezes at abstract design
forks that might constrain an unsettled future vision. **Prefer provisional, reversible, demand-pull
framings. Dissolve decisions rather than forcing them.** When a fork must be presented, present it with a
recommendation and a cheap first slice that commits to nothing.

*Attested: `docs/PROGRESSION.md` header; the working model is in the architecture handover §10.*

### The danger model — "you open the wall" — REOPENED, then subsumed

Your base is **safe by construction**: because you mine through solid earth, carved tunnels have no open
space for anything to spawn into. Danger is **located, not ambient** — it lives in pre-existing caves,
dungeons, and boss arenas you choose to breach. `docs/GDD.md` notes this deliberately **reopened** a
previously-deferred hazards decision.

**Superseded in emphasis by 2026-08-07 below**, which subsumes combat into environmental antagonism and
defers it entirely. The "safe by construction" half is still true and still load-bearing; the
dungeon/boss/arena half is not currently being built.

*Attested: `docs/GDD.md` "The Danger Model (NEW IN v0.2)".*

### 2026-08-07 — the environment is the antagonist — LOCKED

Each layer's iconic physics twist **is** the tension — an aquifer that floods, magma, a hollow. Combat is
subsumed into that and **stays undecided until layer 4**. A design that needs an army of enemies is
fighting the game.

First slice: L3 Aquifer/fluids, chosen because it is reversible.

*Attested: the architecture handover §2 pillar 3; the design-direction memory of the same date.*

### 2026-08-08 — validate the loop before building the campaign — LOCKED

The Sinkforge/cannon is a **lighthouse** — a fixed direction on the horizon that gives every action
meaning — **not a progress bar you watch fill for forty hours.** A charge meter you stare at demoralises;
it makes the other thirty-nine hours feel like waiting. The discharge is a climax you *assemble* in the
final act.

**The corollary is the operative half: prove roughly two hours of real, human, moment-to-moment fun before
building campaign structure.** Content is cheap once the loop is proven; a gorgeous campaign bolted onto an
unfun loop is wasted work.

As of the 2026-08-17 audit, only about **15 minutes** is agent-validated, and *no* human cohort has ever
been observed. That gap is the single largest unknown in the project.

*Attested: `docs/PROGRESSION.md` §10; `the comprehensive audit` "First 2 / 10 / 60 minutes".*

### Dig your factory — the world is solid, caves are punctuation — LOCKED

You dig *into* solid, ore-rich earth. You do not follow a cave. Caves are rare, opt-in danger/reward
pockets — punctuation in rock, not the medium you travel through. **This is the identity; guard it.**

*Attested: the architecture handover §2 pillar 1.*

### Gravity is a mechanic — LOCKED

Mined and produced items physically fall. Machines pour down their own column. Logistics run downhill for
free and uphill at a cost.

*Attested: the architecture handover §2 pillar 2.*

### Demand-pull: never unlock a thing before the player has felt the problem it solves — LOCKED

The Spur must not unlock with the drill, or you never feel that a Head covers one cell.

**Its twin: don't invent chores.** A Head is never `blocked` — with no shaft under it the ore piles at its
feet, like everything else in this game when it lands. Refusing to run in order to prevent a pile would
invent a chore.

*Attested: the architecture handover §10.*

### Ore does not glow. It answers your lamp. — LOCKED

Emission is reserved. The user's framing: *"I want the lighting to make ores feel special but not so much
so that it's hard to play the game from distractions and overstimulation."*

*Attested: the architecture handover §10 and §1.*

### Darkness is the game's word for "you can walk here" — LOCKED

Mining never writes a backing wall, so every player-dug tunnel is void and reads black. A hand-authored
opening that backs itself speaks a dialect the world does not — and reads as a scuff, not a cave.

*Attested: the architecture handover §10.*

### The lode migration: terrain is what you CARVE, the lode is what you EXTRACT — LOCKED

Ore moves out of the terrain plane into a background lode plane. The old model made a vein *be* the rock,
so a tunnel driven through an ore body destroyed everything it did not pocket.

**User decision locked: Option A — no solid ore survives the cutover.** That remains the target and is not
reopened here. Deletion of the solid-ore code path is deliberately split into a **separate later commit**:
bisectable beats bundled.

> **CORRECTED 2026-08-17 — this passage previously asserted "nothing generates solid ore any more, so the
> old path is simply unreached in the meantime". That is the PHASE-3b POSTCONDITION, not current runtime.**
> `LayeredWorldGen` still scatters solid `ore` / `coal` / `iron` / `rich_ore` into `world.blocks`, and
> `_seed_lodes` runs **dead last and is purely additive** — it writes `world.lodes` and never touches
> `world.blocks`. That additivity is exactly why 3a could ship without disturbing the economy, so the old
> claim contradicted the shipped design as well as the runtime.
> **Why this one mattered more than a stale sentence:** it supplied the *reason* the deletion could be
> safely deferred. A false premise carrying a deferral decision outlives its own correction, because the
> decision it justified stays in force after the premise stops being true. The split is still right — for
> the bisectability reason alone, which does not depend on the false half.

Phases 1, 2, 2b and part of 4 have shipped. **Phase 3 was later split: 3a (generated lode plane) shipped
2026-08-17 in `303d1f5` + `8498ae3`; 3b (converting the solid ore blocks) is not done.** As of the
2026-08-17 audit the *cutover branch's* completion, pacing, and deep-pocket play gates are red. It must not
be merged on the strength of the 98.6/100 its own scorer prints — that instruction is unaffected by 3a.

*Attested: `docs/LODE.md`, `docs/LODE_PLAN.md`, `the cutover handover`;
the architecture handover §12.*

### Presentation is the priority, not more simulation — LOCKED

The agreed ordering: **real art > audio > onboarding > movement rebuild.** Not more sim, not more worldgen.
The user judges the game the way a player would, holistically, against *"Factorio × Terraria with
gravity"*; a mechanically correct build that reads as programmer art gets called "shitty", and that
judgement is correct.

**Legibility beats spectacle, always.** Every effect must survive the question *"does this make the game
harder to read in motion?"*

**Menus must read 2026.** *"This feels 2003 coded"* — on menus that were structurally right and visually
dated. Elevation, not borders. Defocus the world behind a modal. A detail plate for the selected thing.
Costs as glyphs. **Never a wall of locked rows** — the future belongs on the research screen.

*Attested: the architecture handover §10; `docs/PRIORITY.md`; `the vibe audit response`.*

> **Attestation repaired 2026-08-17.** This line cited `docs/VIBE_GAP.md`, **a file that has
> never existed** — no add, no contents, no deletion, in reachable or unreachable history. **The decision
> itself is real and is not reopened:** the user has stated and restated it, and the ordering is quoted
> consistently across the repo. What was fictitious was its evidence.
>
> **A DATE THAT WAS IN THIS NOTE HAS BEEN REMOVED, and the removal is the point.** It said the decision was
> made on 2026-06-28. **No artifact in this repository records that.** `git log -S` on both "Presentation is
> the priority" and "real art > audio > onboarding" puts their first appearance at **2026-08-16**; the
> section heading is undated, unlike its dated neighbours; and the only 2026-06-28 entry in this log is a
> different decision. What *is* on that day is a `VIBE_GAP #3 / #8` provenance tag in four commit subjects
> — circumstantial, and not the same thing. **I asserted a specific date for a specific decision, from
> memory, inside a note whose entire subject is attestations pointing at things that are not there.**
> Note the artifacts now cited are *later* than the decision —
> `VIBE_AUDIT_RESPONSE.md` is the 2026-08-17 audit — so they corroborate the ordering rather than record
> its origin, and no document written at the time survives. Said plainly rather than papered over, because
> an attestation pointing at a substitute is how this got here.

### 2026-08-16 — default zoom 0.70× → 1.00× — LOCKED, with its derivation

At 0.70× the field was 57×32 cells, putting the miner at well under one percent of the frame's width — the
measured floor under *"it's hard to see the character at base zoom"*. Every code lever for his presence
(cool two-tone rim, head-lamp, guide ring) had already been pulled and the blind judges still found him via
the marker rather than the sprite, because at that size **there is no sprite left to find.**

1.00× shows 40×22 cells — still wider than Terraria's in tile terms — and buys back 43% of linear size on
everything. Nothing was taken away: the old default survives one step out.

This entry is here as the model for what a design decision record should look like. The reasoning lives in
`scenes/main.gd` beside the constant, where someone changing it will actually read it.

*Attested: `scenes/main.gd` `ZOOM_LEVELS`, tagged #A4.*

### Reference images are mood, not target — LOCKED

Don't overfit to Noita or to assistant-generated images. The real reference is our own build, screenshotted.
Triangulate via negativa. (Done generating images.)

*Attested: the architecture handover §10.*

---

## Lore

### "The Works Are Cold" — PROPOSED. NOT CANON. Do not build on it.

There is **no narrative text in the game.** The entire fiction on screen is the title card
(`SINKFORGE / the way is down`), seven band names, "The Seal", "the Bazaar", and "Stonereach".

The recommended route — endorsed in the earlier plan, **not yet adopted by the user** — is that
the Sinkforge is a foundry sunk through the crust, cold for a century, and you are relighting it. Its
arguments: the game's *title* is the premise; the first machine you build (a Forge) and the last (the
Sinkforge) are the same machine at two scales; the `FORGED` counter has been in the HUD corner all along
meaning nothing; and the finale is a throughput crescendo rather than a shot fired *upward*, which would
reverse "the way is down".

The **bore model** — a shaft bored through the crust, each layer hosting one system sited by its own
geology, your factory becoming the missing crew — is likewise **proposed, not canon**.

Two pieces of lore are already shipped **as art**, which is why this is worth resolving: a colossus on the
horizon (`SkyPainter._sinkforge()`) — a broken cog-ring on a dead pylon, titanic chains, an ember breathing
in the hub, *"dormant, not extinct"* — and a ruin at spawn (cols 40–43), an almost-complete bazaar frame
one block short, whose generator comment calls it *"the first lore ('someone was here')"*.

**This is a vision-level fork and belongs to the user.** The cheapest first slice, which commits to
nothing and is identical for the runner-up route: give `scenes/strata.gd` a third field, one clause of
found signage per band in the hint table's voice, drawn under the band name on the arrival plate.

*Attested: the architecture handover §11; `scenes/sky_painter.gd`; `src/core/layered_world_gen.gd`.*

---

## Process

### Commits carry no Assistant/Vendor/co-author trailer, ever — LOCKED

Author is `teohondascully` only. Messages are prose, in the house voice: what changed and **why**,
including the failure that motivated it.

**Enforced, as of 2026-08-17, because for months it was not.** The rule was LOCKED here and 23 pushed
commits carried the trailer anyway — written by tooling that adds one by default, neither of
which noticed. A rule that lives only in a document is enforced by whoever last read the document.

Three layers, because the first two are each individually escapable:

- `.githooks/commit-msg` refuses the ordinary path. **Tracked**, not in `.git/hooks/` — an untracked hook
  reaches no clone, no worktree and no other session, so it guards the one machine where it was installed
  and is absent everywhere the rule actually gets broken. Activate with `git config core.hooksPath .githooks`.
- `tools/check_trailers.sh` in the harness. This is the real enforcement: all commits land with
  `--no-verify` by habit, which is exactly the flag that skips the hook, and no flag skips the suite. It
  scans **every ref**, not just the current branch, because thirteen worktrees exist and a stale branch
  brings the trailer straight back on merge. It asserts `core.hooksPath` is wired, so the guard's job
  includes checking the guard is installed. It carries a positive control that runs every time, because
  every other assertion in it is a search that found nothing, and a detector that quietly stopped matching
  reports a clean history in precisely the words a clean history produces.
- Neither session uses `--no-verify` any more.

**The 23 historical commits were rewritten**, at the user's explicit instruction on 2026-08-17, superseding
the earlier written recommendation to grandfather them. Trees are byte-identical; only messages changed.
The pre-rewrite history is kept whole at `pre-trailer-strip` — locally as a tag, on origin as
`refs/backup/pre-trailer-strip` — and `the trailer-strip map` records every old SHA against its
new one. Nothing was deleted and the strip is reversible. That backup ref is the single named exemption in
the scanner, and the scanner asserts it is the only one.

*Attested: the architecture handover §8.*

### Never destroy anything the user made — LOCKED

Never `rm`, `git rm`, or purge any file the user created or curates without explicit per-item
confirmation. To exclude something from the repo use `.gitignore` or `git rm --cached` — **never `rm`**.
`history/` (the curated screenshot archive), saves, notes, and `assets/sprites/` (hand-authored art) are
sacred.

**This rule exists because 84 of the user's screenshots were once deleted during a refactor.**

*Attested: the architecture handover §8.*

### The visual record is committed, not merely kept

`history/` and the 51 canonical `_moment_*.png` captures are tracked in git, at the user's instruction on
2026-08-17. Until then both were ignored, `history/` under a `.gitignore` note reading *"keep on disk,
NEVER publish or delete"* — one line asserting two rules that have nothing to do with each other. Only the
**delete** half was ever a decision (the LOCKED rule directly above); the **publish** half was never
recorded or argued anywhere, and it was the half doing the damage, because an ignored file has no undo. A
capture overwritten in place was simply gone.

Committing serves the locked rule instead of straining against it: it is the strongest available form of
not destroying these files. And the disclosure worry the word "publish" implies does not survive being
stated — the repo is the user's own MIT-licensed game, and these are pictures of it.

The premise under the old note was wrong too. These captures are not regenerable. Re-running the capture
instrument (`tools/capture_moments.gd`) does not reproduce them, because the game it photographs has
changed; each one is a record of a world that no longer exists. That is the argument for versioning them
rather than against it.

> *(Corrected 2026-08-17: this sentence named `tools/sees.sh`, which has never existed in this repository —
> zero tree entries, reachable or unreachable. The real instrument is `tools/capture_moments.gd`, whose own
> header calls itself "The 'Sees' blind-vision instrument's renderer". A phantom tool was carrying the
> load-bearing premise of a LOCKED decision, 120 lines below the note that repairs the same defect in a
> different attestation.)*

**Cost, recorded because git history is permanent:** ~237MB (`history/` 171MB, moments 66MB) onto a 53MB
`.git`. There is no lossless win to take first — they are 8-bit RGB PNGs at 1920x1080, already near 3:1 —
and lossy compression is barred outright, because the harness *samples these pixels* (`check_rock_reads`
and its neighbours read values off them). Quantizing would corrupt the evidence rather than merely soften
the picture. A full recapture adds ~66MB; git stores per file, so a partial one costs only what moved.

**`history/.gdignore` keeps the archive out of Godot's resource scanner**, and it is not an optimization —
CI runs `godot --headless --import` from a clean clone in *both* jobs with no cache, so every tracked image
gets imported twice per push. Nothing anywhere references the archive, so that would have been 171MB of
pure CI time bought for nothing. Its `.png.import` sidecars are untracked for the same reason (left on
disk, per the rule above — untracking and deleting are different operations). The 44 moments stay visible
to the scanner, because `tools/` addresses them by `res://` path; `save_png` and `Image.load` read the file
rather than the imported resource, but the path still has to resolve.

*Attested: `.gitignore`, "THE VISUAL RECORD".*

### Isolate parallel work in its own worktree; one integrator commits — LOCKED

Parallel agents on a shared tree contaminate each other's harness runs — same `_moment_*.png` at repo root,
same temp saves, same lockfiles. Every agent gets a **hard file contract** naming what it owns *and* what
it must not touch, and is told: *if your change needs a file you don't own, STOP and report it.*

**Verify, don't trust.** Agents report green on red harnesses. Ask each explicitly for *"anything you could
not verify"*, and tell them you will re-check what they flag and will not re-check what they assert — it
produces markedly more honest reports.

**Warn every agent about perf-gate flakiness:** with N harnesses running concurrently,
`check_frametime`, `check_agility`, `check_stride`, `check_grapple`, `check_pump`, `check_traverse`,
`check_plunge` and `play-tests` go red purely from CPU contention. An agent that "fixes" a spurious red will
destroy good work.

*Attested: the architecture handover §7.*

---

## Measurements worth not re-deriving

Not decisions, but hard-won numbers that a future session would otherwise pay for again.

- **The capture noise floor.** Two captures of the same build differ by several percent — up to ±8% —
  purely from animation phase. **Anything under ~5% is not a signal.** To prove a render change is
  invisible, use a >0.20-threshold histogram plus a magenta diff map, and bisect behind a temporary env
  switch. Never conclude from one number.
- **The mining hitch was the coarse terrain pass** redrawing 64 cells under an opaque fine layer. The
  *predicted* SubViewport-tiling fix measured **NEUTRAL and was reverted** — a good record of a plausible
  optimisation that was simply wrong. `surface_row()` scans are hot; hoist them.
- **Roughness terms add in quadrature, not linearly.** Ablate, don't derive. Three sines summing to a
  nominal ±1 have RMS ≈ 0.42 and never reach their extremes, so a threshold aimed at ±1 fires at a fifth
  strength forever.
- **The body is two rows tall** (34 px against a 32 px cell). A passage that opens one row per column
  without keeping the row above open is impassable — and sim-level tests will not catch it, because they
  only check floor cells.
- **Never put a hole in the spawn plateau's walking surface.** It cost four harness layers at once,
  **twice, in two different columns.** That surface is simultaneously the tutorial corridor, the runway
  `measure_player` runs WEST on from column 36, and the path `check_fastforward` walks EAST. It surfaces as
  four *unrelated-looking* red layers: `check_fastforward`, `check_loop_health`, `check_pacing`,
  `play-tests`. **If those four go red together, suspect the surface first.**

*Attested: the architecture handover §3 and §9.*
