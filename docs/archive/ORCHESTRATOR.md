> **ARCHIVED 2026-08-27.** Untracked since the 2026-08-25 pivot. `docs/archive/PIVOT_PLAN_2026-08-25.md`
> §1 scoped this as REWRITE (keep harness commands / non-vacuity philosophy / agent-play-eval model /
> orchestration playbook / hard commit-destruction rules, cut the five-pillars/Seal/lore content and the
> stale session snapshot) — the "Edited 2026-08-25" header below suggests that edit was done, but it was
> never committed. Moved here rather than promoted to the live tree, on the same reasoning as
> `AGENT_PLAY_EVALUATION_PROTOCOL.md`'s header. Kept for provenance.

---

# ORCHESTRATOR HANDOFF — SINKFORGE

> **Edited 2026-08-25** for the run-based pivot: sections specific to persistent-world design were
> removed or marked below. The rest of this document is unchanged and still describes current reality.

You are taking over as **orchestrator and director** of this project. This document is everything that
matters: what the game is, how it is built, how it is verified, the design philosophy that has accreted
over ~40 sessions, the traps that cost days, and how to run a fleet of parallel agents against it.

Read it end to end before doing anything. It is long because the project is dense, and because most of
what is in here was learned by being wrong first.

---

## 1. YOUR ROLE

You are **game engineer AND director**. Not a ticket-taker.

- **Own the vision.** Make implementation decisions. Choose the best option rather than presenting a menu.
- **Reserve questions for true vision-level forks** — what the game *is about*, not how a thing is built.
- **Work in autonomous sprints:** one agreed goal, executed end to end, the user reviews and steers at
  sprint boundaries. The harness is what makes that autonomy safe.
- **Judge by FEEL**, holistically, against the target: *"Factorio × Terraria with gravity."* The user
  evaluates the game the way a player would, not the way a test suite does. A mechanically correct build
  that reads as programmer art gets called "shitty", and that judgement is correct.
- **Never stop.** The standing instruction is that there is always more to do: finish a strike, then take
  the next item off the list. Each strike should be 3–5 real implementations, not one tweak.

### The user's own words, preserved

> *"you aren't making the strikes through enough. each strike should be like 3-5 implementations and
> ideas... you should have an endless amount of tasks to do so just keep executing and never stop"*

> *"this feels 2003 coded"* — on menus that were structurally right but visually dated.

> *"I want the lighting to make ores feel special but not so much so that it's hard to play the game from
> distractions and overstimulation."*

> The repo must be *"organized, readable, industry-standard, impressive from a software perspective if a
> senior staff were to look at the repo."* It is public.

---

## 2. THE GAME

**SINKFORGE** — a 2D side-view game in Godot 4.6.2, pure GDScript, drawn almost entirely in immediate-mode
`_draw` canvas calls rather than sprites.

You are a miner on the surface of a world made of **solid, ore-rich earth**. You dig *into* it — you do not
follow a cave. You carve a base, build an automated factory, and descend through named geological layers,
each with its own physics twist. The tagline on the title card is **"the way is down."**

### The pillars

> _[Section removed 2026-08-25, pivot: the five pillars, the Seal and the seven named depth bands describe
> the persistent-world's fixed progression, which is dead design. See git history for the original text.]_

### Progression thesis — four interlocked axes

Depth / Tools / Factory / Home. A chassis+modules model resists the "restart everything" feeling. One new
rule per layer keeps novelty cheap. The cannon (see §11) is a lighthouse, not a progress bar. **Validate
the loop before adding content.**

---

## 3. RUNNING AND VERIFYING — the command cheat sheet

```bash
# THE HARNESS — every layer, ~3 min. This is the gate. Everything must be green. Do NOT pipe it
# through `tail`: the pipeline reports tail's exit code, not the runner's, and hides a red run.
GODOT=/opt/homebrew/bin/godot bash tools/run_harness.sh

# Reproduce a CI run locally (no display). RUN THIS BEFORE PUSHING — see §9 trap 1.
SF_HEADLESS=1 GODOT=/opt/homebrew/bin/godot bash tools/run_harness.sh

# One layer
/opt/homebrew/bin/godot --headless --path . --script res://tools/check_lode.gd

# A CAPTURE — must run WITHOUT --headless. Writes _moment_<name>.png at repo root (gitignored), 1920x1080.
/opt/homebrew/bin/godot --path . --script res://tools/capture_moments.gd -- <moment>
# moments include: boot, line, delve, drift, pack, refuse, lode, head, adit, chain, stain …
# read tools/capture_moments.gd for the current list

# Inspect a capture — ALWAYS crop before reading; detail is lost when 1920x1080 is scaled down
sips -c <h> <w> --cropOffset <y> <x> in.png --out crop.png && sips -Z 900 crop.png

# CI
gh run list --limit 5
```

**Screen geometry:** one world cell = 32 world px = **48 screen px** at default zoom (1.5× window scale).
The body is held at frame centre **(960, 540)** in a capture. The body is 34 px tall against a 32 px cell,
so **it always occupies 2 rows** — this matters constantly.

**Capture noise floor (hard-won):** two captures of the same build differ by several percent — up to ±8% in
a bad run — purely from animation phase. **Anything under ~5% is not a signal.** To prove a render change
is invisible, use a >0.20-threshold histogram plus a magenta diff map, and bisect behind a temporary env
switch. Never conclude from one number.

---

## 4. THE CODEBASE

~19,000 lines of GDScript. **Godot 4.6.2. TABS for indentation. Warnings-as-errors with
`untyped_declaration=2`** — every declaration needs a type; `:=` inference satisfies it. This is enforced
in `project.godot` as a compile error, not a lint.

```
src/                        THE SIMULATION — node-free, no engine deps, deterministic
  core/
    factory_sim.gd   2663   the authoritative world + the discrete verb API. The god object.
                            Holds: solid, wall, deposits, lode, lode_max, water, fill, machines,
                            inventory, total_produced/consumed. _BEHAVIORS dispatches machine
                            behaviours by METHOD NAME (not Callable — a bound Callable on self
                            would leak a reference cycle per sim).
    layered_world_gen.gd 1089  the real generator: strata, caves, rifts, sinkholes, the seal,
                            aquifers, ore/coal/iron scatter. `_grow_vein` is the SINGLE funnel
                            every ore body in the game is born through.
    heightmap_world_gen.gd 180 the flat tutorial world (the spawn plateau)
    world_data.gd           the gen→sim handshake artifact: blocks, walls, amounts, water, routes
    world_gen.gd            the generator interface
    save_game.gd            capture/restore. ALSO the determinism canary's signature source.
    water_flow.gd / power_flow.gd / flora.gd / fine_terrain.gd
                            extracted algorithms — the pattern for decomposing the god object
    machine_state.gd
  data/
    machine_def.gd, material_def.gd, bit_rules.gd, mining_rules.gd, research_rules.gd
    machines/*.tres  (20)   ADDING CONTENT = A DATA FILE, NOT A CLASS. Load-bearing decision.
    materials/*.tres (16)

scenes/                     REPRESENTATION — everything you can see or hear
  main.gd          2572     MainView: the controller. Input routing, camera, sim advance, the
                            mining/pick subsystem (~600 lines that want extracting), layout
                            constants, _craftable registry.
  world_renderer.gd 3472    terrain bake, lode/stain, machines, water, LIGHTING ENGINE (~560
                            lines that want extracting), aim/preview overlays
  hud.gd           2250     all HUD + the Bazaar screen (one counter, three tabs)
  player.gd         886     the body: movement, collision, slope authority
  visuals.gd        843     THE GLYPH VOCABULARY — every machine/item drawn from code
  fine_terrain.gd   820     the sub-cell mold pass: what makes rock look carved, not tiled
  sfx.gd            687     ALL AUDIO IS SYNTHESISED AT BOOT. No sample assets, no import path.
  terrain_painter.gd, sky_painter.gd, light_layer.gd, particles.gd, falling_items.gd,
  grapple.gd, bazaars.gd, objectives.gd, hints.gd, hover_info.gd, strata.gd, score.gd,
  payouts.gd, settings.gd, controls.gd, art.gd, world_seeder.gd
  *.gdshader        post_fx, rock_grit, heat_haze, erase

tools/            (see §5)  THE HARNESS + dev tooling — count deliberately not written here, per §5
tests/              5       test_base.gd + 4 headless suites
docs/                       ARCHITECTURE, BAZAAR, BITS, DECISIONS (the log — read it before
                            re-litigating anything), DIRECTOR_BRIEF, DIRECTOR_BUS, DRIFT,
                            FEEL_GAP, GDD, HARNESS_LAYERS, LODE, LODE_PLAN, MATERIAL_SPINE,
                            ORCHESTRATOR (this file), PEER_SESSIONS, PRIORITY, PROGRESSION,
                            SANDBOX
                            (was "12 … VIBE_GAP" — that file never existed. Counts for tools/ and docs/
                            removed rather than re-fixed: §5 already rules that "a number in prose is a
                            claim nobody re-checks", and correcting 12→18 while leaving 13 names listed
                            widened the gap instead of closing it.)
assets/sprites/           the authored miner pixel art — 15 frames, HAND-MADE, IRREPLACEABLE
history/                  GITIGNORED archive of ~124 numbered progress screenshots. SACRED.
```

### The architectural seam that actually holds

`FactorySim` is `RefCounted`, node-free, and cannot see a scene tree. `tests/test_base.gd` builds one with
no tree at all. The README's claim — *"you could delete the player entirely and the production numbers
would be identical"* — is architecturally enforced, not aspirational. **Do not put a `get_tree()` in the
sim.** Most codebases that claim this seam have already broken it; this one has not.

---

## 5. THE HARNESS

`tools/run_harness.sh` runs one independent Godot process per layer, in parallel. The COUNT is
deliberately not written down here — it moves every strike, and a number in prose is a claim nobody
re-checks. The runner prints it; that is the only place it is true. This is the project's central
claim about itself and its whole safety model.

**Structure:** `add "name" "res://tools/x.gd"` registers a headless layer; `add_gl` registers one that
judges PIXELS and needs a real window. Exit 0 = pass. Most layers `extends SceneTree`, boot
`scenes/main.tscn`, settle N frames, then assert.

**Rough taxonomy:**
- `tests/test_*.gd` — sim core, stress/invariants, worldgen, power/water. Conservation, determinism,
  save round-trips, seeded fuzz.
- `check_*` **correctness** — lode, head, mining, saveload, registries, controls, settings, bits.
- `check_*` **look** (`add_gl`, real window) — opening, underground, water_reads, frametime; plus
  headless pixel layers reading `FineTerrain._data` on the CPU (grid, texture, tells, room_reads).
- `check_*` **feel/gauges** — agility, stride, grapple, impact, rhythm, pacing, loop_health, teaching.
- `play-tests` — the agent actually plays the game (§6).

### The assertion philosophy — the most important section in this document

**A green harness bought by moving a threshold is worse than a red one**, because it lies for the rest of
the project's life. The rules, all of them learned by violating them:

1. **Guard against the vacuous pass.** An assertion that is trivially true because the fixture never
   created the condition proves nothing. This codebase names the discipline explicitly in a dozen places
   — e.g. `check_lode.gd`: *"'Nothing was destroyed' is trivially true if nothing was swung at"* → so it
   asserts `swung > 0` first. `check_wrap.gd`: *"A check that cannot fail for want of data is not a
   check."* **Every new layer must assert that it actually did the thing.**
2. **Never lower a floor to make a red test green.** Guessing a harness floor before *playing* the thing
   has been wrong every single time it was tried. Fix the code first. A floor may only move if you can
   write down **why the property was never real**.
3. **Thresholds carry their derivations.** Look at `check_texture.gd`: *"The ceiling is calibrated, not
   derived. The rock printed 12.7% across a face … the retune lands at 5.9% … 6.5% is that, plus enough
   room to move a constant without tripping — this number's job is to stop the slide back, not to name a
   target."* Ratchets are dated and cite the measurement. Do this.
4. **Prove a new guard is non-vacuous by breaking the code and watching it go red.** Do this every time.
5. **A comment that states a number or a behaviour is a test with no runner.** Several have gone stale
   and started lying. Either derive the fact (`% DESCENT_QUOTA`) or put it where the harness checks it.

### Known harness defects (audited, unfixed — good first work)

An audit ran this session and confirmed these. Full detail is in the session transcript; the summary:

- `check_pack_layout.gd:105` — `bazaar_row_count() >= 0` is unconditionally true (it's a `.size()`), and
  the toggled `can_craft` has no path to a row *count*. The property the file exists for is unasserted.
- `check_mining.gd:99` — the `if` branch is unreachable by construction (`_effective_aim` can never return
  a LOS-blocked solid), and the `else` re-asserts the filter that already ran.
- `check_plunge.gd:123` — `roped["mines"] == 0` is vacuous; `_ride()` calls nothing that increments it.
- `check_loop_health.gd:130-132` — three assertions are `clampf(x, 0, CAP)` then `x <= CAP`. Unfailable.
- `check_seam.gd:88` — `Seams.at(p,s) == Seams.at(p,s)`. A literal tautology.
- **Coverage holes:** `_seep_tick` and `_rate_tick` are sim phase and are NOT in `SaveGame.capture`, so
  they are invisible to both the save round-trip *and* the determinism canary simultaneously (they share
  one signature source). `_test_behavior_registry` does not check the `flow` hook. Conservation frontiers
  are hand-written item lists that a new item id silently escapes. Worldgen *feel* floors are single-seed
  (1337) — a tweak that leaves 1337 pleasant and 4242 oreless passes everything.

---

## 6. AGENT-PLAYED EVALS — the thing that makes this project unusual

**The pivot that defines how this game is built:** *build playable LOOPS validated by AGENT PLAY-TESTS —
an agent literally plays the real game to a goal via signposts — not isolated systems with micro-goal
tests. A failing play-test IS the spec.*

- **`tools/play_agent.gd`** — a scripted player. It counts friction: `mines`, `places`, `jumps`, `frames`,
  `stuck_frames`. **CORRECTED 2026-08-17: this entry named three verbs that do not exist and made a claim
  about the input path that is false in both halves.** `place`, `research` and `grapple` have zero
  definitions in that file (`grep -c "func grapple"` = 0). The real surface is `do_mine`, `do_build`,
  `wait`, `jump`, `approach`, `mine_cell`, `walk_to_column`, `dig_down_to`, `climb_to_surface`,
  `select_item`, `deposit_selected`, `collect_below`, `craft`, `build_at`, `give`, `nearest_material`.
  And it does **not** exclusively "drive MainView's actual input path, not the sim directly": `give()`
  injects into the pack and `nearest_material()` scans `sim.solid` wholesale, neither of which any player
  can do. **That sentence is the one that would let a reader conclude the blind-evaluation protocol's gate
  6 — "the actor can be given only player-visible information" — is nearly met.** It is not; see
  `docs/handoff/BLIND_EVAL_READINESS.md` §3, which enumerates 56 privileged inputs across 8 categories.
- **`tools/play_tests.gd`** — goal rungs (get ore → forge ingots → research → build the line → automate →
  breach the seal), each with **friction ceilings**. A goal is met only if it completes *and* stays under
  its ceilings. Ceilings are ratcheted down with dated measurements. Note: best-of-3 retries, so the
  number enforced is the best of three, not the typical one.
- **`tools/arc_driver.gd`** — drives a longer session arc for pacing/loop-health scoring.
- **`tools/mock_bazaar.gd`, `tools/capture_moments.gd`, `tools/zoom.gd`, `tools/measure_player.gd`,
  `tools/dead_space.gd`** — fixtures and instruments.

### The three-tier model: Works / Feels / Belongs

- **Works** — the sim is correct (tests, invariants, conservation, determinism).
- **Feels** — gauges: agility, stride, rhythm, impact, pacing, loop health. Numbers for feel.
- **Belongs** — a *coherence* review by a design-lead + lore-lead perspective. Fundamentally a check on
  the builder. Does this thing belong in this game, or is it a good idea from a different game?

### The SEES tier — blind-vision testing (use this constantly)

A **fresh, zero-context vision agent** judges the game **from pixels alone**, as a first-time player, with
**no access to code, docs, or commit messages**. That ignorance IS the instrument — it is the only judge
that does not already know what everything means.

This is the fix for gauges that read the sim and miss visual legibility. Re-run it per representation
slice. **The naive agent is the judge, not "it looks better to me."**

It works. The most recent pass produced the single most valuable finding of the session:

> *"I cannot reliably tell solid rock from empty air, and I want to say that loudly."* … *"It looks like a
> real game that is under-lit and zoomed too far out."* … *"the single fix with the highest return is
> light the rock and pull the camera in."*

…while confirming the UI is already good: *"the depth badge, the objective banner, the layer title cards,
the Bazaar screens — that is shipped-product quality. It would not look out of place in a Steam store
screenshot."*

**Prompt it to stay naive.** Tell it explicitly not to read source, docs, or commits, and to open only
`.png` files. Point it at `history/` (newest numbers last). Demand image filenames and frame regions for
every observation, and demand bluntness.

---

## 7. ORCHESTRATING PARALLEL AGENTS — the playbook

This session ran **12 agents at once**. It works, and it has sharp edges. What was learned:

### The rules

1. **Isolate every code agent in its own git worktree** (`isolation: "worktree"`). Parallel agents on a
   shared tree contaminate each other's harness runs — same `_moment_*.png` at repo root, same temp saves,
   same lockfiles. Worktrees make it clean.
2. **Give every agent a HARD FILE CONTRACT.** Name the files it owns AND enumerate the files it must not
   touch, by path. Tell it: *"if your change needs a file you don't own, STOP and report it instead."*
   Design the split so no two agents share a file. Merging is then trivial.
3. **The orchestrator commits.** Agents commit in their own worktree with the mandated author string, and
   **never push, never merge, never touch the main checkout.** You cherry-pick.
4. **Verify, don't trust.** Agents report green on red harnesses. Re-run anything load-bearing yourself.
   Ask each agent explicitly for *"anything you could not verify"* and tell them you will re-check what
   they flag and will not re-check what they assert — it produces much more honest reports.
5. **WARN ABOUT PERF-GATE FLAKINESS.** With N agents running harnesses concurrently, `check_frametime`,
   `check_agility`, `check_stride`, `check_grapple`, `check_pump`, `check_traverse`, `check_plunge` and
   `play-tests` go red purely from CPU contention. An agent that "fixes" a spurious red will destroy good
   work. Tell every agent: *re-run that single layer alone before believing it.* Correctness layers are
   unaffected by load — those they can trust completely.
6. **Route findings between agents rather than spawning conflicting ones.** When a read-only report lands,
   `SendMessage` its findings to whichever agent already owns those files. Much higher leverage than a new
   agent that will collide.
7. **Read-only report agents are free and safe.** They cannot conflict. Use lots of them.

### The role split that worked

| Kind | Isolation | Examples |
|---|---|---|
| **Build agents** | worktree, commit locally | bazaar UI · tile quality · audio · lighting · particles · glyphs · the miner · a migration |
| **Tech-lead / report agents** | read-only, no edits | harness audit · senior-staff repo review · lore routes · art-direction spec |
| **Blind-vision agent** | read-only, images only | first-timer legibility judgement |

**Tech leads that paid off enormously:**
- *Senior staff repo review* — "review as if deciding whether to trust this codebase." Found that **CI had
  been red for 33 consecutive pushes** and a live rendering bug, in one pass.
- *Harness assertion audit* — "hunt vacuous passes, guessed floors, tautologies, coverage holes." Found six
  confirmed defects including a layer that could not fail.
- *Art-direction spec* — "produce an implementation spec precise enough that an engineer could build it
  without asking a question." Produced a 10-section spec with palette values, contrast ratios and a build
  order.

**Prompt shape that works:** context → hard file contract → the task with 4-6 *candidate* directions
framed as "you are the designer here, pick what actually helps" → the rules (style, harness, concurrency
warning, verify-with-your-eyes, never delete) → commit protocol → a numbered report spec that explicitly
asks what they could NOT verify.

---

## 8. HARD RULES — non-negotiable

### Commits

**No Claude co-author trailer. Ever.** Author must be `teohondascully` only.

```bash
git add -A && git -c user.name="teohondascully" -c user.email="121736842+teohondascully@users.noreply.github.com" commit -q --no-verify -m "..."
git log -1 --format='%an <%ae>'
git log -1 --format='%B' | grep -icE "claude|co-authored|anthropic"   # must print 0
git push -q origin main
```

That grep exits 1 on zero matches and **short-circuits an `&&` chain** — run the push separately.

Commit messages are written in prose, in the house voice: what changed and **why**, including the failure
that motivated it. Read `git log -8` before writing one. Many are titled `feat(x): STRIKE N — …`.

### Never destroy anything the user made

**Never `rm`, `git rm`, or purge any file the user created or curates without explicit per-item
confirmation.** To exclude something from the repo use `.gitignore` or `git rm --cached` — never `rm`.
`history/`, saves, notes, `assets/sprites/`, screenshots are sacred. Files *you* created this session are
yours to delete. This rule exists because 84 of the user's screenshots were once deleted during a refactor.

### Temp files

Use the session scratchpad, never `/tmp`, never the repo.

---

## 9. THE TRAPS — each of these cost real time

**1. CI ≠ local.** `add_gl` layers were handed a window flag on a machine with no window; Godot died in
`main.cpp` before any GDScript ran, so their `DisplayServer.get_name() == "headless"` self-skip could never
fire. CI was red for 33 pushes while the runner's own comment claimed the opposite. Fixed — the display
test now lives in the runner. **`SF_HEADLESS=1` reproduces CI locally. Run it before pushing.**

**2. NEVER put a hole in the spawn plateau's walking surface.** Cost four harness layers at once, **twice,
in two different columns.** That surface is simultaneously the tutorial corridor, the runway
`measure_player` measures run speed on (it places at column 36 and runs **WEST**), and the path
`check_fastforward` walks (**EAST**). One open cell turns a clean run into a fall, and it surfaces as four
*unrelated-looking* red layers: `check_fastforward`, `check_loop_health`, `check_pacing`, `play-tests`.
If those four go red together, **suspect the surface first.** Confirm with `SF_NO_ADIT=1`.

**3. The body is TWO ROWS tall.** A passage that opens one row per column without keeping the row above
open is impassable — and sim-level tests will not catch it, because they only check floor cells.

**4. Silent-fallback registries.** `WorldRenderer._material()` falls back to `earth` on a miss, so a
material missing from the hardcoded list renders as **dirt** with no error. `rich_ore` — the deep treasure
— did exactly that for as long as it existed. `check_material_registry.gd` and
`check_craftable_registry.gd` now guard both lists. **Any new hardcoded registry needs a guard.**

**5. Determinism.** Same seed → identical world. Moving or adding an `rng.randf()` call reshuffles
everything downstream. A documented bug of exactly this kind let iron crest through the seal onto the
pre-breach shelf.

**6. Godot keychain boot hang (macOS).** Every `godot` run can stall at 0% CPU after the banner when
`securityd` is wedged. `sample` the pid to confirm; work around with a gitignored `override.cfg` TLS
bundle.

**7. The mining hitch.** It was the COARSE terrain pass redrawing 64 cells under an opaque fine layer. The
*predicted* SubViewport-tiling fix measured NEUTRAL and was reverted. `surface_row()` scans are hot —
hoist them. Perf, cosmetics and feel co-evolve; you cannot sequence them. **Build the gauges first.**

---

## 10. DESIGN PHILOSOPHY — the accumulated memory

**Presentation is the priority, not more simulation.** The agreed ordering — real art > audio > onboarding
> movement rebuild. **Not** more sim or worldgen. The live list is `docs/PRIORITY.md`; the presentation
audit that the ordering answers is `docs/handoff/VIBE_AUDIT_RESPONSE.md`.
*(Corrected 2026-08-17: this said "pegged in `docs/VIBE_GAP.md`", a file that has never existed. The
ordering itself is a real user decision and stands — only its cited home was fictitious.)*

**Legibility beats spectacle, always.** Every effect must survive the question "does this make the game
harder to read in motion?"

**Menus must read 2026.** *"Shape right ≠ screen shipped."* Elevation, not borders. Defocus the world
behind a modal. A detail plate for the selected thing. Costs as glyphs. **Never a wall of locked rows** —
the future belongs on the research screen.

**Ore does not glow. It answers your lamp.** Emission is reserved. This is load-bearing.

**Reference images are mood, not target.** Don't overfit to Noita or AI images. The real reference is our
own build, screenshotted. Triangulate via negativa. (Done generating images.)

**Premature-commitment aversion.** The user freezes at abstract design forks that might constrain an
unsettled future vision. Prefer provisional, reversible, demand-pull framings. **Dissolve decisions rather
than forcing them.** When you must present a fork, present it with a recommendation and a cheap first
slice that commits to nothing.

**Demand-pull.** Don't unlock a thing before the player has personally felt the problem it solves. The
Spur must not unlock with the drill, or you never feel that a Head covers one cell.

**Don't invent chores.** A Head is never `blocked`: with no shaft under it the ore piles at its feet, like
everything else in this game when it lands. Refusing to run in order to prevent a pile would invent a chore.

**Darkness is the game's word for "you can walk here."** Mining never writes a backing wall, so every
player-dug tunnel is void and reads black. A hand-authored opening that backs itself speaks a dialect the
world does not — and reads as a scuff, not a cave.

---

## 11. LORE — proposed, not canon

> _[Section removed 2026-08-25, pivot: this lore option-space (the bore model, "THE WORKS ARE COLD", the
> seven band names, the Bazaar spawn ruin) was written for the persistent-world's fixed geography, which is
> dead design. See git history for the original text.]_

---

## 12. WHERE THINGS STAND RIGHT NOW

> _[Section removed 2026-08-25, pivot: this was a dated session snapshot (shipped-this-session items, the
> lode migration status, thirteen agent-worktree reports) that no longer reflects reality. See git history
> for the original text.]_

## 13. THE BACKLOG

Ranked by my judgement of value. You are the director; re-rank it.

1. **Light the rock so solid reads as different from empty.** The blind tester could not navigate. This is
   the highest-value change available and it is not subtle. Do not fix it by raising global brightness — an
   earlier blue fog did that and had to be removed. Shape the darkness: an ambient floor that keeps unlit
   *rock* grainy while unlit *air* stays black, or a contact treatment at the rock/air boundary.
2. **Pull the camera in.** *"The character is ~3% of screen height… this alone makes it read as a debug
   view rather than a game camera."* Zoom lives in `main.gd`; it will move movement-gauge numbers, so
   change it deliberately and re-derive the floors with stated reasoning.
3. **Phase 3, the cutover.** The handover is written.
4. ~~**Merge and verify the eight worktrees.**~~ **TRIAGED** — there were thirteen; see
   `docs/handoff/AUDIT_UPDATE.md` Strike 15. Most are to be re-derived, not merged.
5. **Fix the six audited harness defects** in §5, and close the `_seep_tick` / behaviour-`flow` /
   conservation-frontier / single-seed coverage holes.
6. **The Bazaar as a physical object.** A complete 10-section implementation spec was produced this
   session (in the transcript): geometry with an ASCII sketch at cell resolution, palette with contrast
   ratios at both surface light and underground dark, a layering order, an approach read, and a ruin
   variant. Headline finding: **the ruin has no art at all** — `Bazaars.draw()` only iterates *completed*
   frames, so the first Bazaar every player sees is four wood cells wearing the dirt palette, with grass
   growing on it. Also: the awning is at 1.04:1 contrast against the sky (optically invisible as shape),
   and the keeper is *"a lavender bowling pin."*
7. **Machines should look like installed hardware, not UI.** The blind tester: *"SPUR / DRILL / GENERATOR
   are flat pale rectangles with a nameplate — they read as tooltips someone left on."* **DRIFT RIG is the
   exception and is much better** — chassis, bolts, a visible mechanism. Bring the others up to it.
8. **The hotbar has two identical grey icons.** *"Completely indistinguishable… the kind of thing that
   instantly says placeholder."*
9. **The green/red stubs clipped at the top-left corner.** Proven to be world-layer geometry drawn under
   the HUD and clipped by the screen edge, **not** `hud.gd`. Owner: `world_renderer.gd` / `main.gd` /
   `visuals.gd`.
10. **Decompose the three god files** along seams that already exist: a lighting painter and a water
    painter out of `world_renderer.gd`; a `digging.gd` out of `main.gd`; per-behaviour modules out of
    `factory_sim.gd` (the `_BEHAVIORS` registry was designed for exactly this).
11. **`SaveGame.VERSION` has never been bumped** while seven "additive" `.get()` fallbacks quietly do the
    versioning. Two are dangerous: a pre-lode save loads with an empty lode dict against solid ore blocks
    (the split-brain the plan warns about), and `world_seed` defaulting to 0 rebuilds the fine terrain from
    the wrong seed while a comment two lines away promises the opposite. Pre-1.0, no shipped saves — bump
    to 2 and delete the fallbacks.
12. **`docs/ARCHITECTURE.md` has gone stale in checkable ways** and contradicts itself within one file.
    ~~`docs/DECISIONS.md` is referenced 7 times, including from `project.godot`, and does not exist.~~
    **DONE 2026-08-17 — `docs/DECISIONS.md` now exists**, reconstructed from what the repo actually
    attests (every entry cites its source; nothing was invented to fill a gap). `ARCHITECTURE.md` is
    still open. Writing it turned up a stale pair in `PROGRESSION.md` — "rows 56-57" and "40 ingots"
    against a real `SEAL_TOP` of 84 and `DESCENT_QUOTA` of 64 — now replaced by the constant names.
    The code was never wrong: `hover_info.gd` already printed the quota with `% FactorySim.DESCENT_QUOTA`.
13. **README ships zero images** for a game about how things look, has no CI badge and no license line.
    Publish 3–4 hand-picked frames to `docs/img/`.
14. **`tools/check_base.gd`** — 41 of 51 layers re-declare a byte-identical `_check`. `tests/test_base.gd`
    solved this and `tools/` never got the fix. Plus a "how to add a layer" doc; today the honest answer is
    "copy the nearest file and hope."
15. **The lore first slice** (§11) — user decision.
16. `FineTerrain` names **two unrelated classes** (the renderer's baker and the sim's molding module).
    Rename one.
17. Audio follow-ups from the audio agent: occlusion (not just enclosure), the strike ringing the room via
    `hollow`, per-machine voices in the hum, a `check_space` layer.
18. The `docs/SANDBOX.md` contact sheet — a tuning rig. The stain calibration demonstrated the need.
19. Un-settled: which miner sprite is canonical (`miner.png` vs `miner_idle.png`).
20. **The L1 metal is called "Ore" and smelts to "Ingot"** — the biggest naming hole in the build, and the
    cheapest place to plant whatever lore route wins.

---

## 14. FIRST MOVES

1. Read `docs/LODE.md`, `docs/LODE_PLAN.md`, `docs/PRIORITY.md`, `docs/FEEL_GAP.md`, `docs/ARCHITECTURE.md`.
   *(`docs/VIBE_GAP.md` stood in this list and has never existed — see §10.)*
2. Run `GODOT=/opt/homebrew/bin/godot bash tools/run_harness.sh` — unpiped. Confirm every layer green.
3. Run `SF_HEADLESS=1 …` too (CI parity). Check `gh run list --limit 3`.
4. Take a capture and **look at it**. Crop in. Form your own opinion before trusting mine.
5. The worktrees are **triaged** — `docs/handoff/AUDIT_UPDATE.md` Strike 15 has the decision table. Do not
   re-open the merge question from this file; read that one. (There were thirteen, not eight.)
6. Then pick from the backlog and go. Spin up tech leads and build agents early — they are cheap, they
   parallelise well, and the two audits in this session found more real defects in one pass than a week of
   solo work would have.

Do not ask permission to begin.
