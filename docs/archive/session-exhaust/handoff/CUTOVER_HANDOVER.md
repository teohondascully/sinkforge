# HANDOVER: THE LODE CUTOVER (docs/LODE_PLAN.md phase 3)

You are taking over the single most dangerous change in an in-flight migration. Read this whole
document before you touch a file. It contains things that were learned by breaking the build, and
you will not rediscover them cheaply.

---

## 0. WHAT THE GAME IS, AND WHAT THE MIGRATION IS

SINKFORGE is "Factorio × Terraria with gravity": you dig into solid, ore-rich earth, carve a base,
build an automated factory, and descend through geological layers.

**The migration in one sentence: ore stops being a kind of rock and becomes a thing that is *inside*
rock.** Terrain is what you CARVE; the lode is what you EXTRACT. They used to be the same cell in the
same grid, which meant the pick could not tell "get me through here" apart from "give me that", and
driving a tunnel through an ore body silently destroyed every unit of it you did not happen to pocket.

Design doc: `docs/LODE.md`. Migration plan and eval gate: `docs/LODE_PLAN.md`. **Read both, fully,
before starting.** They are long and they are worth it — §5 of LODE_PLAN is a table naming exactly
which existing assertions are allowed to change and which are forbidden from changing.

### What already shipped (do not redo)

- **Phase 1** — `sim.lode` / `sim.lode_max` / `sim.deposits` exist; hand-extraction (`take_lode`) works;
  mining rock in front of a lode exposes it instead of destroying it; save/load round-trips lodes.
- **Phase 2** — the Head: a drill placed ON a lode drains it in place and pours down its own column.
- **Phase 2b** — the Spur: a passive coverage extender chained off a Head, so one Head works a whole vein.
- **Phase 4 (partial, landed early)** — the STAIN: buried ore is faintly visible through unbroken rock
  (`WorldRenderer._stain`), and lode density thins visibly as a vein drains. This shipped BEFORE the
  cutover on purpose, because after the cutover a world without it is featureless stone with no clue
  where to dig. **This is why your job is now possible at all** — go look at it in a capture.

### What is missing, and is your job

> **SUPERSEDED 2026-08-17 — READ THIS FIRST.** Phase 3a shipped (`303d1f5` + `8498ae3`): the generator now
> seeds a LODE plane and `FactorySim` ingests it, proven across 12 seeds × 5 sizes. **The paragraph below
> is false as written** and is kept only so the original scope reads intact. What remains for 3b is
> converting the solid ore BLOCKS, not creating lode from nothing — do not redo work that has landed.

**~~The world does not generate lodes yet.~~** Every vein in a generated world is still a solid `&"ore"` /
`&"coal"` / `&"iron"` / `&"rich_ore"` BLOCK. The entire lode system above is currently exercised only by
hand-authored fixtures (the starter adit) and by mining a solid ore block open. Your commit is the one
where the world itself is born with its ore in the wall.

---

## 1. SCOPE — AND WHAT IS DELIBERATELY *NOT* IN SCOPE

`docs/LODE_PLAN.md` phase 3 says "one commit: ore is born in the wall; the solid-ore path is deleted in
the same breath." **I am overriding the second half of that, and you should follow my override, not
the doc.** Record the reason in your commit message.

**IN SCOPE — the world stops MAKING solid ore.**

**OUT OF SCOPE — the code stops being ABLE to.** Do NOT delete `mine()`'s ore-like branch, do NOT delete
the drill's bore-through-solid path, do NOT strip `_is_ore_like`'s block role. That is a separate,
purely-subtractive commit (call it strike 29) and it is much safer once the constructive half has been
green for a while.

Why the split: leaving both paths alive for one commit costs nothing — nothing generates solid ore any
more, so the old path is simply unreached — while merging them means that when something breaks you
cannot tell whether the world generated wrong or the deletion cut something load-bearing. It also means
every existing test that hand-builds an ore block with `set_solid(cell, &"ore")` keeps working, so a red
layer in your run is a REAL regression and not fixture rot. Bisectable beats bundled.

---

## 2. STEP 0 — APPLY THE WORK ALREADY DONE

Two files are already written, with their reasoning, and saved as a patch. Apply it first:

```
git apply /private/tmp/claude-501/-Users-thondascully-Projects-sinkforge/62aafc5d-0a82-4415-8f09-b068a4c71b41/scratchpad/cutover_step0.patch
```

It contains:

1. **`src/core/world_data.gd`** — a new `var lodes: Dictionary = {}` grid (cell → vein material id),
   documented. Richness for a lode still lives in the existing `amounts` grid, which is why the whole
   richness pipeline (depth scaling, drought, the aquifer's rich roll) needs no changes at all.

2. **`src/core/layered_world_gen.gd::_grow_vein`** — the single funnel through which every ore, coal,
   iron and rich_ore body in the game is born. The change is two lines:
   - `world.blocks[cell] = material` → `world.lodes[cell] = material` (host rock left exactly as the
     strata laid it down)
   - a new `if world.lodes.has(cell): continue` guard. **This guard is not optional and it is subtle:**
     bodies used to be unable to overlap for free, because a cell already holding `&"ore"` failed the
     "is this earth/stone/deepslate/shale" host test. With the host now left intact, that test stops
     refusing them, and a later vein would silently overwrite an earlier one's material while keeping
     its richness. If you touch `_grow_vein`, keep this guard.

Read the patch. The comments in it explain the reasoning and you should preserve them.

**Verify step 0 before going further:** `git apply --check <patch>` should be silent. Note that after
step 0 alone the game is BROKEN (worlds generate with no ore reachable by anything) — that is expected,
because nothing reads `world.lodes` yet. Step 3 is what closes the loop.

---

## 3. THE REMAINING WORK

Ordered so the game is coherent again as early as possible.

### 3.1 `factory_sim.gd::load_world` — ingest the plane

Around line 666. It already clears `lode` / `lode_max` and ingests `blocks`, `walls`, `amounts`, `water`.
Add the `lodes` ingest: for each in-bounds cell, `lode[cell] = world.lodes[cell]` and set
`lode_max[cell]` from `world.amounts`.

Two things to get right:
- Guard a null/absent `lodes` the same way the `water` ingest guards itself — a WorldData that predates
  the field must still load (as a world with no lodes), because `SaveGame` and older tests construct
  WorldData directly.
- `lode_max` is the DENOMINATOR the renderer thins the fleck field against — it must be what the vein
  held when it was *opened*, not a global constant. For a freshly generated world that is its `amounts`
  value. Getting this wrong makes a fat vein draw as if it were nearly stripped; that exact bug already
  happened once and is why `lode_max` exists at all.

### 3.2 The other three ore-writing sites

`_grow_vein` is the main funnel but it is not the only writer. Find them with:
`grep -n '&"ore"\|&"coal"\|&"iron"\|&"rich_ore"' src/core/layered_world_gen.gd src/core/heightmap_world_gen.gd`

- **`layered_world_gen.gd::_mineralize`** (~line 654) — "the chasm pays": walks a rift's carved cells and
  enriches the solid rock touching them. Two branches: existing `&"ore"` upgrades to `&"rich_ore"`;
  plain stone/shale/deepslate sometimes becomes `&"ore"`. Both now operate on the lode plane and must
  leave the host rock alone. **The `ore → rich_ore` branch must now test `world.lodes.get(cell)`, not
  `world.blocks.get(cell)`** — otherwise it will never fire again and the rift reward silently vanishes,
  which is exactly the kind of failure that passes every test and ruins the game.
  Also preserve the `cell.y >= DEEPSLATE_ROW` depth gate; its comment explains why (rich ore at shallow
  depth lets a player skip a tier gate by walking sideways).

- **`layered_world_gen.gd`** ~line 845 and ~line 814 — the ore/coal scatter callers. These pass material
  into `_grow_vein`, so they should need no change. **Verify that; do not assume it.**

- **`heightmap_world_gen.gd`** ~line 121 — `world.blocks[cell] = &"ore"`. This is the FLAT tutorial world
  generator (the one that makes the spawn plateau). Same treatment: write the lode, keep the host rock.
  Note it currently writes no `amounts` entry at all — decide what richness a heightmap vein has and say
  why in a comment, rather than letting it default silently.

- **`_REWARD_ROCK` / `_structural_rock`** (~line 740) — reads `[&"ore", &"rich_ore", &"coal", &"iron"]` as
  block materials and substitutes `&"stone"` for structural purposes. After the cutover no block is ever
  one of those, so this becomes dead-but-harmless. **Leave it** (out of scope per §1) but note it in your
  report as a strike-29 deletion candidate.

### 3.3 `world_seeder.gd` — the hand-placed spawn fixtures

**READ `docs/LODE_PLAN.md` AND THE FILE'S OWN COMMENTS FIRST.** `_seed_starter_adit` is already written
in the post-cutover idiom and is your reference for how a lode fixture should look. Do not change it.

- **`_seed_starter_vein`** (cols 47, 48 at `SURFACE`) — the bootstrap ore you hand-mine for your first
  ingots. Currently `set_solid(cell, &"ore")` + `deposits = 200`. Becomes: host rock stays solid, lode
  behind it. **See §4.1 — these cells are ON THE SPAWN PLATEAU'S WALKING SURFACE and must remain SOLID
  at seed time.** They do: you are replacing a solid ore block with a solid rock block, so solidity is
  unchanged. Just be certain you do not "helpfully" carve them open.

- **`_seed_tutorial_coal`** (col 54 at `SURFACE`) — same treatment. Same surface constraint.

- **`_seed_tutorial_mineshaft`** — **this one needs a real redesign, not a substitution.** Today:
  ```
  col 56 SURFACE    open mouth (toss things down here)
  col 56 SURFACE+1  MINESHAFT_DRILL_CELL — open; player drops the Drill here
  col 56 SURFACE+2  MINESHAFT_ORE_CELL   — a SOLID ore block the drill bores DOWN into
  col 56 SURFACE+3  AUTO_FORGE_CELL      — catches the bored ore
  col 56 SURFACE+4  open (ingots land)
  col 56 SURFACE+5  rock floor
  ```
  The old drill bored down through solid ore from above. **A Head does not do that — it sits ON the lode
  it eats.** That is the placement rule the whole migration teaches ("you put the machine on the thing it
  eats"), so the tutorial must demonstrate it, not contradict it.

  My recommendation, which you may overrule if you can argue better: make the drill cell and the lode
  cell the SAME cell. The player looks down the shaft, sees a stained/flecked vein in the back wall of an
  open cell, hand-works a little of it, and then drops the Drill directly onto it — and the ore falls to
  the forge below exactly as before. That teaches the new rule in one move and pays off the stain
  immediately.

  Whatever you choose: `MINESHAFT_DRILL_CELL`, `MINESHAFT_ORE_CELL`, `AUTO_FORGE_CELL` and
  `MINESHAFT_ORE_RICHNESS` are constants in `scenes/main.gd` (~line 578) and are referenced by
  `tools/arc_driver.gd:163`, `tools/play_tests.gd:1263`, and `scenes/main.gd:2511`. If you change what a
  constant MEANS, rename it — a constant whose name lies is worse than a renamed one, and these are read
  by the play-harness.

### 3.4 Sonar — the payoff

`scenes/main.gd::try_scan` (~line 1909). It already filters on `sim.is_solid(cell) and
sim.ore_deposit_at(cell) > 0`, and `ore_deposit_at` already falls through to lode deposits — so
**prospecting through rock should start working essentially for free**, which is the feature finally
becoming what it was always supposed to be. Verify that claim rather than trusting it.

One thing IS wrong: it builds each echo with `"material": sim.material_at(cell)`, which returns the
BLOCK material — now `stone`, not `ore`. Echo colour will go grey. Prefer the lode material when there
is one.

### 3.5 `objectives.gd` — the tutorial ladder

**Non-negotiable, and it is stated as such in the plan: shipping a tutorial that describes the old game
is worse than shipping the old game.** Read the whole file; the steps are at ~line 38.

Steps whose TEXT is now false: `mine` ("hold LMB on the metal-flecked rock by spawn"), `build` ("Drop the
Drill into the shaft just ABOVE the ore vein — it bores down into it"), `fuel` ("mine the coal vein right
of the shaft"). Rewrite them to describe clearing rock to expose a vein, working the exposed face, and
covering it with a Head.

Steps whose COMPLETION CHECK may also need work: `_find_line()` uses `drill_column_remaining`, which I
believe already reports a lode face — **verify it, do not assume**. `_produced(&"ore") >= 4` should still
work (hand-working a lode counts as produced) but confirm the player can actually reach 4 in the seeded
world without a drill.

Keep the writing voice. These strings are terse, second-person, and concrete about which key to press.

### 3.6 `hints.gd`

Same treatment, smaller. `grep -n "ore\|vein\|mine" scenes/hints.gd` and fix anything that describes ore
as a block you break.

### 3.7 Rendering — verify, probably no change

`WorldRenderer._cell_base_color` already stains solid cells that have a lode behind them, so a generated
world should immediately show the tell. **Take a capture and look at it** (§5). Check `_draw_ore_glints`
does not depend on ore BLOCKS existing.

### 3.8 The tests

This is where most of your time will go, and it is the actual deliverable — a green harness that is
green for real reasons.

`docs/LODE_PLAN.md` §5a lists the assertions that are ALLOWED to change and what they must become. §5c
lists invariants that must NOT move under any circumstances. **Treat §5c as law.**

Expect to touch: `tools/test_worldgen.gd`, `tools/check_richness.gd`, `tools/arc_driver.gd`,
`tools/play_agent.gd`, `tools/play_tests.gd`, `tools/mock_bazaar.gd`, `tools/capture_moments.gd`, and
possibly `tools/test_sim.gd`, `tools/test_stress.gd`, `tools/check_drift.gd`, `tools/check_spoil.gd`,
`tools/check_tells.gd`, `tools/check_descent.gd`.

**The rule for every single one, and it is the most important instruction in this document:**

> When a layer goes red, the default assumption is that YOUR CODE IS WRONG, not that the assertion is
> stale. Fix the code first. You may only change an assertion when you can write down, in the assertion's
> own comment, *why the property it was checking was never real* or *why the property has deliberately
> changed and what the new property is*. "I lowered the threshold until it passed" is the failure mode
> this project has been burned by repeatedly, and a green harness bought that way is worse than a red one
> because it lies for the rest of the project's life.

A worked example of doing this correctly is in `tools/check_lode.gd::_the_rock_tells_on_itself` — an
assertion that compared two colour stains on hue was replaced, with the reasoning kept inline, because
the two stains had deliberately been given different channels and the old comparison was measuring the
wrong thing.

---

## 4. HARD-WON CONSTRAINTS — THE THINGS THAT COST DAYS

### 4.1 NEVER PUT A HOLE IN THE SPAWN PLATEAU'S WALKING SURFACE

This cost four harness layers at once, **twice, in two different columns**, and it is the single most
expensive trap in this codebase.

The flat spawn plateau's top surface is simultaneously (a) the corridor the opening tutorial walks,
(b) the runway `tools/measure_player.gd` measures run speed on, and (c) the path `check_fastforward`
walks. `measure_player` places the body at `FLAT_START + 6` (column 36) and runs **WEST**;
`check_fastforward` walks **EAST**. A single open cell anywhere along there turns a clean run into a
fall, and the failure surfaces as four *unrelated-looking* red layers: `check_fastforward`,
`check_loop_health`, `check_pacing`, and `play-tests`.

Layout constants are in `scenes/main.gd`: `SURFACE = HeightmapWorldGen.FLAT_SURFACE_ROW = 20`,
`FLAT_START = 30`, `FLAT_END = 66`. Cluster: col 40-43 bazaar ruin · col 46 forge · cols 47-48 starter
vein · col 49 spawn · col 51 tree · col 52-54 the starter adit · col 54 coal · col 56 shaft.

The starter adit solves this by being a **sealed pocket one row BELOW the surface** — you break into it,
the ground above stays whole. Read `_seed_starter_adit`'s comments; they were written after the failure.

If four playthrough layers go red at once and look unrelated, **suspect the surface first.** You can
confirm instantly with the `SF_NO_ADIT=1` env switch, or by seeding your change behind a temporary env
flag and A/B-ing the harness.

### 4.2 The body is TWO ROWS tall

The player body is 34px against a 32px cell, so it always occupies 2 rows. A passage that opens one row
per column without keeping the row above open is **impassable**, and the sim-level tests will not catch
it because they only check floor cells. This shipped once and had to be fixed with explicit walkability
assertions (contiguity, ≥2 rows, column overlap ≥ 2, roof unbroken). `tools/check_lode.gd` has them.

### 4.3 Determinism

Same seed must produce an identical world. The `routes` grid exists purely so tests can distinguish
deliberate structure from undirected cave. When you change generation, **keep the RNG draw order
identical** — moving or adding an `rng.randf()` call reshuffles everything downstream. A latent bug of
exactly this kind is documented in `_grow_vein`'s `min_row` comment: a rich-ore roll shifted the RNG
sequence and let iron crest through the seal onto the pre-breach shelf. Byte-identity with the OLD
(pre-cutover) world is NOT required — run-to-run identity under the new code IS.

### 4.4 Performance gates are flaky right now

Several other agents are running full Godot harnesses on this machine simultaneously. `check_frametime`
and `check_agility` — and to a lesser degree `check_stride`, `check_grapple`, `check_pump`,
`check_traverse`, `check_plunge`, `play-tests` — measure wall-clock and will go red purely from CPU
contention. If one fails, **re-run that layer alone** before believing it:

```
/opt/homebrew/bin/godot --headless --path . --script res://tools/check_frametime.gd
```

Correctness layers (`test_sim`, `test_stress`, `worldgen`, `check_lode`, `check_head`, `check_richness`)
are unaffected by load — trust those completely.

### 4.5 Do not destroy anything

**Never `rm`, `git rm`, or purge any file you did not create.** `history/` is an irreplaceable archive of
the maintainer's screenshots and is gitignored by design — never try to commit it, never clean it. This
is a standing hard rule after a previous agent deleted 84 of the maintainer's screenshots.

---

## 5. HOW TO ACTUALLY VERIFY

**Run the full harness. It must be 57/57.**
```
GODOT=/opt/homebrew/bin/godot bash tools/run_harness.sh
```
(~3 minutes normally; longer under load.) Individual layer:
`/opt/homebrew/bin/godot --headless --path . --script res://tools/<name>.gd`

**Then LOOK AT IT.** A green harness on this change is necessary and nowhere near sufficient — the whole
point is that the world now looks different.
```
/opt/homebrew/bin/godot --path . --script res://tools/capture_moments.gd -- <moment>
```
Must run **WITHOUT** `--headless`. Writes `_moment_<name>.png` at repo root, 1920x1080 (gitignored). Read
`tools/capture_moments.gd` for the moment list; `stain`, `lode`, `adit`, `chain`, `head` are relevant.
Read the PNG with the Read tool and actually look. Crop first, since detail is lost when a 1920x1080 is
scaled down:
```
sips -c <h> <w> --cropOffset <y> <x> in.png --out crop.png && sips -Z 900 crop.png
```
Geometry: one cell = 48 screen px at default zoom; the body is held at frame centre (960, 540).

**The questions the capture must answer**, and you should state your answers in your report:
1. Underground, can you tell where there is ore, without being told? (If not, the cutover has made the
   game unplayable regardless of what the harness says.)
2. Does a generated vein read as a *body* with shape, or as scattered noise?
3. When you clear rock off a vein, does the exposed face look like a reward?
4. Is the world now *too* stained — does every wall look vaguely ore-ish? Over-telling is a real failure
   mode; `docs/LODE.md` §7 says the tell must say "something is here", never "400 iron is here".

**Play the first two minutes in your head, concretely, and write it down:** spawn → what do you see →
what do you hit → do you get 4 ore → can you build the drill → does the tutorial's text match what just
happened? If any step in that chain is broken, the commit is not done, however green the harness is.

---

## 6. CODE STYLE

- GDScript, Godot 4.6.2. **TABS** for indentation, never spaces.
- Warnings-as-errors with `untyped_declaration=2`: every declaration needs a type. `:=` inference
  satisfies it.
- This codebase writes long, WHY-focused prose comments — often several lines, explaining the reasoning
  and frequently the *failure that motivated the code*. Match that density and that voice. A comment
  that restates the code is noise here; a comment that records why an obvious alternative was rejected
  is the house style.
- Python heredoc edits: use literal TABs, and always `assert s.count(old) == 1` before replacing.
- `timeout` is not available in this shell.

---

## 7. COMMITTING

Commit in YOUR WORKTREE only. Do **not** push, do **not** merge, do **not** touch the main checkout —
the orchestrator merges.

```
git add -A && git -c user.name="teohondascully" -c user.email="121736842+teohondascully@users.noreply.github.com" commit -q --no-verify -m "<message>"
```

The message must contain **no** mention of Claude, Anthropic, or co-authorship. Verify:
```
git log -1 --format='%an <%ae>'
git log -1 --format='%B' | grep -icE "claude|co-authored|anthropic"   # must print 0
```
(That grep exits 1 on zero matches and will short-circuit an `&&` chain — run it separately.)

Write the message in the house style: what changed, and *why*, in prose. Look at
`git log -5` for the voice. Include your reason for splitting the deletion out into strike 29.

Also update `docs/LODE_PLAN.md` phase 3 and `docs/LODE.md` §10 to record what landed and what did not.

---

## 8. YOUR REPORT

1. Worktree absolute path and commit SHA.
2. The harness result, **verbatim**.
3. Every file you touched and why.
4. **Every assertion you changed**, with the justification you wrote for each. If you changed none, say
   so — that is a strong result and worth stating.
5. Your answers to the four capture questions in §5, and your two-minute playthrough walkthrough.
6. What you found and deliberately did NOT do (strike-29 candidates, anything out of scope).
7. **Anything you are unsure about.** Do not paper over it. An honest "I could not verify X" is worth far
   more than a confident claim that turns out to be false — the orchestrator will re-check whatever you
   flag, and will not re-check what you assert.
