# Decisions

An architecture decision record for Sinkforge. Each entry states a decision, why it was made, and where in
the repository you can check it. Entries that record a design intention with no artefact behind it say so
rather than inventing evidence.

It is cited by name from `project.godot`, which calls it the rationale for a compile-error tripwire, and
from `README.md`, `.gitignore`, `.githooks/commit-msg`, `tools/check_trailers.sh`,
`tools/capture_moments.gd`, `docs/ARCHITECTURE.md` and
`.github/workflows/harness.yml`.

## Status taxonomy

| Status | Meaning |
|---|---|
| LOCKED | Decided, built, and load-bearing. Changing it breaks things on purpose. |
| PROVISIONAL | Decided for now, deliberately reversible. |
| PROPOSED | Written down and argued for, but not adopted. Nothing should be built on it. |
| REOPENED | Was settled, has been deliberately re-opened. |
| SUPERSEDED | Replaced by a later entry, kept because the reasoning still matters. |

---

## Engineering

### The sim is node-free, and the seam is enforced (LOCKED)

`FactorySim` is a `RefCounted`. It has no engine dependencies and cannot see a scene tree.
`tests/test_base.gd` constructs one with no tree at all, which is what makes the seam checkable rather
than aspirational: the production numbers do not depend on the player existing.

No `get_tree()` belongs in the sim. The rule holds only because it has been treated as absolute.

*Attested: `src/core/factory_sim.gd`; `tests/test_base.gd`.*

### Adding content is a data file, not a class (LOCKED)

A machine is a `.tres` in `src/data/machines/` (20 of them). A material is a `.tres` in
`src/data/materials/` (16). The sim is generic over both, which is why content can be added without
touching it.

The known cost is registration. Several hand-maintained lists still have to agree with the data
directory: the renderer's material table, the sim's behaviour table, the craftable registry, save
filename construction, and hand-written test frontiers. `WorldRenderer._material()` resolves an unknown
id to `earth`, so a material missing from its list renders as dirt with no error at all. `rich_ore`, the
deep treasure, did exactly that for as long as it existed. Two harness layers now guard both lists, and
any new hardcoded registry needs its own.

*Attested: `src/data/machines/`, `src/data/materials/`; `scenes/world_renderer.gd` `_material()`;
`tools/check_material_registry.gd`, `tools/check_craftable_registry.gd`.*

### 2026-06-27: the machine model is a thin `behavior` tag, not a type enum (PROVISIONAL)

A machine is a named recipe-runner, and a source is a recipe with no inputs. A thin
`behavior: StringName` tag (empty by default) lets the few genuinely non-recipe machines branch inside
the sim without a type enum. The splitter was the first of them. Every def carries a stable
`id: StringName` for save and reference safety.

It is provisional rather than locked because an enum would have forced every future machine to declare
which of N kinds it is before anyone knew what the kinds were. A tag defers that until the shape of the
content is known.

*Attested: `docs/ARCHITECTURE.md` "Data Resources", which cites this entry by date;
`src/core/factory_sim.gd`.*

### Machine behaviours dispatch by method name, not by `Callable` (LOCKED)

`FactorySim._BEHAVIORS` maps a behaviour tag to a method name. A `Callable` bound to `self` and stored on
`self` leaks a reference cycle per sim, and this project constructs a great many sims: one per test, one
per harness layer, one per seed in a corpus.

*Attested: `src/core/factory_sim.gd` `_BEHAVIORS`.*

### Static typing everywhere, enforced as a compile error (LOCKED)

`project.godot` sets `gdscript/warnings/untyped_declaration=2`, where 2 means error rather than warning.
Every declaration needs a type; `:=` inference satisfies it. `project.godot` calls this "Enforcement
tripwire #1", and self-enforcement is what the entry is for. A style note somebody has to remember to
police in review is not the same instrument.

*Attested: `project.godot`, `[debug]`.*

### `_grow_vein` is the single funnel every ore body is born through (LOCKED)

Every ore body in the game is created through one function in `src/core/layered_world_gen.gd`. That is
what made the lode migration tractable: moving ore out of the terrain plane meant changing one funnel
rather than every generator site.

*Attested: `src/core/layered_world_gen.gd` `_grow_vein`.*

### Same seed means an identical world (LOCKED)

Moving or adding an `rng.randf()` call reshuffles everything downstream of it. `_grow_vein` carries a
`min_row` floor for exactly this reason: a body seeded just under the seal could otherwise climb through
rows the seal stamp later re-fills and leave its crest above them, which is how iron once reached the
pre-breach shelf.

The consequence for the harness is that every worldgen fixture uses fixed, committed seeds. A
randomly-seeded worldgen check is worse than none. `MainView.WORLD_SEED` is 1337 and
`MainView.default_seed()` routes the `SF_SEED` override, so a seed corpus re-runs the real layers at
their real floors on other worlds instead of re-implementing the measurements somewhere they can drift.

*Attested: `src/core/layered_world_gen.gd` `_grow_vein`; `scenes/main.gd` `WORLD_SEED`, `default_seed()`;
`tests/test_worldgen.gd`.*

---

## The harness

### A green harness bought by moving a threshold is worse than a red one (LOCKED)

The most important rule in the project.

1. Guard against the vacuous pass. An assertion that is trivially true because the fixture never created
   the condition proves nothing. Assert that the fixture did the thing first.
2. Never lower a floor to make a red test green. A floor may only move when the reason the property was
   never real can be written down.
3. Thresholds carry their derivations: the measurement, the date, and what the number is for.
4. Prove a new guard is non-vacuous by breaking the code and watching it go red.
5. A comment that states a number or a behaviour is a test with no runner. Either derive the fact from
   the constant or put it where the harness checks it.

Rule 5 is why `hover_info.gd` prints the ingot quota with `% FactorySim.DESCENT_QUOTA` instead of typing
"64".

*Attested: `scenes/hover_info.gd`; `tools/check_lode.gd`, `tools/check_wrap.gd`, `tools/check_texture.gd`,
each of which states the discipline in its own words.*

### Build playable loops, validated by play-tests against the real input path (LOCKED)

`tools/play_agent.gd` drives the real `Player` body with real platformer physics and triggers the real,
reach-gated verbs on `MainView` (`try_mine`, `try_build`, `try_drop`, `try_craft`, `select`), which is
the same surface a person drives with mouse and keys. Nothing in it reaches past the verb layer to fake a
result, so a passing play-test means a person could actually do the thing.

`tools/play_tests.gd` sets goal rungs with friction ceilings: a goal is met only if it completes and
stays under its ceilings. A failing play-test is the spec.

*Attested: `tools/play_agent.gd`, `tools/play_tests.gd`.*

### Presentation is judged blind, from pixels (LOCKED)

`tools/capture_moments.gd` renders the game's canonical moments so legibility can be judged from the
frame by a reviewer with no access to the code, the docs, or the commit messages. That ignorance is the
instrument. It is the only judge that does not already know what everything on screen means, and it is
the fix for gauges that read the sim correctly and miss whether the screen is readable.

`SF_MOMENT_DIR` redirects the write and changes nothing else, so a baseline can be archived without a
canonical capture being touched. It fails closed: an unusable directory refuses the capture rather than
falling back to the repository root.

*Attested: `tools/capture_moments.gd`; the canonical `_moment_*.png` at the repository root.*

### 2026-08-17: the harness may never touch the player's save (LOCKED)

`tools/check_saveload.gd` drove the real `user://sinkforge.save` through `_save_game()` and then deleted
it, so the one command every contributor is told to run destroyed the developer's game each time. The
runner's own header promised the opposite.

`MainView.SAVE_PATH` became `MainView.save_path`, a `static var`, the same treatment `Settings.path`
already had. The production default was deliberately left unchanged, because moving where players save
would have traded one data-loss bug for another. Two guards enforce it: `tools/check_save_isolation.gd`,
a source scan that runs first and costs milliseconds, and `tools/save_sentinel.gd`, a runner instrument
that hashes the real slot before and after the sweep.

*Attested: commits `a6a681f`, `6a0dc8d`; `scenes/main.gd` `save_path`;
`tools/check_save_isolation.gd`, `tools/save_sentinel.gd`.*

### A layer that measures time runs alone (LOCKED)

`tools/run_harness.sh` registers layers with `add`, `add_gl` (needs a real GL surface) or `add_excl`
(needs the box to itself). A timing layer measures the machine, not the directory, so running it
alongside others inverts its margins and it goes red for reasons that have nothing to do with the code.
`check_frametime` and `check_dig_hitch` are registered `add_excl` for that reason.

`add_excl` is not only for timing claims. `check_grapple_reads` went red on two sweeps of four and green
on every isolated run, and it is registered exclusive too. That removes the condition rather than the
cause, which the runner says out loud where it registers the layer.

*Attested: `tools/run_harness.sh` (`add_excl` and its registrations).*

---

## Design

### 2026-06-28: the progression spine, and the working model that governs it (PROVISIONAL by design)

A guided design pass resolved the long-open question of what the Sinkforge, the tech graph and the
endgame are, and unblocked the crafter modules and ore quality, both of which had been waiting on a
recipe graph.

The meta-decision matters more than the content. Names, counts, and per-layer twists can change; the
shape is what is locked. Two sub-systems, combat feel and power mechanics, were deliberately left open to
be designed separately before being built.

This is the project's general working model. Prefer provisional, reversible, demand-pull framings, and
dissolve a decision rather than forcing it. When a fork has to be presented, present it with a
recommendation and a cheap first slice that commits to nothing.

*Attested: `docs/PROGRESSION.md` header, which cites this entry by date.*

**SUPERSEDED (content only) by the 2026-08-25 pivot.** The specific progression spine this entry
resolved — the Sinkforge as a fed endgame, a tech graph, crafter modules waiting on a recipe graph — is
persistent-world content and is dead; see `docs/GDD.md` §9 ("the Sinkforge as a continuous consumer",
"persistent-world progression... the research tree as a menu... the descent gate as a one-time toll").
The *meta*-decision — the paragraph above this note — is not superseded and still governs how design
work happens here: prefer provisional, reversible, demand-pull framings over forcing a decision. Recorded
as a content-only supersession rather than archiving the whole entry, per this file's own convention,
because the reasoning about *how to decide* still matters even though *what was decided* does not.

### The danger model: you open the wall (REOPENED, then subsumed)

The base is safe by construction. Because you mine through solid earth, a carved tunnel has no open space
for anything to spawn into. Danger is located rather than ambient: it lives in pre-existing caves,
dungeons and boss arenas you choose to breach. `docs/GDD.md` records this as deliberately reopening a
previously-deferred hazards decision.

Superseded in emphasis by the 2026-08-07 entry below, which subsumes combat into environmental
antagonism and defers it. The safe-by-construction half is still true and still load-bearing. The
dungeon, boss and arena half is not currently being built.

*Attested: `docs/GDD.md`, "The Danger Model".*

### 2026-08-07: the environment is the antagonist (LOCKED)

Each layer's iconic physics twist is the tension: an aquifer that floods, magma, a hollow. Combat is
subsumed into that and stays undecided until layer 4. A design that needs an army of enemies is fighting
the game.

The first slice was the L3 aquifer and its fluids, chosen because it is reversible.

*Attested: `docs/PROGRESSION.md` layer ladder; `src/core/water_flow.gd`; `tools/check_water_move.gd`,
`tools/check_water_reads.gd`, `tools/check_pump.gd`.*

### 2026-08-08: validate the loop before building the campaign (LOCKED)

The Sinkforge is a lighthouse: a fixed direction on the horizon that gives every action meaning. It is
not a progress bar you watch fill for forty hours. A charge meter you stare at demoralises, because it
makes the other thirty-nine hours feel like waiting. The discharge is a climax you assemble in the final
act.

The corollary is the operative half. Prove roughly two hours of real, moment-to-moment fun before
building campaign structure. Content is cheap once the loop is proven, and a gorgeous campaign bolted
onto an unfun loop is wasted work.

What is actually measured today is much less than that. `tools/play_tests.gd` covers the opening arc up
to first automation and a handful of friction goals below it. No human cohort has been observed at all,
and that gap is the largest unknown in the project.

*Attested: `docs/PROGRESSION.md` §10; `tools/play_tests.gd`.*

### Dig your factory: the world is solid, caves are punctuation (LOCKED)

You dig into solid, ore-rich earth. You do not follow a cave. Caves are rare, opt-in danger and reward
pockets, punctuation in rock rather than the medium you travel through. This is the identity of the game
and it needs guarding.

*Attested: `docs/GDD.md`; `src/core/layered_world_gen.gd`.*

### Gravity is a mechanic (LOCKED)

Mined and produced items physically fall. Machines pour down their own column. Logistics run downhill for
free and uphill at a cost.

*Attested: `docs/GDD.md`; `scenes/falling_items.gd`; `src/core/factory_sim.gd`.*

### Demand-pull: never unlock a thing before the player has felt the problem it solves (LOCKED)

The Spur must not unlock with the drill, or you never feel that a Head covers one cell.

Its twin is that chores must not be invented. A Head is never `blocked`. With no shaft under it the ore
piles at its feet, like everything else in this game when it lands. Refusing to run in order to prevent a
pile would be a chore with no gameplay in it.

*Attested: `docs/DRIFT.md` §5, "The rule that keeps this from becoming an errand"; `docs/LODE_PLAN.md`
phase 2b.*

### Ore does not glow. It answers your lamp. (LOCKED)

Emission is reserved. The intent is for lighting to make ore feel special without making the game harder
to play through distraction and overstimulation, so the glint pass is a response to light rather than a
light source of its own.

*Attested: `scenes/world_renderer.gd`, the ore glint pass.*

### Darkness is the game's word for "you can walk here" (LOCKED)

Mining never writes a backing wall, so every player-dug tunnel is void and reads black. A hand-authored
opening that backs itself speaks a dialect the world does not, and reads as a scuff rather than a cave.

*Attested: `src/core/factory_sim.gd` `mine()`; `scenes/world_renderer.gd`.*

### The lode migration: terrain is what you carve, the lode is what you extract (LOCKED)

Ore moves out of the terrain plane into a background lode plane. The old model made a vein be the rock,
so a tunnel driven through an ore body destroyed everything it did not pocket.

The target is that no solid ore survives the cutover. Deletion of the solid-ore code path is deliberately
split into a separate later commit, because bisectable beats bundled.

Phases 1, 2, 2b and part of 4 have shipped. Phase 3 was later split. 3a, the generated lode plane, shipped
on 2026-08-17 in `303d1f5` and `8498ae3`; 3b, converting the solid ore blocks, is not done. 3a is purely
additive: `LayeredWorldGen` still scatters solid `ore`, `coal`, `iron` and `rich_ore` into `world.blocks`,
and `_seed_lodes` runs last and writes only `world.lodes`. That additivity is why 3a could ship without
disturbing the economy, and it is also why a world is never half-migrated today. The half-migration risk
returns the moment 3b starts deleting.

*Attested: `docs/LODE.md`, `docs/LODE_PLAN.md`; commits `303d1f5`, `8498ae3`; tag `pre-lode`;
`src/core/layered_world_gen.gd`, `src/core/world_data.gd`.*

### Presentation is the priority, not more simulation (LOCKED)

The agreed ordering is real art, then audio, then onboarding, then a movement rebuild. Not more sim, not
more worldgen. The game is judged the way a player would judge it, holistically, against "Factorio ×
Terraria with gravity". A mechanically correct build that reads as programmer art is a build with a real
problem.

Legibility beats spectacle. Every effect has to survive the question of whether it makes the game harder
to read in motion.

Menus have to read as current. Elevation rather than borders. Defocus the world behind a modal. A detail
plate for the selected thing. Costs as glyphs. Never a wall of locked rows; the future belongs on the
research screen.

### 2026-08-16: default zoom 0.70× to 1.00× (LOCKED, with its derivation)

At 0.70× the field was 57×32 cells, which put the miner at well under one percent of the frame's width.
That is the measured floor under "it's hard to see the character at base zoom". Every code lever for his
presence (the cool two-tone rim, the head-lamp, the guide ring) had already been pulled and blind
reviewers still located him by the marker rather than the sprite, because at that size there is no sprite
left to find.

1.00× shows 40×22 cells, still comfortably wider than Terraria's field in tile terms, and buys back 43%
of linear size on everything. Nothing was taken away: the old default survives one step out, then 0.50×
and 0.33×.

The reasoning lives in `scenes/main.gd` beside the constant, where someone changing it will read it.

*Attested: `scenes/main.gd` `ZOOM_LEVELS` and the comment above it, tagged #A4.*

### Reference images are mood, not target (LOCKED)

Do not overfit to Noita or to generated concept images. The real reference is this build, screenshotted.
Triangulate via negativa.

*No artefact records this beyond the decision itself.*

---

## Lore

### "The Works Are Cold" (PROPOSED, not canon)

There is no narrative text in the game. The entire fiction on screen is the title card
(`SINKFORGE`, `the way is down`), the eight band names in `scenes/strata.gd` (OPEN SKY, TOPSOIL, THE
CLAYBAND, SHALE REACH, THE LONG DARK, THE DEEPSLATE, THE SEAL, STONEREACH), and the Bazaar.

The proposed route is that the Sinkforge is a foundry sunk through the crust, cold for a century, and you
are relighting it. Its arguments: the game's title is the premise; the first machine you build (a Forge)
and the last (the Sinkforge) are the same machine at two scales; the `FORGED` counter has been in the HUD
corner all along meaning nothing; and the finale is a throughput crescendo rather than a shot fired
upward, which would reverse "the way is down".

The bore model, in which a shaft is bored through the crust and each layer hosts one system sited by its
own geology while your factory becomes the missing crew, is likewise proposed rather than canon.

Two pieces of lore already ship as art, which is why resolving this is worth doing. A colossus stands on
the horizon (`SkyPainter._sinkforge()`): a dead crown with an ember heart breathing in the cog hub,
dormant rather than extinct. And a ruin sits at spawn (`LayeredWorldGen.RUIN_X`, columns 40 to 43), an
almost-complete Bazaar frame one block short of working.

The cheapest first slice, which commits to nothing and is identical for the runner-up route, is to give
`scenes/strata.gd` a third field: one clause of found signage per band, in the hint table's voice, drawn
under the band name on the arrival plate.

*Attested: `scenes/hud.gd` (title card, `FORGED`); `scenes/strata.gd` `BANDS`; `scenes/sky_painter.gd`
`_sinkforge()`; `src/core/layered_world_gen.gd` `RUIN_X`.*

---

## Process

### Commits carry no co-author trailer (LOCKED)

The author is `teohondascully` only. Messages are prose in the house voice: what changed, and why,
including the failure that motivated it.

The rule was written down long before it was enforced, and 23 pushed commits carried a trailer anyway. A
rule that lives only in a document is enforced by whoever last read the document. Two mechanisms now
carry it:

- `.githooks/commit-msg` refuses the ordinary path. It is tracked rather than sitting in `.git/hooks/`,
  because an untracked hook reaches no clone and no worktree, and so guards only the one machine where it
  was installed. Activate with `git config core.hooksPath .githooks`.
- `tools/check_trailers.sh` runs in the harness, which is the real enforcement: `--no-verify` skips a
  hook and no flag skips the suite. It sweeps every ref rather than the current branch, because a stale
  branch brings the trailer straight back on merge. It asserts that `core.hooksPath` is wired, so the
  guard's job includes checking that the guard is installed. It counts commits rather than matching
  lines, because a message carrying two trailers would otherwise be reported as two refs. And it carries
  a positive control that runs every time, because every other assertion in it is a search that found
  nothing, and a detector that has quietly stopped matching reports a clean history in exactly the words
  a clean history produces.

The scanner has no allowlist. There was one exemption for a while, covering a backup ref that held the
23 original messages, and it was closed. An allowlist that can grow quietly is how a guard becomes a
formality, and the cheapest way to stop one growing is not to have one.

The 23 historical commits were rewritten on 2026-08-17. Trees are byte-identical; only messages changed.

*Attested: `.githooks/commit-msg`; `tools/check_trailers.sh`;
`.github/workflows/harness.yml`, the `authorship` job.*

### Never destroy a curated file (LOCKED)

Never `rm`, `git rm`, or purge a file that was authored or curated by hand, without explicit per-item
confirmation. To exclude something from the repository use `.gitignore` or `git rm --cached`, never `rm`.
`history/` (the curated screenshot archive), saves, notes and `assets/sprites/` (hand-authored art) are
all covered.

The rule exists because 84 screenshots from that archive were once purged during a refactor.

*Attested: `.gitignore`, "THE VISUAL RECORD".*

### The visual record is committed, not merely kept

`history/` and the canonical `_moment_*.png` captures are tracked in git, as of 2026-08-17. Both were
ignored before that, `history/` under a `.gitignore` note reading "keep on disk, NEVER publish or
delete", which welded two unrelated rules together. Only the delete half was ever decided. The publish
half was never argued anywhere, and it was the half doing the damage, because an ignored file has no
undo: a capture overwritten in place was simply gone.

Committing serves the rule above rather than straining against it. It is the strongest available form of
not destroying these files, and a public MIT-licensed repository of one's own game discloses nothing by
carrying pictures of it.

The captures are not regenerable. Re-running `tools/capture_moments.gd` does not reproduce them, because
the game it photographs has changed, so each one records a world that no longer exists. That is the
argument for versioning them rather than against it.

The cost is worth writing down, because git history is permanent. `history/` is about 227MB and the root
captures about 72MB, against a `.git` that is now roughly 350MB. There is no lossless win to take first,
since they are 8-bit RGB PNGs at 1920×1080 and already near 3:1. Lossy compression is barred outright,
because several harness layers sample these pixels; quantising would corrupt the evidence rather than
merely soften the picture.

`history/.gdignore` keeps the archive out of Godot's resource scanner. That is not an optimisation. CI
runs `godot --headless --import` from a clean clone in both of its build jobs with no cache, so every
tracked image would otherwise be imported twice per push, and nothing in the project references the
archive. Its `.png.import` sidecars are untracked for the same reason, and left on disk, because
untracking and deleting are different operations. The root captures stay visible to the scanner, because
`tools/` addresses them by `res://` path.

*Attested: `.gitignore`, "THE VISUAL RECORD"; `history/.gdignore`; `.github/workflows/harness.yml`.*

---

### A search's null bounds the search, never the world (LOCKED)

An empty grep is a fact about the pattern, the population and the file types it ran over. It is never a
fact about the program. Treating one as evidence of absence has cost this project more time than any
other single habit.

The case that named it. A band of pure green over pure red appeared at the top-left of a capture. Four
searches were run for a source: colour literals across all `.gd`, named `Color.<NAME>` constants (which a
`Color(` pattern structurally cannot see), pure primaries in all five `.gdshader` files, and `.tres` /
`.tscn` / `.godot`. All four came back empty, and each null was read as *"therefore the colour is computed
at runtime, therefore no search can find it."*

The first half was true. The second half did not follow from it, and the truth was worse than either: the
colour was computed **by the GPU, on stored pixels, by a pass that runs every frame**. A bake viewport
retained its target and re-applied `adjustment_saturation = 1.18` to its own previous output on every
incremental bake, compounding as `1.18^n` until each pixel's dominant channel clipped to 1 and the rest to
0. A pure primary is the *fixed point* of that map. No source search over any population could ever have
reached it, because no source contained it.

> The failure was not that the searches were too narrow. It was that nobody asked whether a search was the
> right instrument.

**How to apply.**

- Before widening a failed search, ask what kind of thing the answer would be, and whether the instrument
  can represent it at all. A grep finds authored values. It cannot find computed ones, accumulated ones, or
  values that are the fixed point of a transform applied repeatedly to its own output.
- When a null is load-bearing, run a deliberately weaker search that MUST return something, and confirm it
  does. A pattern that matches nothing is indistinguishable from a pattern that is wrong, and the two are
  told apart only by a control.
- State the population with the result, always: which paths, which file types, which pattern. "Nowhere in
  the codebase" is not a finding until it says what was read.

The same rule in its positive form, which is cheaper than any of the above: **look at the artifact.**
Rendering the item icons to a single PNG found a glyph that measured cleanly distinct from all twenty-six
others and read as a magnifying glass, and it found that the icon suite was grading art at 48px that the
game draws at 13px. Both were invisible to a passing, correct test suite. An artifact you can look at is a
population of one, and looking is cheap.

## Errata: claims in pushed commit messages that are wrong

A commit message is the one artifact in this repository that cannot be corrected in place. Amending a
pushed commit rewrites history that other clones may hold, so the standing decision is **not to rewrite
history for a wrong message** — the correction is recorded here instead, where it is public and lives
next to the reasoning.

Both entries below are mine, both were caught within a day, and both come from the same root: a claim
that felt established but was read off too little data.

**`e9feb96` — "`scenes/bazaar_page.gd` is 1412 lines."** It is 1441. 1412 was the count before the
accessor and forwarders the same commit adds. The extraction figures in that message are correct; only
the total is wrong.

**`a499e06` — "waiting on `lamp_residual()` … made the spread worse."** Unsupported. The comparison was
five samples against five: 1.35 against 2.70. Eight further runs of the first arm also read 2.70, so the
1.35 was a lucky draw and the difference was never there. The supportable claim is that the change showed
**no measurable improvement** and was reverted for lack of evidence, not that it was harmful. The
mechanism offered for the harm — that a variable-length wait re-varies everything else that free-runs —
is plausible and unevidenced, and should not be repeated as a finding. That commit is itself reverted by
`00ec990` for an unrelated and larger reason, recorded in the revert's own message.

The general rule this produced: **a spread is not a number you can read off five samples, and neither is
a difference between two spreads.** Put comparative claims where they can be amended.

## Measurements worth not re-deriving

Not decisions, but numbers that were expensive to establish once.

- **Captures of the same build are not identical.** Animation phase alone moves pixels between two runs
  of the same code. To show that a render change is invisible, count changed pixels against a
  >0.20 threshold and produce a magenta difference map; do not average a luma delta, which inherits the
  dark's compression and reads a crushed change as an absent one. Bisect behind a temporary environment
  switch, and never conclude from a single number.
- **The mining hitch was the terrain bake, in three separate forms.** Repainting the whole ~7700-cell
  coarse world on every dig cost a ~300ms freeze, fixed by splitting the static terrain into 8×8-cell
  chunk canvases so a dig repaints ~64 cells. The coarse bake was then ~72% of the frame's draw calls on
  a mature base (~11,882 of them), fixed by hosting the chunk canvases in a world-sized `SubViewport` and
  drawing its render target as one quad. Re-rendering that whole 4096×4096 viewport still cost ~100ms per
  dig, two thirds of a 114ms hitch, fixed by retaining the target and re-rendering only dirty chunks.
  Separately, the fine-terrain baker re-processed the whole ~120k-cell fine grid on every terrain change;
  `src/core/fine_terrain.gd` `sync_block()` now re-molds one coarse cell's block plus a sync band, 144
  fine cells at current settings.
- **A retained render target compounds any post-process it inherits.** The terrain `SubViewport`
  inherited the `WorldEnvironment`, whose adjustment pass runs as a viewport post-process, so saturation
  1.18 was re-applied to the same stored pixels on every bake and the terrain compounded 1.18^n. A grass
  cell measured (87,130,47) at boot and (42,255,0) after one play arc, and the walked surface line, the
  one strip the fine layer does not cover, became a neon red-and-green band across the full width of the
  frame. Fixed in `deff5e7` by giving the viewport its own `World2D`; guarded by
  `tools/check_bake_idempotent.gd`.
- **Eighty-odd harness layers passed that frame.** Every layer boots, settles and shutters, so the suite
  was blind to a defect that compounds per event. Generate the state first, through the real path, then
  assert idempotence.
- **Roughness terms add in quadrature, not linearly.** Ablate rather than derive. Three sines summing to
  a nominal ±1 have an RMS around 0.41 and never reach their extremes, so a threshold aimed at ±1 fires
  at a fifth of its intended strength forever.
- **The body is two rows tall.** `Player.HEIGHT` is 34px against a 32px cell, deliberately, so that two
  tiles of clearance are required and a one-tall gap is an honest squeeze. A passage that opens one row
  per column without keeping the row above open is impassable, and sim-level tests will not catch it
  because they only check floor cells.
- **Never put a hole in the spawn plateau's walking surface.** It cost four harness layers at once,
  twice, in two different columns. That surface is simultaneously the tutorial corridor and the runway
  several movement layers measure on. It surfaces as four unrelated-looking failures at once:
  `check_fastforward`, `check_loop_health`, `check_pacing`, and the play-tests. If those four go red
  together, suspect the surface first.

*Attested: `scenes/world_renderer.gd` (the chunk grid and terrain bake); `src/core/fine_terrain.gd`;
`tools/check_dig_hitch.gd`, `tools/check_bake_idempotent.gd`, `tools/check_frametime.gd`;
`scenes/player.gd` `HEIGHT`.*
