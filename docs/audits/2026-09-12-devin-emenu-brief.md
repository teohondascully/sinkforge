# The E-menu: what we decided, why, and how firmly to hold it

Written 2026-09-12 against `main = 4c452f1a`, for Devin.

## 0. How to read this document

This is a **brief, not a specification.** The director approved the design below as a target and
explicitly asked that it not be set in stone: if, with the context you have from the codebase, you think
a different approach is better, take it.

One condition on that. Every conclusion here is tagged with what kind of thing it is:

| Tag | Means | How to treat it |
|---|---|---|
| **CODE** | A ruling already in the shipped codebase, usually with a ledger entry | Changing it changes shipped behaviour. You may still argue for it — say so explicitly and cite what you are overturning. |
| **MEASURED** | We have an observation behind it: an image, a count, a grep | Attack the measurement or the population it was drawn from. |
| **REASONED** | An argument with no measurement under it | The most attackable category. Several of these are load-bearing. |
| **TASTE** | One person's judgment, no evidence | Overrule freely and without ceremony. |
| **OPEN** | We do not know | Yours to answer, or to leave open deliberately. |

If you reject something, **name which claim you are rejecting and which tag it carried.** A different
design that happens to also work is useful; knowing that a REASONED claim was wrong is worth more,
because the same reasoning is about to be applied to four other surfaces.

## 1. What the E-menu is

The player presses E and gets a screen for: what am I carrying, what does the rig want, what is my
factory doing, and what do I do next. It does not exist yet in any form. This brief is the first design
pass over it.

Two properties that shape everything:

- **The world keeps simulating while it is open.** It is not a pause screen. `CODE`
- **The factory is expected to scale to roughly five hundred working components.** This is the
  director's stated assumption and it is the single constraint that decided the design. `CODE`

## 2. How we got here — the method, so you can judge the evidence

The director wrote a long image-generation prompt and got two mockups back. Both looked like
infographic panels. Rather than refining them, we did this:

1. **Read the shipped code first**, and found that the prompt described a different game than the one
   that exists (§4 below). Three factual divergences, one of them the cause of the infographic feeling.
2. **Wrote six short prompts testing six genuinely different directions**, one screen each, with an
   identical fixture so they would be comparable. These are committed at the repo root as
   `EMENU_A_THE_LOAD.md` through `EMENU_F_AT_THE_MACHINE.md`, plus `EMENU_PROMPTS.md` (the index).
3. **Generated all six**, then added the director's 500-component constraint, which re-sorted them.
4. **Wrote two more at scale**: `EMENU_G_THE_SPINE.md` (the composite) and
   `EMENU_H_CUTAWAY_AT_SCALE.md` — **H is a deliberate control**, generated to try to falsify the
   claim that whole-factory diagrams die at scale.

All eight renders are in `docs/media/emenu/`. Read them beside this document; several conclusions here
are only checkable by looking.

**The control is the part of this method worth keeping.** H came back *better* than predicted and forced
a correction to the conclusion (§3, row 4). A design argument that survived a deliberate attempt to kill
it is worth more than one that was merely preferred.

## 3. The findings

| # | Finding | Tag |
|---|---|---|
| 1 | The pack has a cap (`bulk_cap: 90`, `inventory_slots: 10`) and the original mockups omitted it. An inventory with no scarcity is a list, not a decision. This is most of why they read as infographics. | `MEASURED` |
| 2 | The cap taxes freight, not kit. Machines, rope and torches ride free. The menu's primary structure should be that split. | `CODE` |
| 3 | A depth-indexed strip is O(depth); a factory diagram is O(machines). At ~475 machines the strip found all four bad bands before a digit was read. | `MEASURED` |
| 4 | The whole-factory cutaway does **not** become illegible at scale — it becomes *uninformative*. Three red machines among hundreds of identical comb teeth. It answers "look what I built" and fails "what is wrong". | `MEASURED`, and this **corrects** the earlier prediction that it would become unreadable |
| 5 | Therefore the cutaway survives with a different job (a Presentation view), rather than being deleted. | `REASONED` |
| 6 | The band count column is an unplanned win: read down it and you get a density profile of your own factory. | `MEASURED` |
| 7 | At ~475 machines the mine stops looking like a mine and starts looking like shelving. See §8. | `MEASURED`, consequences `OPEN` |
| 8 | 500 components is ~16 machine types placed 500 times. The scale constraint costs almost nothing in art. | `MEASURED` |
| 9 | The renderer is `_draw()` primitives, not sprites and not SVG: 310 primitive calls to 13 texture calls across `view/`. This, not the menu design, is the quality ceiling. | `MEASURED` |

## 4. Three things the code says that the first design pass got wrong

Listed because the same mistake is available to you. All three were found by reading shipped source, not
by reasoning about the game.

**The cap is real.** `data/player/pack.yaml`: `inventory_slots: 10`, `bulk_cap: 90`. `hotbar.gd` already
draws a PACK FULL chip against it. The original prompt said *"no invented weight limit"*.

**The split is real.** `sim/items/pack.gd` states it in capitals: *"THE CAP TAXES FREIGHT, NOT THE KIT.
Ore, rock and refined goods are bulk; a placeable machine item is not."* `Pack.is_bulk_item` is
`not MachineDef.exists(item)`, and `data/machines/` contains `rope.yaml` and `torch.yaml`, so those ride
free too. In the fixture used throughout (Clay 24, Coal 12, Iron-bearing ore 8, Iron ingot 3, Glimmer 1,
Torch 4, Rope 2, Plate Press 1) that is **48 of 90** carried across five taxed rows and three free ones.

**The join between pack and world already exists and nobody used it.** `view/hud/wanted_rule.gd` (D0592):
a machine that is starving wears an upward triangle, and the stack in your pack that would feed it wears
*the same glyph in the same colour*. Its own docstring explains why it is not colour alone, quoting
`status_look.gd`: *"green working against red no-fuel is the single most common colour confusion there
is, with amber starved joining them; for a deuteranope those three lamps were one lamp."*

## 5. The design

Three surfaces, each with a bounded cost as the factory grows, and one demoted fourth.

### 5.1 The Load — the pack `CODE` for the split, `TASTE` for the treatment

Freight and kit as two visually distinct groups, with the cap rendered as a physical thing rather than a
number in a corner. Two treatments were tested:

- A tall stratified gauge, each freight item holding a band sized by its contribution, in that item's
  own ink, with leader lines to the list. `docs/media/emenu/A-the-load.png`. This **read instantly** —
  you can see clay is most of your load before reading anything.
- The same stratification compressed into a horizontal bar under a row of wells.
  `docs/media/emenu/G-the-spine-at-scale.png`. The segments are present and say nothing.

**Stratification appears to need height, not width.** `MEASURED`, n=2, so weak. The split itself is
`CODE`; how you draw it is yours.

### 5.2 The Spine — navigation `REASONED`, with one image behind it

A narrow strip down one edge, indexed by **depth**, not by machine.

- The shaft is divided into bands (20 m in the mockup — that number is `TASTE`).
- Each band carries a count of the machines in it and the colour of the **worst** lamp among them.
- A caret marks where the engineer is.
- Opening a band expands it into that band's machines, each with its own lamp, so the player reaches a
  machine by: find the red band, open it, choose.
- Empty spans are named rather than left implicit — H invented "46 m unworked" and it is better than a
  gap. `MEASURED`, borrowed from the control.

**The argument:** the game is one vertical shaft, so depth is a coordinate that always exists and always
orders. A strip indexed by it is O(depth) and aggregable; a diagram is O(machines) and is not. Factorio
needs a map because it is 2D and unbounded. We are not.

**The evidence:** `G-the-spine-at-scale.png` at ~475 machines. Four bad bands found before reading a
digit. Set it beside `H-cutaway-at-scale-control.png`, which is a competent drawing of the same factory
in which the three red machines are single ticks among hundreds.

**This is the most attackable claim in the brief**, because one image is one image and nobody has ever
touched a spine with their hands. See §8.

### 5.3 The Card — the targeted state `REASONED`

Standing at a machine and pressing E gives that machine's card: its name, its status in its own colour,
a small elevation with its real ports marked, what it holds, what it wants, and one verb.

Neither of the director's original mockups drew this state, and it is likely the **most frequent** use of
the menu. It is also O(1) in factory size, which is why it matters more at 500 components than at six.

`docs/media/emenu/F-at-the-machine.png`. Note this render for its finish as much as its layout — it is
the clearest picture in the set of what the game could look like (§9).

### 5.4 The Presentation view — the demoted cutaway `REASONED`

Keep the whole-factory cutaway, but give it the job it is actually good at: being looked at with
pleasure, rarely. Not navigation, not diagnosis. `H-cutaway-at-scale-control.png` is a real drawing of a
real factory and it is genuinely nice; it simply cannot answer an operational question.

### 5.5 Deliberately left out

- **An index by machine type.** At 475 machines "where are my gear mills" is unanswerable by the spine.
  This is a known gap, chosen rather than overlooked, and it is the first thing to add back. `OPEN`
- Sound, drag-to-assign, order history, the full discovery catalogue. All real, all deferred.

## 6. What the code already gives you — measured, with addresses

**The data for the spine is nearly free.**

- `interface/observation.gd:271` — `var map_machines: Array[Vector2i]`, every machine position,
  **unwindowed**. This is already the whole-factory population the spine needs.
- `interface/hub_planes.gd:116-124` — each machine record carries `status`, `power_permille`,
  `progress_permille`, `facing`, `fuel`, `filter`, `stage`.
- `interface/hub_planes.gd:102` — `_fill_metre_planes` already walks *all* machines, so an all-machines
  pass over the sim is precedented and is not a new cost.
- `interface/hub_planes.gd:20-22` — `pack_bulk`, `pack_bulk_cap`, `pack_slots` are already published.

So the spine needs status joined onto the unwindowed machine population and rolled up by band: one new
interface plane, one view file. **The Card needs no sim work at all** — `status` and `fuel` are already
there, and `MachinePainter.need_item` already answers "what does it want".

Note there are now **two machine populations** in the observation: `machines` (windowed to roughly the
screen, which is what `WantedRule` reads) and `map_machines` (all of them). Reconcile deliberately.
Two instruments are not a cover: if the spine and the pack mark ever disagree about whether something is
starving, that is the reason.

**The item and machine vocabularies are already lookup tables**, which is the seam that makes an art pass
cheap: `view/visuals/item_look.gd` is `id -> drawer + purpose`, `view/visuals/machine_look.gd` is
`id -> {kind, color}` with drawers in `machine_glyphs.gd`, and `tests/test_looks.gd` pins the population
against `data/machines`. `ItemLook.PURPOSE` already holds ~35 written purpose lines, better written than
anything the mockups invented — reuse them rather than authoring new copy.

**`hotbar.gd` carries rules that the menu must not contradict.** `CODE`

- *"THE BAR IS A WINDOW ONTO THE PACK, NOT THE PACK"* — it draws only the slots you carry. A trailing
  empty well reads as broken (D0412). Several of the mockups re-added empty wells; that is a regression.
- A stack drained to 0 keeps its number, leaving a gap, so held stacks never move (D0553). This was
  measured: strangers 127-132, four of six fed or selected the wrong stack when the bar reordered.

**There is no menu infrastructure in the NEW build — but legacy already solved it.** `MEASURED`

`UI_MODAL` is declared at `view/hud/ui_theme.gd:41` and used in **zero** non-legacy files. `hotbar.gd`
and `hud_layer.gd` are the entire new HUD: no modal layer, no focus model, no input capture.

Legacy has all of it, and the house rule is `docs/A_PRIME_REFACTOR_PLAN.md` §1 (the A-prime decision,
"lift what legacy already solved whole") — **port, do not re-derive; lift the architecture, not just the
leaves.** What is there:

- `legacy/scenes/page_surface.gd` (81 lines) — `PageSurface`, *"WHAT EVERY DRAWN PAGE NEEDS AND NOTHING
  ELSE"*: a page is a plain object drawing onto somebody else's canvas, needing exactly four things.
  Carries `_round_rect`, `_keycap`, `_tracked`, `_rail_slots`, `_modal_vignette`, and a probe hook so a
  layout assertion can read the drawn rectangles back without a display.
- `legacy/scenes/settings_page.gd` (865 lines) — a full worked page built on it.
- `legacy/scenes/machine_view.gd` (726 lines) — *"EVERYTHING THE WORLD DRAWS ABOUT A MACHINE: casing,
  construction animation, status chrome, nameplate, **input and output marks**, and **load gauge**."*
  That is the Card's ancestor, ports and gauge included.

**Read `PageSurface`'s docstring before writing any menu code.** It is a warning written for exactly the
situation the new build is walking into: *"They were written out once per page. `SettingsPage` and
`BazaarPage` held eleven of these each, byte-identical after comments... the arithmetic stops being
survivable at the split this is clearing the way for, where five units would have carried five copies of
the same eleven."* The E-menu is the third page. Port the surface before the first page, not after the
second.

This substantially lowers the infrastructure estimate. It does not lower it to zero: the port has to
land under the new build's layer rules and size caps (§7), and legacy's page took its data straight from
the sim where the new one must come through `Interface.Observation`.

## 7. Constraints that are not ours to waive

Architectural, from `docs/ARCHITECTURE.md` and enforced by `tools/layer_lint/layer_lint.py`:

- **`view` may not reach `sim`.** Everything the menu knows comes through `Interface.Observation`.
  A spine that reads `Machines` directly will fail the gate and should.
- 400 lines hard / 300 warn per `.gd`; 50 lines per function; complexity <= 10. A menu is exactly the
  kind of feature that wants to be one 900-line file. `hotbar.gd` shows the house pattern instead:
  `layout()` decides and returns data, `paint()` transcribes, and both are testable without a display.
- Every judgment call gets a ledger entry, in the same commit for anything touching `core/` or `sim/`.
- Mutation-test any new guard. Reaching a check is not the check firing.

Design rulings with evidence behind them:

- **Never colour alone.** Status is a mark *and* a colour. The spine's bands in the mockup are mostly
  pure fill, which is a defect in the mockup, not a licence.
- **Freight versus kit**, per `pack.gd`.
- **One glyph in two places**, per `wanted_rule.gd` — the menu should extend that vocabulary rather
  than invent a second one.

## 8. What is weak about this, stated plainly

**No human has ever touched a spine.** It is one image. Strangers 127-132 found a hotbar failure nobody
predicted; "band means place" could fail the same way. This wants a blind stranger seat before it is
trusted, and the seat must discover the failure rather than be told what to look for.

**No index by machine type.** §5.5. Known, chosen, first to add back.

**The strip-mine question is unresolved and it is bigger than the menu.** `OPEN` The reason
`G-the-spine-at-scale.png` looks like shelving is not the interface. The stated identity is
*dig-your-factory: solid ore-rich earth you carve into*. At six machines that reads. At 475 the carving
is finished and what remains is a lattice of platforms. **The thing that makes the game beautiful is
consumed by the thing that makes it deep.** This was flagged as an unasked question in
`docs/audits/2026-09-12-devin-vision-brief.md` §9 before an image of it existed; now one does. If 500-
machine factories are later ruled out, a menu designed around them was designed for a world we deleted.
Do not block on this — but do not let it disappear either.

**One image is one image.** Findings 3, 4 and 6 each rest on a single render. They are the best evidence
available and they are not much evidence.

**And the honest one: this design does nothing about the actual quality problem.** §9.

## 9. The art track, and why it may outrank all of the above

The director's own read was that the game "looks basic because it is a lot of SVG". **There is no SVG in
the repo** — zero `.svg` files. What actually renders, counted across `view/`:

```
310 primitive calls  (draw_rect 125, draw_line 68, draw_circle 64, draw_colored_polygon 21,
                      draw_arc 18, draw_polygon / draw_quad / draw_multiline the remainder)
 13 draw_texture* calls
```

Immediate-mode `_draw()`. Every machine, every rock cell, every item assembled at runtime from
primitives. The symptom the director named is real; the mechanism is different, and so is the fix.

**The A/B is already in the build.** `assets/sprites/` holds 18 hand-drawn miner frames — idle, walk x4,
dig x3, jump, fall, land, climb x2, swing, haul, hang — drawn through `miner_draw.gd`. The miner is a
sprite standing in a primitive world. That gap is the whole answer to "how much better can this look".

**The tech is not missing.** Seven shaders already ship: `veil`, `rock_tone`, `rock_grit`, `rock_tooth`,
`post_fx`, `heat_haze`, `erase`. Plus `light_painter`, `light_layer`, `veil_light`, `sky_light`. The
pooled torchlight and lamp bounce that make `F-at-the-machine.png` beautiful are not a technology gap.
There is simply nothing worth lighting yet.

**The budget is bounded by type, not by instance:** `data/machines/` has **16 types**, `data/materials/`
has **11**, `ItemLook` covers ~30 ids. Roughly 16 machines x 3 states + 11 tilesets + ~30 icons — call it
90 authored assets, for a Dome Keeper / SteamWorld Dig tier finish. Five hundred components does not move
that number.

Ordered by perceived gain, largest first — `REASONED`:

1. **Rock autotiling.** Terrain is currently per-cell tone (`base_color` + `grain` + `depth_darken`): a
   grid of coloured cells. Proper corners, overhangs and a distinct cut face is the entire difference
   between a grid and excavated earth. Also closes queue item 21 (cut-face geometry).
2. **~50 machine sprites.** `F-at-the-machine.png`'s Processor against the current glyph, in one frame.
3. **Light, applied to art worth lighting.** The stack already runs; it is currently lighting rectangles.
4. **Motion.** `falling_items.gd`, `particles.gd`, `leaf_drift.gd` exist. Spinning bits, chute flow,
   lamp flicker.

**The recommendation the director approved: treat these as two tracks, and treat the art as the
higher-value one.** A perfectly architected spine drawn in `draw_rect` still reads as a debug view. If
your queue has room for one, take the art.

## 10. How we would sequence it — and why you might not

Offered as a starting position. `TASTE` throughout.

0. **Port `PageSurface` first.** 81 lines, and its own docstring explains why doing it after the second
   page is too late. Everything below sits on it.
1. **The Card first.** Smallest, needs zero sim work, highest frequency of use, and it forces the menu
   infrastructure (modal layer, focus, input capture) into existence against a target small enough to
   get right. `legacy/scenes/machine_view.gd` already has its ports and load gauge.
2. **The Load.** Freight/kit plus the cap. Also small, also zero sim work, and it is the piece with the
   firmest `CODE` backing.
3. **The Spine's data plane.** Status joined onto `map_machines`, rolled up by band. Testable headless
   with no view at all, which is where this codebase prefers to prove things.
4. **The Spine's view**, then a blind stranger seat on it before anything is built on top.
5. **The Presentation view**, last and optional.

A reason you might reorder: if the infrastructure in step 1 turns out to be large, the Load may be the
better first target since it needs no world interaction at all. A reason you might do none of it yet:
§9.

## 11. Questions we would like answered

1. Is the spine right, or is it a clever answer to a question players do not ask? What would you build
   instead, at 500 components?
2. Is there a navigation primitive we are missing because we are anchored on "one vertical shaft"?
3. Does the two-population problem (`machines` windowed vs `map_machines` unwindowed) want reconciling
   before the spine is built on it, or is a documented divergence fine?
4. What is the cheapest honest way to get a human verdict on a spine before committing to it?
5. Is the art track really higher-value than the menu track, or is that an overcorrection?
6. What does a 500-component factory do to the "dig your factory" identity, and is that a reason to cap
   component count rather than to scale the interface to it?
7. Anything in §7 you think is wrong. Those are the rules we are treating as settled, which makes them
   the most dangerous things in the document.

## 12. What to send back

Not agreement. A verdict on each of §3's nine findings — accept, reject, or "the evidence does not
support this either way" — and for anything rejected, which tag it carried and what you would do
instead. Then your own sequencing, with the reasoning visible, so we can see where it diverges from §10
and why.

If you conclude the whole E-menu should wait behind the art pass, say that plainly. It is a live option
and nobody here will be offended by it.
