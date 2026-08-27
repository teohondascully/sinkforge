# Overnight director audit — 2026-08-18

**Scope.** I inspected main/remote state, worktrees, director-bus directives, priority documents, committed
overnight changes, visual/evaluation artifacts, and both trace logs. I did **not** run Godot or the full
harness independently: the shared machine remains reserved for working agents. Results below are therefore
committed/trace evidence unless explicitly described as an audit observation.

## Executive verdict

The night produced real player-visible progress, not only tooling:

- teaching is smaller, persistent across launches, and quieter during movement;
- the arrival ceremony no longer selectively erases ropes and glints;
- shallow Bazaar screens no longer always consume the whole display;
- grapple preview and rope tension are less debug-like and more physical;
- machine state and silhouettes are more legible;
- interior rock now has a renderer-side cue that clears the pixel measurement gate;
- the first honest menu matrix exposed reproducible defects instead of judging one flattering midgame frame.

The central design blockers remain open:

1. **T1.0:** manual face-to-spine haul pain still does not exist; Freight Winch remains blocked.
2. **T1.0b:** seed pacing is genuinely fragile after correcting fixture mistakes; floors must not move.
3. **T3.1:** rock is closed on pixel measurement, not on human perception.
4. **T2.1m:** menu work is at evidence/prototype stage, not a complete overhaul.

This is a productive **between-milestones** position. The first visual cleanup pass has shipped; the next
visible milestones are a quieter opening, a real menu-system redesign, and terrain material grammar. The
Freight Winch is still the next major gameplay milestone, but its prerequisite has not moved.

## Repository and delivery health

| Check | Status | Evidence / consequence |
|---|---|---|
| `main` versus `origin/main` | **Synced** | Audit start: 0 ahead / 0 behind. Overnight claims that are on main are also on remote. |
| Working tree | **Active; do not clean** | `docs/MENU_MATRIX.md` and `scenes/hud.gd` are modified by the active menu lane. This audit did not touch them. |
| Worktree safety | **Watch** | Fifteen-plus stale worktrees remain, some hundreds of commits behind main. They are reference material, not merge candidates. T5.9’s re-derive-not-merge rule remains correct. |
| Harness/save isolation | **Improved; not rerun here** | `c6fc29f` fixes `with_machine.sh` failing open to the real save slot; `5279323` requires a declared sandbox for fixture `user://` writes. |
| Full-suite claim | **Qualified** | Traces report 89 PASS / 0 FAIL / 0 SKIP sweeps with exit 4. Do not treat this audit as independent headed/performance certification. |

## What changed overnight

### Visual program and evidence discipline

- **P0 shipped** (`cb2b34f`): seven provenance-labelled, noncanonical baseline frames under
  `docs/media/baseline/`. It found two capture/instrument defects before visual conclusions were made.
- Visual phases were renamed **P0–P6** to avoid collision with `VISUAL_TRIAGE.md`’s V1–V5 roots.
- The granular visual queue remains in `VISUAL_RECOMMENDATIONS_SURFACE.md`; `PRIORITY.md` contains only
  milestone parents, avoiding another competing todo list.
- Menu evidence expanded to twelve captures across fresh, midgame, full, unaffordable, actionable, and
  settings states.

### T2.1 and P1 — HUD/guidance

Shipped work includes:

- noncritical help hides while the player is moving quickly, with hysteresis;
- one-time teaching persists across launches instead of replaying each boot;
- sapling renewability is shown after first rooting instead of dumped in the instruction;
- lesson height is capped by the same geometry source that draws it;
- every HUD draw helper has an explicit priority class;
- a quiet capture moment now exists, separate from the timed TOPSOIL ceremony;
- ceremony scrim alpha fell from 0.80 to 0.28 while glyph-local shadow retains word contrast; repeated
  readings show rope median disturbance reduced about 65%;
- PACK/WORKS panels now size to shallow content: fresh PACK 91.8% → 54.5% canvas, fresh WORKS 91.8% →
  67.6%; BENCH correctly remains full-height.

Open: `UI-01` was reframed—its hint follows the player rather than being truly centred, but still blocks
the relevant tree. `UI-02` needs a new cursor-proximity predicate. P1 still requires human/director frame
review; green structural checks do not close it.

### Grapple and machines

- **Grapple:** the full-length dashed guide became a short fading hand stub; preview ink moved from 50% to
  16% of the throw; rope sag now responds visibly to payout/tension. Physics was not changed.
- **Machines:** stopped non-furnace machines no longer light nearby rock as though running; per-kind crowns
  raised pair separability. P5a is closed.
- **Open:** aim endpoint ring is too loud on some backgrounds; that tuning is a director/play decision.
  GR-07, human movement feel, remains open.

### T3.1 and terrain grammar

- `7181e04` added a rock tooth. Knockout versus tooth-on measurement moved pooled grain from 61–62% to
  87–88%, with plain interiors at 86%, against unchanged 75% floor.
- This is **not perception closure**. Samples sit near luma 11; a pixel statistic may detect a cue a person
  cannot use. Current-build blind review remains blocked by stale canonical captures.
- P3 found material grammar was effectively surface-only; fine terrain received color but not material
  identity. `89011dd` added per-material grammar to that path.
- P3 also rejected several attractive but wrong mechanisms: nonvisible lit-band treatments, an assumed
  depth-density trend that does not exist, and an easy smooth-hole remedy with poor return.
- Ore glints and player-intent markers were found below the darkness veil and moved above it.

### Menus: evidence, repairs, no overhaul yet

The menu matrix found and corrected real defects:

- SETTINGS had clickable bindings below both panel and screen; it now fits with a hit-rect assertion that
  can fail;
- price chips rendered `need/have` while docs claimed `have/need`; fixed;
- SETTINGS’ translucent plate allowed bright world/tutorial material to read through; fixed opaque;
- fixtures had posed controller-owned state that the live game overwrote, so early screenshots never showed
  a genuine BUILD state; corrected before using them as evidence;
- gold was counted: nine meanings across 29 call sites. One stalled-count colour contradiction is fixed;
  broader semantics remain open;
- accessibility selection-read coverage is committed (`6b60047`).

The menu overhaul is **not shipped**. Most `MNU-*` tickets remain untouched. A selected SETTINGS direction
exists—share Bazaar visual language while retaining its separate settings state machine—but broad work has
not begun. Current dirty `MENU_MATRIX.md` and `hud.gd` show the lane is active.

### Gameplay and evaluation honesty

- T2.3 now drives the real held-input dig path. The valid conclusion is a **rare** hitch: median dig is
  near quiet frames, while roughly 11 of 400 breaks cost about 33ms. Earlier “constant 32–35ms” and “no
  player-rate stall” claims were both wrong.
- T1.0b was widened to eight seeds. Two failures were fixture artifacts where the agent never descended.
  Corrected state: three pass, two marginal, three severe; seed 512 remains 92% silence / 3.0 events per
  thousand frames over a real descent. Floors do not move.
- Blind opening-evaluation readiness correctly says **FIX READINESS BLOCKER**: the actor decision channel
  has direct simulation, coordinate, inventory, objective, and target-oracle access. Prompt wording cannot
  solve gate 6. Seed reliability also blocks fair gate-2 interpretation.

## Priority timeline

| Horizon | Milestone | Status | Closing condition / next action |
|---|---|---|---|
| **Now** | T1.0 face-to-spine haul pain | **Blocked; highest gameplay priority** | C2 completes legal real-dump/cap measurement. No Freight Winch first. |
| **Now** | T1.0b pacing corpus | **Red; diagnosis incomplete** | Re-run corrected descent fixture, separate worldgen scarcity from actor incapacity, especially seed 512. |
| **Now** | P1 / T2.1 guidance quietness | **Mechanically mostly shipped; review open** | Director review of quiet/sapling/grapple/map frames; resolve UI-01/UI-02. |
| **Now** | P2 / T3.1 interior legibility | **Renderer gate green; perception open** | Fresh current-build captures, then zero-context visual review. |
| **Now** | P6 / T2.1m menu overhaul | **Matrix/prototype gate shipped; redesign open** | Review prototype direction; implement one selected system slice, not a reskin. |
| **Near** | P3 / T3.12 terrain grammar | **Unblocked; active investigation** | One dirt→stone treatment that survives normal, 1×, 4×, and rock/void review. |
| **Near** | P4 / T3.13 grapple language | **5 of 7 closed** | Director endpoint-ring decision, then human in-motion GR-07. |
| **Near** | P5a / T3.2 machine state | **Closed** | Do not casually reopen; wider-than-one-cell silhouette is a later design call. |
| **Parallel** | T2.5 repository presentation | **Not started** | Assign the bounded presentation pass. |
| **After T1.0** | T1.1 Freight Winch graybox | **Not cleared** | Requires valid manual-pain evidence and later route/desirability gates. |
| **Later** | Tier 4 lore/world; Tier 5 debt | **Backlog / demand-pull** | Must not displace loop, legibility, or menu work. |

## Decisions that only the director/user should make

1. Is the current quiet frame now player/route-first, or should UI-01/02 continue?
2. After fresh captures, does a zero-context viewer actually read tooth-on rock as rock?
3. How quiet can the aim endpoint ring become before reliable grapple acquisition is harmed?
4. Does the world-space guide ring / 40-second stuck-guidance imperative manufacture desire for blind
   evaluation purposes?
5. Should 41 stale canonical captures be refreshed, explicitly preserved as dated history, or left stale?
6. After valid T1.0 evidence, what generous raw-ore-only capacity shape creates interruption without
   damaging movement?

## Recommendations

1. Keep C2 on T1.0. Do not migrate loop work to C1 just because C1 owns an adjacent measurement tool.
2. Require every “shipped” visual claim to say whether it is structural-test-verified, pixel-verified,
   human-reviewed, or inferred.
3. Treat stale canonical captures as a program blocker for visual acceptance, not archive housekeeping.
4. Do not call P3 or P6 successful because their matrices and instruments exist. Their player-visible
   treatments are the next milestones.
5. Preserve re-derive-not-merge discipline across stale worktrees.

## Bottom line

The project is visibly stronger this morning: quieter teaching, a more physical grapple, truthful machine
state, smaller shallow Bazaar panels, a rock-side cue, and the first credible menu evidence base. It is
not ready to declare the opening solved, menus modern, underground perceptually readable, or the Freight
Winch justified. The next sprint should convert these improved instruments into player-facing decisions,
not seek generic polish.
