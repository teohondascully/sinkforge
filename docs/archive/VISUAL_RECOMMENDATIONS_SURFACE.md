> **ARCHIVED 2026-08-27.** Untracked since the 2026-08-25 pivot. `docs/archive/PIVOT_PLAN_2026-08-25.md`
> §1 scoped this as REWRITE (keep sections A-F — tutorial occlusion, world labels, grapple readability,
> terrain grammar — cut section G, the Bazaar's four tabs) — the "Edited 2026-08-25" header below
> suggests that edit was done, but it was never committed. Moved here rather than promoted to the live
> tree, on the same reasoning as `AGENT_PLAY_EVALUATION_PROTOCOL.md`'s header. Kept for provenance.

---

# Surface-frame visual improvement queue

> **Edited 2026-08-25** for the run-based pivot: sections specific to persistent-world design were
> removed or marked below. The rest of this document is unchanged and still describes current reality.

**Status:** director backlog for rapid, narrowly scoped visual iteration. This is deliberately granular:
the project may run many independent fixes in parallel, provided each one uses a named before/after frame,
one hypothesis, and an explicit regression guard. `docs/VISUAL_TRIAGE.md` supplies the four root systems
and acceptance philosophy; this file supplies the individual work.

**Evidence frame:** the two supplied SINKFORGE surface screenshots from 2026-08-17:

- **A — surface play:** miner, grapple/aim guide, two Forge markers, terrain cutaway, selected-item panel.
- **B — tutorial collision:** the same surface view with the SAPLING tutorial plate visible.

This is a frame audit, not an assertion that every issue exists in every state or is caused by one file. Each
ticket starts by reproducing its named frame through the machine lock and locating the responsible renderer,
HUD, or asset rule.

## Reference philosophies

### Factorio: operational information earns its brightness

Factorio is dense, but it does not make every fact equally loud. A player can inspect an inserter, belt,
machine, or alert because its state is carried by the world object or appears on demand. Its principle for
SINKFORGE: **throughput/status UI should clarify a machine already visible in the world; labels must not be
more memorable than the machine they describe.**

### Noita: the world owns the composition

The Noita reference is visually calm despite a complex simulation: HUD stays at edges, the player remains a
small but readable silhouette, terrain reads as broad mass before detail, and empty space is permitted.
Its principle for SINKFORGE: **make the player’s intended route and the surrounding mass legible before
adding texture, badges, or explanation.** This is not a request to copy Noita’s palette, darkness, or pixel
simulation.

### SINKFORGE’s own direction: kinetic industrial descent

The game must retain its brighter surface and its expressive grapple. The desired frame is not minimalist;
it is a miner in a physical world whose industrial tools visibly change that world. Its principle:
**every bright/animated element should either describe a committed player action, a live machine state, or a
newly discovered opportunity.**

## Dispatch rules

- One ticket, one primary visual hypothesis, one named frame.
- Use `tools/with_machine.sh` for any Godot/capture work; never overwrite canonical captures.
- Review normal play scale first; then 1× and 4× when pixel craft is involved.
- Preserve a before/after image pair and state which changed pixels support the claim.
- Structural tests protect layout/state. They do not certify beauty; a capture review is mandatory.
- `INVALID` is acceptable when the frame, state, capture, or ownership cannot be reproduced.
- Do not lower legibility/performance/HUD thresholds to buy a green result.
- The agent chooses no unrelated cleanup. A rejected treatment is recorded and reverted.

## Queue

### A. Attention hierarchy and tutorial interruption

| ID | Recommendation | Frame evidence | First bounded treatment | Guard / verdict |
|---|---|---|---|---|
| UI-01 | Replace the screen-centred SAPLING plate with a source-bound first-use cue. | B: the plate covers the player’s upper context, sky, gear, and nearby tree while teaching a local placement action. | One-line prompt beside valid grass/held sapling. | Player can still discover valid placement; no central occlusion. |
| UI-02 | Make first-use teaching conditional on relevance, not merely item selection. | B: lesson persists while many other active signals exist. | Show only while sapling is held and cursor is near valid/invalid ground. | Cue vanishes when item changes or action completes. |
| UI-03 | Suppress non-critical help while grappling, aiming, falling, or moving quickly. | B: tutorial competes with the grappling state underneath. | Gate non-critical announce state on active movement/aim state. | Critical danger/error feedback still appears. |
| UI-04 | Give every tutorial a demonstrated-use retirement condition. | B: the panel teaches an action but occupies persistent space. | Record successful first plant; retire or reduce future cue. | Returning players can recover help through an opt-in surface. |
| UI-05 | Rewrite lessons to one action plus one immediate world consequence. | B: “It grows into a NEW TREE: wood is renewable” is a second concept competing with the input instruction. | “Plant on grass with RMB.” Reveal renewability after successful plant or in codex. | No loss of essential instruction. |
| UI-06 | Establish a tutorial maximum footprint. | B: a large central rectangle dominates a small action. | Define a capture-reviewed max height/coverage for non-modal lessons. | Do not treat panel area alone as an aesthetic score. |
| UI-07 | Separate objective/progression language from affordance language. | A/B: pointers, labels, and lesson all read like competing objectives. | Inventory all active helpers and tag as critical/active/discoverable/ambient. | Only one primary attention state at a time. |
| UI-08 | Add a quiet-frame test state. | A: even idle surface play contains many competing signals. | Capture normal surface with no hover/tutorial/selection transient. | Player and intended route become first read. |

### B. World labels, arrows, and target indicators

| ID | Recommendation | Frame evidence | First bounded treatment | Guard / verdict |
|---|---|---|---|---|
| UI-09 | Replace persistent `FORGE` text with world-first state reading where possible. | A: the `FORGE` label is larger/more readable than the tiny machine. | Hide label outside proximity/hover or make it an optional inspect result. | A new player can still find and identify the forge. |
| UI-10 | Remove duplicated Forge guidance. | A: two `FORGE` labels and two downward markers make the same zone feel overexplained. | Identify whether each communicates a distinct machine/objective; retain only unique information. | Do not remove a genuinely different destination/state. |
| UI-11 | Make arrows encode a single grammar. | A/B: arrows under labels and triangular markers near points compete with ring/cursor language. | Define arrow meaning: destination, placement, or active interaction—never all three. | State remains intelligible in a still frame. |
| UI-12 | Reduce selection ring competition. | A: large white circle and gold ring both draw attention near player/machines. | Assign one ring to active player action and soften/remove redundant ring. | Active target remains obvious during input. |
| UI-13 | Reserve white for immediate impact/physical event. | A: bright white rings, rope marks, ore glints, and highlights all use similar urgency. | Reduce non-critical white UI or move it to muted material colours. | Mining/impact feedback remains punchy. |
| UI-14 | Move persistent status from free-floating text into hardware. | A: labels describe small machines that have insufficient visible state themselves. | Add/clarify one physical indicator before adding text. | Works with labels hidden and in grayscale. |
| UI-15 | Create an explicit “inspect mode” for verbose labels. | A: the world is always annotated even while moving. | Show full machine names/details only on hover/hold/map mode. | Essential emergency status remains available. |

### C. Grapple and player action readability

| ID | Recommendation | Frame evidence | First bounded treatment | Guard / verdict |
|---|---|---|---|---|
| GR-01 | Replace or soften the persistent dashed grapple guide. | A: vertical dashed line reads as construction/debug geometry, not a physical tool. | Compare current line with short dim reticle/arc while aiming. | Anchor acquisition remains as reliable. |
| GR-02 | Draw a physical cable only after commitment. | A: aim and attachment are visually conflated. | Separate aim preview from attached rope render. | Player knows whether hook is attached. |
| GR-03 | Encode tension through cable form/motion, not added UI. | A: current guide has no visible physical state distinction in still frame. | Small sag/straightness/opacity shift tied to tension. | No movement physics change. |
| GR-04 | Reduce rope contrast against calm sky/background until it is needed. | A: the guide rivals the miner silhouette against blue sky. | State-based alpha and endpoint emphasis. | Cable remains readable against dark underground. |
| GR-05 | Make anchor preview local to the likely endpoint. | A: long guide occupies most of the frame. | Endpoint reticle + short predictive segment. | Prevent accidental/corner anchors. |
| GR-06 | Ensure player silhouette remains above tool telemetry. | A: rings/line pull attention away from the small miner. | Compare player outline/value contrast against active aim state. | Do not add a permanent player glow. |
| GR-07 | Review the grapple in motion, not only screenshots. | A gives no timing evidence. | Named swing capture/video with aim, attach, tension, release, miss. | Direct human movement feel is final authority. |

### D. Terrain material identity

| ID | Recommendation | Frame evidence | First bounded treatment | Guard / verdict |
|---|---|---|---|---|
| TR-01 | Reduce isolated pale dirt accents. | A: tan/white/brown single-cell spots produce a mottled/cow-spot read. | Lower density or cluster accents in one dirt test region. | Dirt does not become flat wallpaper. |
| TR-02 | Stop using equal-frequency noise for dirt and stone. | A: both read as square variation before material. | Define separate dirt clump/strata and stone fracture/plane rules. | Independent reviewer names each material without UI. |
| TR-03 | Establish broad dirt mass before microtexture. | A: many local squares obscure large soil volumes. | Add low-frequency compaction/strata field before small marks. | Preserve mining-cell readability. |
| TR-04 | Establish stone as plane/fracture rather than speckle. | A: stone regions share the same spotted language as dirt. | Use directional seams/planes with restrained chips. | Do not turn stone into geometric wallpaper. |
| TR-05 | Reserve brightest mineral glints for identifiable ore/event semantics. | A: bright marks in earth and cavity compete with UI white. | Compare meaningful ore glint clusters against random high-value accents. | Scanner/resource discovery remains legible. |
| TR-06 | Separate void darkness from rock texture. | A: dark underground regions retain noisy marks while air/rock mass is unclear. | Interior-only rock treatment after T3.1 root decision. | Existing rock/void gate must not regress. |
| TR-07 | Make freshly excavated faces relate visibly to their source material. | A: holes can read as black cut-outs rather than removed earth. | Test a restrained cut-face/boundary vocabulary. | Do not restore disproved generic edge treatment. |
| TR-08 | Remove smooth/blurred patches that do not express material state. | A: local soft areas break the hard pixel grammar without reading wetness/light/depth. | Locate renderer layer causing smoothing; test removal or semantic assignment. | Preserve intentional lamps, water, fog, and depth effects. |
| TR-09 | Audit texture density by depth band. | A: upper earth is busy while lower mass becomes dark noisy ambiguity. | Produce density/value histogram by material/band, then one band treatment. | Do not globally brighten underground. |
| TR-10 | Test material identity at normal camera scale before zoomed pixel craft. | A: a pattern can look intentional at 4× and unreadable during play. | Standardize normal/1×/4× review triptych. | Normal-play judgment wins conflicts. |

### E. Surface/subsoil continuity and world composition

| ID | Recommendation | Frame evidence | First bounded treatment | Guard / verdict |
|---|---|---|---|---|
| SF-01 | Bridge grass lip to upper dirt with a controlled topsoil stratum. | A: thin crisp grass strip abruptly becomes unrelated mottled ground. | One shared palette/value bridge below surface. | Surface collision and grass placement unchanged. |
| SF-02 | Give the first few underground rows a depth story. | A: no clear topsoil → packed earth → stone progression. | Sparse roots/compaction/erosion in a controlled slice. | Avoid decorative clutter. |
| SF-03 | Align edge language above and below ground. | A: surface silhouette is crisp; subsurface becomes diffuse/noisy. | Compare boundary contrast and pixel clustering rules. | Air/solid legibility does not regress. |
| SF-04 | Ensure trees/ruins feel embedded in terrain rather than placed on it. | A: large outlined tree/ruin silhouettes meet a very thin grass lip. | Ground-contact/shadow/root treatment for one prop type. | Do not resprite all surface props. |
| SF-05 | Clarify whether the giant background gear is landmark, ambience, or UI-adjacent decoration. | A/B: it sits behind the player, large and dark, with ambiguous meaning. | Test reduced contrast or a stronger world/story relation. | Preserve intended landmark silhouette if it carries lore. |
| SF-06 | Reduce non-semantic sky sparkles/bokeh when they compete with interaction markers. | A/B: several pale sky specks share visual language with bright player-world signals. | State-dependent density/contrast test in active play. | Keep atmosphere in quiet moments. |
| SF-07 | Establish one surface focal path per frame. | A: arch, gear, tree, player, labels, rings, and terrain all compete laterally. | Compose/cull/reduce one secondary focal element in a canonical surface moment. | Do not make the world empty; player route must improve. |

### F. Player, machines, and pixel-craft consistency

| ID | Recommendation | Frame evidence | First bounded treatment | Guard / verdict |
|---|---|---|---|---|
| PC-01 | Make the machine silhouette carry more identity than its label. | A: Forge hardware is tiny and generic relative to its text badge. | One forge silhouette/state pass at normal scale. | Name may remain available on inspect. |
| PC-02 | Reconcile pixel density between miner, trees, terrain, and UI glyphs. | A: hard black tree/miner outlines, mottled terrain, and crisp HUD all feel authored at different resolutions. | Create a one-frame pixel-scale audit before modifying art. | Do not blur everything into a common denominator. |
| PC-03 | Reduce black-outline dominance on non-critical surface props. | A: tree silhouette is strongly black-edged against a softer world. | Test selective outline/value reduction on one prop. | Silhouette remains readable against sky. |
| PC-04 | Ensure the miner reads at a glance when not selected. | A: small player is visually outranked by rings, labels, line, and nearby prop contrast. | A/B player value/silhouette comparison with chrome quieted first. | Do not solve through permanent halo UI. |
| PC-05 | Give installed machines a visible active/idle distinction. | A: labels/pointers carry state because hardware does not. | One physical state cue for forge/drill family. | Causality survives labels hidden and grayscale. |
| PC-06 | Reserve clean negative space around high-value interactions. | A: forge, rope, rings, terrain accents, and labels crowd the same local area. | Quiet surrounding noncritical overlays when interacting. | No loss of important warning information. |

### G. Bazaar and settings overhaul

> _[Section removed 2026-08-25, pivot: the Bazaar's four tabs (PACK/WORKS/BENCH/SETTINGS) and their menu-numbered findings are dead design. See git history for the original text.]_

---

## Priority and dispatch order

The director may dispatch many tickets concurrently, but their milestone order remains:

1. **T2.1 / V1:** UI-01 through UI-08, then UI-09 through UI-15 as evidence dictates.
2. **T3.1:** functional rock/void interior readability remains a prerequisite; do not obscure it with terrain polish.
3. **T3 terrain-material grammar:** TR-01 through TR-10 and SF-01 through SF-03, beginning with one
   controlled cross-section.
4. **T3 grapple visual language:** GR-01 through GR-07, paired with existing T3.10 movement-feel work.
5. **Existing T3.2/T3.11:** PC-01/05 and SF-04/05 only after terrain and HUD hierarchy stop masking them.
6. **T2.1 menu-overhaul parent:** MNU-01–MNU-35 begin with a visual-language/information-architecture
   prototype after V1. The prototype may run beside T3.1; broad implementation follows only after director
   review of the fresh, midgame, full-catalogue, and settings capture matrix.

Rapid iteration is encouraged. The protection against random polish is not a low ticket count; it is a
strong review contract: every ticket visibly improves its named frame or it is reverted, deferred, or
reframed.

---

## Ticket annotations — measured corroboration

*Per `docs/handoff/VISUAL_TRIAGE_LEAD_HANDOFF.md` Phase 0.3. Findings that arrived from instruments rather
than from the frame audit go here, so a ticket's evidence column stays the audit's and its corroboration
stays attributable.*

### SF-02 and TR-03 — corroborated by `check_opening`, which knows nothing about this document

**`check_opening` has been the suite's only red all day, and it is a TRUE red.** The peer session rendered
the frame it judges and outlined the condemned tiles using `dead_space.judge`'s own `rows` rather than a
reimplementation — so the map cannot disagree with the verdict. Band y 613..885, 16 x 2 tiles:

    row 1  ................    alive everywhere — it holds the grass/topsoil colour break
    row 2  ...##........###    dead under the ruin arch (x 360..600) and the right quarter (x 1560..1920)

**The finding is not which tiles are dead. It is which ones survive.** Row 2 passes *only where gameplay
content happens to sit* — an ore vein, the cave mouth, a forge. **The subsoil has no intrinsic texture at
this scale; it reads as alive only where something was placed on top of it.**

That is **SF-02** (*"no clear topsoil → packed earth → stone progression"*) and **TR-03** (*"broad dirt
mass before microtexture"*), reached by a pixel metric that predates this document and has never read it.
These tickets were authored from a subjective visual audit; this is the same conclusion from an
independent instrument. **Two methods, one conclusion, neither informed by the other** — which is a
different and stronger thing than a second opinion.

It also explains the 5-vs-6 dead-cell oscillation across runs: **the population sits on the threshold, so
lighting phase moves a tile across it. Thinness in the subject, not flakiness in the gauge.**

**Consequence for sequencing:** this is Phase 3 evidence arriving during Phase 2, and it does not promote
Phase 3. `check_opening`'s red is the *symptom* the terrain grammar would address; the interior-legibility
gate is still the gate. Recorded now so it is not rediscovered later and mistaken for new.

### `UI-01`–`UI-08` — `P1` closure, one line each

**Every one of these closes explicitly, per the handoff. "Waiting" is not a state.** Evidence frames are
`docs/media/baseline/` (before, immutable) against `docs/media/p1/` (after).

| ID | status | what happened |
|---|---|---|
| `UI-01` | **`SHIPPED` `6df9bd7`** | **Closed by the gate it was waiting on.** The premise was wrong about the code — `hint_anchor` was always the body through the canvas transform, never screen-centred — and right about the frame: the bubble hung over the miner's head whatever it was about, so the planting lesson covered the ground it described. `main.gd` now reads `if _hints.active_gate() != &"": anchor = _cell_center(_aim) + Vector2(0.0, -float(CELL) * 0.5 - 6.0)`. A gated lesson is only on screen because the cursor is over a cell that satisfies its gate, so that cell IS the subject and the tail points at it. Untouched lessons keep the head anchor, so this cost nothing anywhere else. |
| `UI-02` | **`SHIPPED` `d57e02a`** | **The predicate this row called missing was built, not worked around.** `Hints.SAPLING_GATE` (`&"plantable_ground"`) is declared on the def as `"when"`, `_init` folds every `when` into `_gate_of`, and `_ready_to_show` returns `_relevant.get(_gate_of[id], false)` — with `has` as the guard rather than a null test, because an absent gate and a false gate are different answers and both have to be reachable. The controller pokes it with the sim's OWN planting guard: `note_relevant(SAPLING_GATE, _can_reach(_aim) and sim.can_plant_sapling(_aim))`, so what the bubble promises and what the click does cannot come apart. Retirement was already `UI-04`'s latch. |
| `UI-03` | **`SHIPPED`** | `_busy` now **hides** as well as freezes. The clock already stopped while the body moved too fast to read; leaving the bubble drawn through a swing was one more thing over the rope at the moment the rope is the subject. **Hysteretic** — arms at 1.25× stride, releases below 0.9× — because a single threshold makes a cruising body strobe the lesson, and a suppression rule that flickers is worse than none. **Aiming deliberately excluded:** the cursor is live every frame of normal play, so gating on it would suppress the lesson permanently, which is `UI-04`'s retirement wearing `UI-03`'s clothes. |
| `UI-04` | **`SHIPPED`** | **"Fires once" had a period, and the period was one process.** `Hints._done` was never written to disk, so every state-edge lesson — grapple, wrap, chain, hard landing, aquifer — **re-taught itself in full on every launch.** `check_teaching` held the game to *"none of it is ever said twice"* and passed, because the assertion and the session live inside the same boot. Now carried in the save beside `player_pos`; absent in an old save restores today's behaviour. The demonstrated-use half is `planted`. Recovery surface: the existing `H` overlay. |
| `UI-05` | **`SHIPPED`** | The ticket's own example. *"It grows into a NEW TREE: wood is renewable"* moved off the pickup and onto the first sapling that **roots** — a payoff instead of a promise. `rich_ore`'s Blast Furnace path moved to the BENCH by the same rule: a research path is a plan, not a consequence. |
| `UI-06` | **`SHIPPED`** | `hint_box()` extracted from the draw call so the harness sizes lessons **without reimplementing the layout**. The ceiling is `LESSON_MAX_H = 52.0` (`tools/check_hud_layout.gd:951`), and the bubble it caps runs `HINT_FS` 8pt over a `HINT_WRAP` of 176.0 with a 16px pad (`scenes/hud.gd:684-689`). Set from measurement after the `UI-05` cuts, in which `pump`, `chain` and `wrapped` each lost a third clause and the lessons were rewritten to one line apiece: tallest lesson 47px at 3.92% of canvas, as recorded at `tools/check_hud_layout.gd:934-939`, which also carries the ceiling's whole history — *"It was 77, then 61; it is 52 now"*, every move downward and every one following the subject. **Width is deliberately not asserted** — `hint_box` clamps to `HINT_WRAP + 16` (`scenes/hud.gd:689`), so every lesson at the cap reports that number by construction and a width bound could not fail for any string. Two controls sit under the ceiling so it cannot pass empty: a deliberately over-long lesson must measure over it, and a one-word lesson must measure under it (`tools/check_hud_layout.gd:986-993`). **Numbers corrected twice, both recorded rather than overwritten.** On 2026-08-19 this row's `HINT_WRAP + 20` and 61px were flagged as two revisions stale. On 2026-08-20 the row still *led* with "Ceiling **61px = three drawn lines**" and contradicted itself two clauses later; 61 was the ceiling at 11pt over a 230px wrap and has not been the ceiling since. The stale figure is named here and stated nowhere as fact. |
| `UI-07` | **`SHIPPED`** | `Hud.HELPER_TAGS` classifies all **31** `_draw*` methods — critical 4 · active 3 · discoverable 6 · ambient 5 · internal 13, counted at `scenes/hud.gd:473-510` and printed by the layer itself on every run (`tools/check_hud_layout.gd:1025-1032`) — and the harness asserts **both directions** against the live method list, so a new surface fails until someone decides what kind of thing it is. **Count corrected 2026-08-20: this row said 28 methods with internal 10.** Only the prose was ever stale. The both-directions assertion (`tools/check_hud_layout.gd:1013-1024`) fails on an untagged method *and* on a tag naming a method that no longer exists, so the registry could not drift from the class while this row did — which is the distinction worth keeping: a number in a document is not guarded by the mechanism it describes. **The taxonomy immediately found something:** `PAUSED (P)` and the arrival plate are both `critical` and both aimed at the same strip. The chip had already been moved once, out of the objective line at y=8 and **into** the ceremony's band. It has left the centre column entirely — the centre has three occupants competing for 100px while the left column has two chips and 300px of nothing. |
| `UI-08` | **`SHIPPED`** | A `quiet` capture moment: the surface with the announce channel empty and nothing hovered. `boot` cannot serve — the TOPSOIL ceremony is up on frame one, so **the game's own opening shot contains an interrupt and every judgement made on it judges the interrupt.** The quiet frame is what `P1`'s completion review is entitled to: everything left in it was chosen rather than timed. |

**A NOTE ON THIS TABLE'S OWN RELIABILITY, added 2026-08-20 after it nearly cost two rebuilt features.**
`UI-01` and `UI-02` were read off this table as the two open items in `P1` and worked up as a plan — a
cursor-proximity predicate to build, a source-bound anchor to move. Both already existed, shipped hours
earlier as `d57e02a` and `6df9bd7`, and the only thing that caught it was reading the code before writing
any. That is the fifth time a row here has survived the change that closed it. **The table is a record of
what was true when someone last wrote in it, and closure lands in commits, not in rows.** Verify against
the source before starting anything this table calls open — and when you close something, close it here in
the same commit, because the cost is not confusion, it is duplicated work that reverts a better version.

**`P1`'s completion evidence is still a human/director review of that quiet frame.** Nine harness assertions
and a footprint ratchet say the composition no longer collides with itself. **None of them says it is
pleasant**, and the ratchet's own ticket warns against treating panel area as an aesthetic score.

### TR-06 — `PROVED`, and the root decision it was waiting on now exists

**Status: `PROVED` (2026-08-17, `c1`).** The ticket's own approach line said *"interior-only rock treatment
after T3.1 root decision"*, and it had no root decision to be after. It has one now, and the ticket's
premise — *"separate void darkness from rock texture"* — turns out to have been the diagnosis rather than
the recommendation. **The void was not merely dark; it was being TEXTURED, at slightly greater strength
than the rock.**

Two defects behind it, both measured by `c1`, both the same family as everything else found today:

1. **A mask that does not mask what its comment claims.** `rock_grit.gdshader` is titled *"SUB-CELL TOOTH
   FOR THE ROCK"* and says *"air gets none of this"*. It masks on `step(0.004, COLOR.a)` — but
   `fine_terrain` clears only the **sky**; both void branches (the wall behind a shelf, the back wall you
   have dug into) write **alpha 255, exactly like solid rock**. Measured before the fix: air's local grain
   **2.06** against rock's **1.83**. *The tooth written to make rock read as rock had been applied to the
   void at equal strength for its entire life.* Texturing both equally cannot separate them at any
   amplitude — which is why three separate amplitude and frequency treatments measured as nothing.
2. **The layer order defeats the one mechanism written for this problem.** `rock_grit` runs on the terrain
   layer at `z=-9`; `_dark` is a **MULTIPLY** layer at `z=50`. So `grit_add` — comment: *"a small additive
   floor so rock that the veil has taken most of the way down still has something in it rather than
   nothing"* — is scaled by precisely the factor that made the rock dark. The sampled median outside the
   lamp is **8.7/255**, so landing ±2 levels through that veil needs ±20 levels in *lit* rock. **The
   mechanism could not reach its own stated purpose from below the multiply.**

**Treatment:** `scenes/rock_tooth.gdshader` — the same tooth drawn again **above** the veil, additive,
masked on a new `VOID_ALPHA` (254, one level, invisible on an opaque layer) so the mask finally has
something true to read.

| | VALUE | GRAIN | rock / air |
|---|---|---|---|
| baseline | 52% | 61% | 8.3 / 9.2 — **inverted: air read as more substantial than rock** |
| treated | **67%** | **79%** | **12.6 / 9.0** |

`check_opening` **6 of 32 dead tiles → 0 of 32 against the CORRECTED instrument**; `check_underground`
0/22; `check_room_reads` PASS. **No threshold was moved.**

> **THE RULER HAS TO BE NAMED, AND IT TOOK A CHALLENGE TO GET IT NAMED.** I ran `check_opening` on
> `origin/main` at `f225eaa` — *without* the tooth — four times, and it **PASSED** every time at **2/32**,
> with its dead pair in a different place from the one `c1` reported. Two sessions had two numbers for the
> same world. `c1` then ran the control neither of us had, on a clean detached worktree:
>
> | renderer | instrument | horizon | result |
> |---|---|---|---|
> | main, no tooth | main's | y=589 | **1–2 / 32 PASS** |
> | main, no tooth | `c1`'s corrected one | y=613 | **6 / 32 FAIL** (×3, no variance) |
> | tooth | `c1`'s corrected one | y=613 | **0 / 32 PASS** |
>
> **Same world, two rulers, and the ruler is what moved.** `c1`'s branch carries two unmerged instrument
> repairs: `check_opening.gd`'s `_horizon_y` (the capture-geometry projection defect), and `dead_space.gd`,
> whose metric summed **horizontal** neighbour differences only and now averages both axes. Main therefore
> judges a band ~24px too high and **misses the deadest subsoil row entirely** — the second row, where
> every condemned tile lives — and its one-axis metric scored ground that is flat vertically and banded
> horizontally as alive.
>
> **CORRECTED, BY `c1`, AGAINST THEIR OWN EARLIER SENTENCE.** They first reported *"6/32 three consecutive
> times, zero variance"*; a later clean-worktree run measured **7/32**. So the figure is **6–7/32** and it
> **does** wobble by a tile across runs, consistent with the animation-phase noise we already know about.
> **The verdict does not wobble** — 6 and 7 both fail a cap of ~3.8 tiles — and the 2-vs-6 gap is four
> tiles, far outside a one-tile jitter, so phase-dependence is still ruled out *as the explanation for the
> disagreement between the two rulers*. It is **not** ruled out as a property of the metric.
>
> *Recorded because I quoted "zero variance" here on their word, and a correction is exactly the kind of
> claim that gets believed for feeling already-verified.* `check_underground` and `check_water_reads` are
> unmoved by the corrected metric, so it changes one layer and only the one with a real dead region.
>
> **So the finding survives and the sentence changes.** Not *"took the suite's only red to green"* but
> *"took 6/32 to 0/32 against the corrected instrument"* — the red cleared was one `c1`'s own instrument
> fix had exposed. Smaller, and true. **And the consequence points the other way: `check_opening` is
> currently GREEN ON MAIN because of two instrument defects, so main's opening dead-space number is a
> LOWER BOUND and must not be quoted as a baseline until those land.** `tooth_add` was taken to 0.030 rather than 0.022 because 0.022 measured exactly
75.0% against a 75% floor — *a one-point margin is not a margin.*

**AND SF-02 GETS A SECOND, STRONGER CORROBORATION FROM THE SAME WORK.** The subsoil band described above —
alive only where gameplay content sat on it — now has texture of its own. **SF-02 was a symptom of a
functional defect, not only of a missing grammar**, which is the phase sequencing working exactly as the
handoff designed it: a Phase-2 functional fix paid a Phase-3 ticket without Phase 3 starting.

**WHAT THIS DOES NOT CLOSE, stated by the engineer who did the work rather than extracted from them:**
*"This is legibility, not grammar. The tooth is one isotropic language over all solid material, so **TR-02
and TR-04 are untouched** — dirt and stone still share a variation language, and stone is not yet
plane/fracture. I will not let 'the rock test passes' read as 'the rock reads correctly.'"* Phase 3's gate
is clear; Phase 3 is unstarted.

### V0 — a baseline captured by a different code path is a different frame

**Method note, and it cost a wrong conclusion before it was caught.** A standalone probe of the opening —
same scene, same `dev_start = false`, only `SETTLE` raised 60 → 90 — captured **the Bazaar modal over a
dimmed world, with no terrain in the frame at all.** Judging that image would have "confirmed"
`check_opening` was measuring a scrim and filed a false finding against a working layer.

The fix was to dump the PNG **from a copy of the judging layer itself**, so the capture path cannot diverge
from the path under audit. **For every named V0 baseline: the divergence between two capture paths is
silent and total, not marginal.** A baseline that disagrees with the layer that judges it looks exactly
like a baseline that agrees.

### `PC-05` — `SHIPPED` (`P5a`, 2026-08-18, `c2`), and the ticket's evidence line was literally true

The ticket reads *"labels/pointers carry state because hardware does not."* That is what it looked like
from the outside. Inside `_paint_lights` the line was:

```gdscript
if kind == "furnace" and not _machine_active(machine):
    pulse *= 0.12   # (Non-furnace runners keep their steady casing glow.)
```

A stopped drill, hopper, splitter, crusher, borer, press, mill and pump each lit the rock around them
**exactly as brightly as a working one**. The hardware was not merely silent about its state; it was
asserting the wrong one — in the one channel that carries across a dark room. And the parenthetical had
turned that into a design note, which is the reason it survived: *a defect phrased as an intention does
not read as a defect.*

**Measured** by `tools/check_machine_state.gd` — one subject at a time, all six in the same stage cell,
name label / held badge / status lamp suppressed, Rec.709 luma inside the cell. `D_motion` compares two
captures of the **same** state at different animation phases; `D_state` compares working against stopped.
Anything at or under `D_motion` is the sprite breathing.

| machine | working | stopped | `D_motion` | `D_state` | |
|---|---|---|---|---|---|
| Forge | 142.9 | 50.6 | 5.22 | **92.39** | already gated — the control, and it barely moves |
| Drill | 170.1 | 89.6 | 7.11 | **81.22** | was `12.4` against a motion baseline of `8.8` |
| Generator | 208.0 | 76.3 | 25.62 | **131.73** | |

Before the fix the Drill's **stopped** frame was *brighter* than its working one — 179 against 172. The
milestone frame `history/131-the-drill-that-glowed-while-stopped.png` is the twelve patches side by side;
in the top row the Drill's two states are the same picture with the bit at a different angle.

**The gate was the entire difference between the Forge and the Drill.** The casings, the glyphs, and the
two machines' art were never the variable — which is worth stating because `PC-01` is the neighbouring
ticket and the obvious reading of "the Forge reads and the Drill does not" is that the Forge is better
drawn. It is not. It had one word of luck in a conditional.

Supporting, and deliberately smaller: `Visuals._cold_iron` subtracts value (0.22) and saturation (0.18)
from an **idle** casing. Subtracted from idle rather than added to working, because `scenes/visuals.gd`
already records an A/B decided against brightening — it costs glyph contrast. The working look is
byte-identical to before this change.

**Three things the measurement forced, none of which is the fix:**

- **`MOTION_MARGIN` was a coin toss.** At 2.0 the Drill measured 1.68, 1.94, 2.01, 1.41, 2.04 and 2.43
  across six runs of unchanged code — *the verdict flipped between runs while the subject never moved.*
  Now 3.0, chosen from a measured gap with both sides written down: passing subjects sit at 4.4× and up,
  the pre-fix Drill at ~1.9×, and any threshold in (2.5, 4.0) separates those two populations stably.
- **The ignition flare is a permanent reported column, not a shutter moment.** Capturing at the instant
  `machine_status` first says `working` photographs the Forge's ember ramp — 253/255 with 95% of the cell
  clipped — and stopped-luma swung 248.8 → 48.8 between identical runs. I sent that 253 to `c1` as
  corroboration of a tonemap bug before I noticed my own shutter was the cause, and had to withdraw it.
- **The same shutter error, made twice.** The Generator reported the renderer as idle at the working
  state on every run. `_machine_active` beside the captures was still sampled at the flip instant after
  the captures had been moved to steady state. `_status_generator` calls a generator working the moment
  it *holds* coal; `_machine_active` asks whether it is *burning* it. The layer now asserts the two
  predicates agree at steady state, **both directions** — nothing in the repository had ever made them
  agree, and `_machine_active`'s default arm (`_held > 0 or progress > 0`) is a guess about every
  behaviour added after it was written.

**What this does not close.** `PC-01` — silhouette identity — is untouched: the machines are still a
casing and a glyph, and a Drill still has to be read rather than recognised. The family is proved on
three subjects; the layer names the other three every run (Crusher `no_power`, Spur `unlinked`, Gear Mill
`no_input`) rather than reporting on whichever cooperated and calling that the family. Torches
(`sim.torch`) and conduits (`sim.conduit` — *"a placed layer, not a machine"*) are lit by their own loops
and were checked, not assumed, before the gate was made universal.

### `PC-01` — `SHIPPED` (`P5a`, 2026-08-18, `c2`), with the half it cannot reach stated

The ticket said *"Forge hardware is tiny and generic relative to its text badge"*, and the code agreed with
it in writing. `Visuals.draw_machine_casing`'s header quotes the audit that filed this and answers it
exactly: *"Every machine in the game was the same 30x30 flat square in a different hue with an icon on it.
Hue and icon are how a toolbar distinguishes its entries; they are not how a world distinguishes its
objects."* What followed was a **lighting** model — top catch, bevel, plinth, rivets. It is good, and it
made the square read as an object without making it read as a *particular* object. **The diagnosis was
accepted and the silhouette half was never built.**

Measured by `tools/check_machine_identity.gd`: glyphs off, light pools off, every body painted one grey,
and the comparison run between **occupancy masks**, so nothing but geometry can register.

| | before | after |
|---|---|---|
| mean pair difference, 190 pairs | 0.093 | **0.252** |
| tightest pair of different kinds | 0.000 | **0.036** |
| machines whose body was their own shape | 1 of 20 | 20 of 20 |

The one machine that already had its own outline was the Spur, and only because a Head deliberately draws
no casing at all.

**THE FIRST VERSION MEASURED BETTER AND LOOKED WORSE.** Carving each machine into two and three sub-bodies
took the mean to **0.352** — a real, large, correctly-measured gain — and the play-zoom capture was
unambiguous the other way: the machines read as *broken*, not as different. Every part carried its own
bevel and outline, so a 32px cell filled with internal seams; the glyph shrank to fit the largest surviving
part and clipped; and the solid block of registry colour that makes a machine read as one object at 16
screen pixels was gone. *The gauge went green while the subject got worse.* `history/132` is the A/B that
settled it, and the shipped version is the conservative one: **one solid body, one crown.**

Identity lives in the top band because that is the only part of a machine's outline with sky behind it — a
chimney, two gantry posts, three crusher teeth, a hopper's flange, a pump's spout. Each is an addition
against the background rather than a subtraction from the mass.

Two collisions the measurement found and an eye would not have: the Drift Rig's canopy sat **0.028** from
the Hopper's flange, and the Descent Engine's cap **0.038** from the Generator's dome. The three
placeables — rope, torch, conduit — were one full square each and scored 0.003 from one another.

Everything drawn *on* a machine moved with it. Glyph, badge, progress bar, status lamp, need bubble and I/O
ports were all positioned against the **cell**, which was correct for exactly as long as every machine
filled its cell; with profiles in and nothing else changed, the Forge's input wedge hung in the air above
its chimney. They anchor to `machine_face` now, and `check_casing_light` asserts every face still sits on
one of its own kind's body parts.

**WHAT THIS DOES NOT CLOSE, and it is a design question rather than a drawing one.** At the locked 0.50×
play zoom a cell is **16 screen pixels** and a crown is three of them. This is close to the most a one-cell
machine's outline can carry, and the ticket's premise — that silhouette should out-rank the label — may
want machines that occupy **more than one cell**. That is a footprint decision with sim, placement and
progression consequences, and it belongs to the director rather than to this pass.

**Found while measuring, not fixed:** `ore_vent.tres` declares no `behavior`, so `Visuals.machine_kind`
falls through to the branch that catches the base Forge (*"recipe with empty inputs"*) and the Ore Vent
ships with a furnace's sooty casing and a fire glyph. It is not a furnace. Fixing it needs a glyph, which
is art rather than classification.

### `GR-01`–`GR-07` — `P4` closure, and the two that were already answered

**The first job was not to fix these but to find out which are still true.** `UI-01` in this same programme
turned out to be aimed at a property the code does not have, and two of these read the same way on
inspection. Measured by `tools/check_grapple_reads.gd`, which is the visual half of a tool that already had
`check_grapple` — and every number in that layer is a velocity, so not one of them would move if the rope
were drawn as a magenta line with an arrow on it.

| ID | status | what the measurement said |
|---|---|---|
| `GR-01` | **`SHIPPED`** | Subsumed by `GR-05`. The lead was eleven evenly-spaced dashes running the whole throw — which is how a CAD package indicates a distance and how a debug build draws a raycast. It is a stub off the hand now, fading along its length. |
| `GR-02` | **`ALREADY SATISFIED`** | `_draw_aim_ghost` returns early while `grapple.live()`, so aim and rope are never on screen together. **0.998** of the corridor between hand and anchor is drawn by one state and not the other. Nothing to do. |
| `GR-03` | **`SHIPPED`** | The one the code appeared to have answered. `_draw_cord` bowed the line by `slack() * ROPE_SAG` — tension as form, not UI — but `ROPE_SAG` was a flat 26px **regardless of how much line was out**. Measured as a share of the rope's own chord: **0.013 at 0.55 slack against 0.012 bar-taut.** The same picture. Sag is now `d·√(3s/(8(1−s)))`, capped at 0.42 of the chord: **0.237 against 0.054.** No physics changed. |
| `GR-04` | **`REPRODUCES` — escalated, not tuned** | Measured on real surface ground with one solid cell alone in the sky: on dark rock the whole preview adds **~15 levels** of edge over ~1600 pixels; on open sky the **endpoint mark alone carries ~208** over ~200, against a miner whose own silhouette step is **87**. The ticket is right and its diagnosis is off by one element — the lead is quiet everywhere, and it is the ring that is loud. `AIM_SHADE` is a near-black stroke at 0.55 alpha whose own comment explains it: *"a dark backing ring, so the mark survives pale rock too."* Tuned for the worst background, drawn on every background. **Reported, never asserted, and put back after tuning:** the ticket's approach is *"state-based alpha"*, which is a design call, and the two numbers a floor would compare are not the same quantity (an opaque body's step against its background, versus the contrast a two-tone ring carries within itself). |
| `GR-05` | **`SHIPPED`** | The preview **inked 0.50 of the throw**; it inks **0.16**. What the preview is for is the endpoint, and that is entirely in the ring. The trace is untouched, so acquisition is exactly as reliable — `GR-01`'s stated constraint. |
| `GR-06` | **`DOES NOT REPRODUCE`** | *"the guide rivals the miner silhouette."* At the 90th percentile of edge strength the miner reads **87.5** levels against the preview's **42.5** — better than 2:1 in the miner's favour, and that was true before the lead was shortened. The complaint is real about attention and not real about contrast, and it is the one ticket here whose remedy would have made the frame worse. |
| `GR-07` | **`OPEN` — human** | *"Direct human movement feel is final authority."* Not a harness question by its own wording. |

**Eight instrument defects, each a way of measuring something adjacent to the question:**

1. **The lamp is aimed.** Isolating the preview by parking the cursor on the miner's hand also swings five
   and a half cells of light. Excluding a lamp-sized disc then blinded the layer to the near field — the
   only place a shortened lead lives — and it reported 0.04 of the throw inked while seeing the endpoint
   ring alone. The reference frame suppresses the preview instead, cursor unmoved.
2. **A noise floor sampled over a shorter interval than the signal is not a noise floor.** Two back-to-back
   reference captures called a bobbing marker and twinkling ore perfectly still. And no temporal control
   can remove a thing that was in neither reference — that answer was spatial, a corridor along the throw.
3. **`reach` was the wrong number, and a change that plainly worked is what proved it.** Shortening the
   lead moved `reach` by nothing, because the endpoint ring is at the far end and always will be.
4. **A difference metric cannot answer a single-frame question.** Counting pixels that differ between slack
   and taut said yes for the flat rope as loudly as for the hanging one (3537 against 4540) — displacing a
   line by more than its own width changes a similar number of pixels whether the displacement is 14px or
   200. `GR-03` asks about **one** frame, so the shipped measurement is bow: the cord masked by its own
   colour, at the 99th percentile of its offsets from its chord. Reproducible to three decimals, where the
   differencing version swung 0.24 to 0.31 on identical code.
5. **A tutorial bubble appeared between the reference and the shot.** Teleporting to the surface lands the
   body in the air, which fires the CHAIN IT lesson — a frame-wide high-contrast plate with its edge
   straight through the throw corridor. That is where *"the preview reads 194 levels"* came from: a number
   that would have confirmed `GR-04` on the strength of a hint.
6. **`_edge_p90` reads the step UNDER the mask, not the step the mask ADDS.** Correct for the miner, who is
   opaque and whose silhouette is entirely his own; wrong for a thin translucent line, whose reported step
   belongs to whatever it was drawn across. Underground that is flat dark rock and it never showed.
7. **A control sampled at the signal's own period is blind by construction.** The body's idle animation
   lives in the corridor a few pixels past the hand, and the two references are 38 frames apart — an idle
   cycle near that period matches in both while differing in the shot between them.
8. **A measurement labelled "against calm sky" was taken against a tree.** The first surface shot aimed at
   empty air; the trace stopped on the nearest trunk and the ring landed a cell from the miner's head
   against foliage.
