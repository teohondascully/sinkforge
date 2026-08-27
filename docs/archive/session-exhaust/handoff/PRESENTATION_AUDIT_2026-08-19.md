# Presentation audit, 2026-08-19 — cross-checked against the ticket corpus

**UNCOMMITTED ON PURPOSE.** Decide whether this belongs in the repo before adding it.

Two read-only passes, run independently and merged here:

- a **pixel pass** — 25 frames read (21 in-world, 4 menu-over-world) plus 7 magnified crops, with the worst findings checked against source;
- a **corpus pass** — all 81 tickets (`UI-01`–`15`, `TR-01`–`10`, `SF-01`–`07`, `GR-01`–`07`, `PC-01`–`06`, `MNU-01`–`35` + `29a`) read across `VISUAL_TRIAGE.md`, `VISUAL_RECOMMENDATIONS_SURFACE.md`, `MENU_MATRIX.md`, `PRIORITY.md`, `FEEL_GAP.md`, `DIRECTOR_BRIEF.md`, `LODE*.md`, `CAPTURE_MANIFEST.md`, the `handoff/` set and both `media/*/README.md`.

The point of merging them is the third column below: **which of these is already written down, and which is genuinely new.** Roughly half the pixel findings are new.

---

## 0. Read this before trusting any row

**The capture set is stale.** 20 of the 56 root `_moment_*.png` are stamped **17 Aug 14:06**, two days behind HEAD. Genuinely current in-world frames are `_diag_water.png` (19 Aug 18:21), `history/148` (19 Aug 18:35), `history/149`–`150` (19 Aug), and the `_moment_{dashboard,quiet,counter,*_full}.png` set (18 Aug 04:33–04:51).

**A finding seen only in the 17 Aug set may already be fixed.** Rows below are marked `[STALE]` where that applies. `PRIORITY.md:1063` already calls this out — *"treat stale canonical captures as a program blocker for visual acceptance"* — and `CAPTURE_MANIFEST.md:71-80` goes further: the archive spans **four renderer cohorts**, and two frames with different renderer signatures "are pictures of different builds and are not comparable."

**Re-shoot before acting on anything marked `[STALE]`.** That is cheaper than fixing a defect that no longer exists.

---

## 1. Resolve this one before writing any code

**`GENERA GENERA GENERATOR` — machine nameplates overdraw each other mid-word.**
`_moment_drift.png` x≈1090–1270 y≈310–330, verified at 5×. Three adjacent Generators each draw an opaque nameplate over its western neighbour's tail; the strip reads `GENERA GENERA GENERATOR` with the `A` sliced vertically. One row down, three identical machines report `19`, `19`, `197` — the first two are `197` with the `7` eaten. A player concludes two generators are broken. `_moment_chain.png` is the same at six machines: `SPUR SPUR DRILL SPUR SPUR SPUR`.

**The evidence and the source disagree.** `world_renderer.gd:2759` `_plan_machine_labels()` already contains a run-collapse (`SPUR ×5`) and a two-shelf packer, in-tree since `c913e57` (08-16 23:04) — which *predates* these captures.

So exactly one of these is true:

1. the collapse is not firing for cell-adjacent machines (a live bug), or
2. both captures are from an older build than their timestamps imply (a capture-provenance bug).

**Find out which first.** Either way the durable fix belongs in `_draw_machine_label` (`world_renderer.gd:2799`): if a planned plate would overlap a claimed span, **drop it entirely rather than draw it truncated**. Never draw a plate narrower than its string.

---

## 2. Findings NOT already in any ticket

Ranked worst-first. Grades are the pixel pass's.

| # | Finding | Where | Grade |
|---|---|---|---|
| 1 | Nameplates overdraw mid-word (§1 above) | `_moment_drift.png`, `_moment_chain.png` `[STALE]` | SHIP-BLOCKER |
| 2 | **Layer banner's drop shadow is an ~840×130 black cloud** across the daylight sky — no falloff limit. Invisible underground, ruinous above. Visibly desaturates the sun halo at (680,435) and dirties the gear prop. It is the loudest artifact on the two prettiest screens | `_moment_boot.png`, `_moment_scarp.png` x≈545–1385 y≈180–315 | SHIP-BLOCKER |
| 3 | **Axis-aligned dashed lattice over the rock** at ~150–170px pitch, full frame height, **crossing carved-out air as well as solid rock**. Uniform 1px, uniform dash, uniform grey. `history/121` is titled *"rock stops drawing its grid"* — it is back, or it never left | `_moment_drift/head/lode/refuse.png` | SHIP-BLOCKER |
| 4 | **Settings opens on top of the Bazaar** — four z-layers (world, Bazaar PACK, Settings, un-dimmed HUD) all readable at once. No shipped game reaches this state | `history/150` (**19 Aug, current**) | SHIP-BLOCKER |
| 5 | **Orphan `F` in the corner of every menu.** The gameplay keybind strip is not suppressed when the Bazaar opens; the rail covers it from x=48, leaving a half-cut `F`. Same at top: depth-chip plate pokes out at x≈31–47 y≈22–87. On all four tabs | `_moment_{works,pack,bench}_full.png`, `_moment_counter.png` | SHIP-BLOCKER |
| 6 | **Solid magenta bar across the map** — 8px, fully saturated violet, full width, aligned to *neither* adjacent boundary, where every other boundary is a 1px hairline. Reads as a corrupted scanline | `_moment_map.png` y≈665–675 | SHIP-BLOCKER |
| 7 | **The map's title strikes through four of its own labels.** `THE CLAYBAND` at ~60px across the map body overprints `TOPSOIL`, `0 m`, the small `THE CLAYBAND` row and `10 m` — while 110px of empty panel sits directly above where the title belongs | `_moment_map.png` x≈670–1250 y≈255–315 | SHIP-BLOCKER |
| 8 | **Grass renders twelve metres underground**, inside the dug mineshaft. Surface grass decal applied to underground platform tops. Same frame: the shaft is a flat untextured grey-brown rectangle with square corners amid heavily textured rock | `history/148` (**19 Aug**) x≈800–1120 y≈565–575 | BAD |
| 9 | **The PACK tab icon is a padlock** — shackle, body, keyhole — and renders *gold and filled* when active, which universally means "locked". The icon for "your stuff" says "you can't have this." `BENCH` is a hamburger glyph | all Bazaar frames, left rail | BAD |
| 10 | **Machine status LEDs are blown out by the scene light** — five machines in the same state read as five different colours in a torch-lit room. A status indicator subject to the light budget cannot report status. Draw it *after* the light pass at fixed value | `_moment_chain.png` | BAD |
| 11 | **`889` printed unplated across a machine's face** in ~28px white, bleeding into the neighbour's status dot. No units, no icon, no plate | `_moment_chain.png` (1200,487), `_moment_head.png` (1195,485) | BAD |
| 12 | **Two numbers per hotbar slot in identical typography** — keybind index top-left, stack count bottom-right. Slot 3 reads `3` … `11`; the single-slot surface bar reads `1` … `1`. The count plate is `cw + 4` against a 30px well, so 3-digit counts overflow the border (`hud.gd:3353`) | every in-world frame | BAD |
| 13 | **The item name plate hangs 38–45px off the hotbar's left edge.** Mechanism confirmed: `hud.gd:3367` centres a ~62px string on a 30px well, so `(SLOT - lw) * 0.5 ≈ -16`. Whenever the selected slot is at either end — at spawn it always is — the plate overhangs. Fix is one clamp | `_moment_delve/room/swing.png`, `history/148` | BAD |
| 14 | **Dashboard does not dim the world**, and splits one widget group across its z-order: the `Wood Pickaxe` label reads *through* the panel at ~30% while the hotbar well below draws *in front* at full brightness. `0 working` is in alert orange on a fresh save where nothing is wrong. `2 0▸` is uninterpretable | `_moment_dashboard.png` | BAD |
| 15 | **World tooltips are corner dialog boxes** — a ~750×150 panel top-right for eight words, with no connection to the object it describes (ore face centre-screen, reticle at (1080,540)). Uses a fifth distinct plate style | `_moment_lode.png`, `_moment_refuse.png` | BAD |
| 16 | **Keybind strip survives modals and reflows.** Unplated text, no key caps. `history/150` shows it as `F hook · Q drop · M map · H keys` with `E pack` dropped, so every remaining item shifts horizontally | every frame, bottom-left | BAD |
| 17 | **The hotbar resizes and re-centres on every pickup** — 1 slot at spawn → 9 by `history/148` — so the whole bar slides as you play. `hud.gd:3281`'s comment defends it ("a trailing empty slot reads as broken"). Terraria, Factorio and Minecraft all ship a fixed bar; a moving anchor is more disorienting than an empty well | `hud.gd:3281` | BAD |
| 18 | **Two identical rails on screen simultaneously** — Bazaar's `1 PACK/2 WORKS/3 BENCH` and Settings' `1 AUDIO/2 CONTROLS/3 FEEL`, same geometry, same numbering, 260px apart. In both, the index digit overlaps the tile's top-left corner | `history/150` | BAD |
| 19 | **Flat maroon slab with zero texture**, hard vertical edges, running off-frame, while every surrounding surface is mottled. Reads as a missing texture. Same frame: the gear prop is a 350px wheel in the sky with no mount, plus a detached grey L-bracket at (1195–1245, 590–625) | `_moment_scarp.png` x≈1130–1450 y≈760+ | BAD |
| 20 | **The layer banner's colour is tinted per layer**, so legibility varies by where you are: `THE CLAYBAND` is gold on dark (fine), `SHALE REACH` is pale grey on near-black (weak) | `_moment_haul.png`, `_moment_stain.png` | POLISH |
| 21 | **`tier 2` / `tier-1` — data-model vocabulary in player copy** (`too hard — the Stone Pickaxe (tier 2) bites it`) | `_moment_refuse.png`, `_moment_pack_full.png` | POLISH |
| 22 | **Em-dash-mid-sentence is a house tic** across every detail plate, and it makes the HUD read like a design document. `carrying 64 · 640 gathered all told` should be `Held 64 · Mined 640` | all detail plates | POLISH |
| 23 | **Three names for the surface visible at once**: `OPEN SKY` (chip), `THE SURFACE` (banner), `TOPSOIL` (subtitle *and* map row) | `_moment_scarp.png` | POLISH |
| 24 | **The currency chip strip duplicates the grid 200px below it — in a different order** | `_moment_counter.png` | POLISH |
| 25 | **The hotbar's decorative 4px gold top bar reads as a completed progress bar** and is not one | `_moment_delve.png` y≈884 | POLISH |
| 26 | **Drop particles are bare 4px white squares** (six in a vertical line at x≈818) — they read as dead pixels | `_moment_haul.png` | POLISH |
| 27 | Stray ~15px pure-blue square in solid rock; clipped glyphs sliced by the top edge; chunk seam with a green sliver at x=0–70 | `_moment_delve.png` (10,262), `_moment_swing.png` (1113,15), `_moment_stain.png` (1275,10), `_moment_boot.png` | POLISH |

---

## 3. Findings that ARE already ticketed — with what the pixel pass adds

Do not re-file these. Several carry new evidence that changes their status.

| Finding | Existing ID / status | What is new |
|---|---|---|
| Objective banner overprints the depth chip and FORGED counter (`25 m SHALE RE`, `ORGED 0`) | `FEEL_GAP.md:1108-1112` records this as **fixed** — "now measures free span, clamps, ellipsizes" | **Either a regression or an incomplete fix.** And the *opposite* failure ships simultaneously: `_moment_room.png` ellipsises the instruction itself — `…(face it, press…` — so the actual key is unreadable. `[STALE]` — re-shoot first |
| Objective subtitle sliced horizontally by the modal's top edge | `MNU-07` **OPEN**; `MENU_MATRIX.md:764-768` calls it "the most visible thing wrong with this screen" | Confirmed still live on **19 Aug** frames (`history/149`, `150`), plus the hotbar poking out below at (890–1030, 960–1010) |
| Depth chip and layer banner contradict each other | `media/baseline/README.md:163-168` — "recorded as an observation, not a defect; needs a human ruling" | **Six frames tabulated**, and `history/148` (current) shows the banner announcing `10 METRES DOWN / THE CLAYBAND` while the chip reads `7 m TOPSOIL` — announcing a layer the player already climbed out of. Stronger than "observation" now |
| Water is a rectangular slab | `T3.6` **OPEN** | Newest in-world frame (`_diag_water.png`, 19 Aug): hard vertical sides ignoring the cavity, draws *in front of* rock top-right, and **only 1 of 3 water bodies has a surface line** — a body with no surface reads as a coloured wall |
| Two distinct items render as the same grey box | `T3.4` **RE-VERIFIED 2026-08-18, REPRODUCES** (`deepslate`/`iron` at dE 1.0, IoU 0.72) | Wider than the ranked pair: icons are *darker than the well they sit in* (`UI_SLOT` = `rgba(.11,.12,.16)`). `_moment_pack_full.png` row 4 cols 1–8 are all near-black on dark. Suggests a **minimum-luma floor** on icon fills, not per-pair fixes |
| PACK's fresh-game dead space (460px of black, ~40% of panel) | `MNU-11` **no work** | **Root cause found in source:** `_pack_ledger` (`hud.gd:1835`) early-returns when `production_rates()` is empty — which at game start it always is. The widget designed to fill that space fills nothing, silently. This is an *error path returns the passing value* instance |
| Status labels styled as disabled buttons; `64/3` cost chips | `MNU-18` **OPEN/deferred**, `MNU-20` **OPEN** (already fixed one `need/have` inversion) | `64/3` parses as "64 out of 3"; `_moment_bench_full.png` shows `64/2` on an **already-researched** node. `IN HAND`/`RESEARCHED`/`BUILD ENTER` share one pill — two states and one action, indistinguishable |
| Four reticle styles + a 🚫 gizmo floating detached in the rock | `UI-11`, `UI-12`, `UI-13` all **untouched** | Enumerated: plain white circle, pale circle + 4-point star, gold ring-with-dot, red X-in-box. None is a designed mark. The prohibition marker is a 1px circle with a diagonal slash at `_moment_lode.png` (835,105) |
| Tech-tree: green means two things, hand-drawn bracket connectors | `MNU-22`, `MNU-23`, `MNU-24` all **no work** | **Node labels auto-shrink**: `Automation`/`Crosscutting` at ~20px beside peers at ~24px — the type scale breaks on the two longest names |
| `PAUSED (P)` chip floating outside every panel | Recorded **inside `UI-07`'s SHIPPED cell**: "`PAUSED (P)` and the arrival plate are both `critical` and both aimed at the same strip" | It is redundant — an open modal *is* the pause — and at (30,185) it aligns to nothing. A known-unfixed collision living inside a closed ticket |
| Two tutorial systems firing into the same pixels | `UI-01` **REFRAMED — still open** | `_moment_swing.png` y≈300–410: the GRAPPLE lesson renders *underneath* the layer banner, both mid-fade, both illegible. No arbitration between the hint system and layer-announce |
| Five plate treatments on one screen | `MNU-01`, `MNU-05`, `MNU-33` all **no work** | Enumerated: depth chip (border all sides), objective banner (top rule only), hover tooltip (pale-blue border, square corners), hotbar (grey-blue + gold top bar), world tooltip (fifth style) |
| Deep frames carry information in ~8% of the screen | `T3.1` gate 4 **NOT READY**; `PRIORITY.md:1577-1601` — 59–76% of on-screen rock is below readable luma | `_moment_stain.png`: the lit, information-carrying area is ~640×250 of 1920×1080 |
| Capture set is stale | `PRIORITY.md:1063` — "a program blocker for visual acceptance" | Quantified: 20 of 56 root moments at 17 Aug 14:06 |
| `Period` instead of `.` on the CONTROLS page | not ticketed | **FIXED** in `1f0e478` — plus a keycap table for all punctuation/named/keypad keys, kept injective because `_spec_conflict` compares these strings |

---

## 4. The process finding

**The tutorial bubble had already been through a ticket, and shipped.**

`UI-06` asked for *"a capture-reviewed max height/coverage for non-modal lessons"* and warned in its own acceptance line: *"Do not treat panel area alone as an aesthetic score."*

What shipped was `LESSON_MAX_H = 61.0`, and the comment above it said exactly what it was:

> **61px is three drawn lines at size 11, and it is where the game already is**

A ceiling measured from the artifact cannot be failed by the artifact. Nineteen lessons were checked against it, all passed, and the number proved only that the strings had not grown since the day the constant was written. The guard was real; the property it guarded was not the one the ticket asked for. `UI-05`/`UI-06` are both marked `SHIPPED`; `UI-01` (placement/occlusion) is `REFRAMED — still open` and is the live one.

Fixed in `69b49bd` — 8pt over a 176px wrap, sixteen lessons rewritten to one line, tallest 61px → 47px, 3.92% of canvas, ceiling lowered 61 → 52.

**The generalisation, from the corpus pass:** several other `SHIPPED` statuses do not describe a shipped state.

- `MNU-06` — SHIPPED, and the same row says *"treatment: not attempted"*; 9 of 29 call sites moved.
- `MNU-27` — SHIPPED in the index; the ledger it points at reads *"SHIPPED (the clipping), OPEN (the rest)"*.
- `MNU-32` — SHIPPED for selection marks only; text contrast and focus-visible remain.
- `GR-01` — SHIPPED because `GR-05` covered it, not on its own evidence.
- `T3.1` 6a — "renderer gate green" in one doc, *"CLOSED ON MEASUREMENT AND NOT CLOSED ON PERCEPTION"* in another.

`OVERNIGHT_AUDIT_2026-08-18.md:153` already prescribes the remedy: require every shipped visual claim to state whether it is **structural-test-verified, pixel-verified, human-reviewed, or inferred.** No ticket carries that label yet. Adopting it would have caught `UI-06`.

---

## 5. Ticket-hygiene defects worth an hour

Found by the corpus pass; all are documentation, none are code.

1. **`MNU-29a` is SHIPPED and OPEN simultaneously** — `VISUAL_RECOMMENDATIONS_SURFACE.md:152` vs `MENU_MATRIX.md:770`.
2. **`MNU-30`/`31`/`32` are listed among "tickets with no work"** three sections after they were shipped in the same file — `MENU_MATRIX.md:860`.
3. **`MNU-19`'s premise is contradicted by the matrix that measured it.** The ticket calls the "16 more wait behind research" line a modal instruction; `MENU_MATRIX.md:259-261` says *"That is the correct pattern… The redesign must not lose it."*
4. **`TR-09` is closed and reopened in one file** — `PRIORITY.md:1849` vs `:2083`.
5. **`T3.2` is closed in the audit and open in its own body text.**
6. **`UI-01`'s falsified premise still stands uncorrected** in `VISUAL_TRIAGE.md:39,197` ("screen-centred").
7. **Two incompatible status vocabularies**, and the statuses actually in use (`PROVED`, `REFRAMED`, `ALREADY SATISFIED`, `DOES NOT REPRODUCE`) are terminal in neither.
8. **Ticket count disagrees**: 45 / 80 / actual 81.
9. **`UI-06`'s quoted numbers were two revisions stale** — corrected in `69b49bd`, which also fixed `check_hud_layout.gd`'s `HINT_WRAP + 20` / `250.0` note (that was `230 + 20`; the code is `176 + 16`). Quote the constants, not their product.

---

## 6. Cheapest wins

Both are small and clean up several screens each:

- **Kill the layer banner's blur shadow** (§2 #2) — one draw call. Replace with a 1px hard offset at 60% black, or plate it like the depth chip.
- **Hide the world HUD group under any full-screen modal** (§2 #4, #5, #18; §3 rows 2 and 11) — one `visible = false` on the parent clears the orphan `F`, the clipped depth-chip stub, the sliced objective subtitle, the surviving keybind strip and the `PAUSED (P)` chip.

The one to be careful with is §1, because the source already contains the fix and the evidence says otherwise.
