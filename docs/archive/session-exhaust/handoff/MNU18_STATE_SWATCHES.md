# `MNU-18` — the state swatch family, reviewed

The ledger's verdict on `MNU-18` reads *"DEFER the swatch family. It needs the greyscale and text-only
pass `MNU-32` asks for, and that is a review rather than an edit"* (`docs/MENU_MATRIX.md:589`). This is
that review. It changes no code. It exists so the ticket stops being blocked on an analysis nobody had
run, and so a builder can implement the family without making a second set of design decisions.

**Scope, stated before the findings, because a review with an unstated population reads as a sweep.** The
subject is `scenes/hud.gd` — the counter (PACK, WORKS, BENCH), its detail plate, and the hotbar. The
settings page (`scenes/settings.gd`) is not in it; it has its own controls with their own states and is
under separate work. Colour values are read from source rather than sampled off a frame, for the reason
`tools/check_text_contrast.gd:37-42` already gives: sampling drags in the lighting veil and glyph
antialiasing, and antialiased edges are most of the pixels in nine-point type.

**Every `scenes/hud.gd:LINE` below is against commit `3c85b32`, this worktree's HEAD — not against the
working tree.** The file is being edited concurrently: at the time of writing it carried 103 uncommitted
insertions and had grown from 4136 lines to 4236, and it moved by 100 lines during this review. Past
`_detail_wanted_h` the working-tree offset was exactly +100 (`_works_row` at HEAD 2439 sat at 2539 in the
tree), and it will not stay at +100. Resolve a citation with
`git show 3c85b32:scenes/hud.gd | sed -n 'NNNp'`, or by name — every site below is named as well as
numbered. None of the concurrent edits adds or removes a colour literal, so every value in this document
is current regardless.

---

## 0. The states are not one axis, and that is the first finding

The ticket names five states as if they were five values of one variable. They are not. Four of them are
values of one variable and the fifth is a value of another:

| axis | states | who owns it |
|---|---|---|
| admissibility — can I act on this, and if not, why not | locked, unavailable, affordable/short, buildable | the world and the pack |
| cursor — is this the one thing I am pointed at | selected | `bazaar_row` (`scenes/hud.gd:287`) |

Selection composes with every admissibility state: a locked rung can be selected, a short row can be
selected. A family of five swatches drawn from one channel is therefore malformed before any colour is
chosen — it would have to paint two independent facts with one mark. The family proposed in §4 is four
admissibility marks plus one selection mark that overlays all four.

Two further distinctions the ticket's vocabulary hides, both of which are live in the code:

- **affordable** and **buildable** differ by exactly one bit, `can_craft` (`scenes/hud.gd:150`).
  `ready = can_craft and _can_afford(cost)` at `scenes/hud.gd:2645` and `2662`. A row can be affordable
  and not buildable, and that is the ordinary state of the whole counter whenever you are away from a
  Bazaar.
- **unavailable** is not one state. It is the union of "not standing at a claimed Bazaar" and "the pack
  is short", which the code keeps apart at `scenes/hud.gd:2647` and `2663` and the player cannot.

---

## 1. Inventory: where each state is expressed today

### 1.1 The WORKS row, `_works_row` (`scenes/hud.gd:2439`)

| state | how it is drawn | cite |
|---|---|---|
| selected | plate fill `Color(0.176, 0.153, 0.098)` plus a 2px `UI_ACCENT` spine down the left edge | `scenes/hud.gd:2442`, `2443` |
| not selected | plate fill `Color(1, 1, 1, 0.030)` over the modal | `scenes/hud.gd:2445` |
| affordable | name ink `UI_TEXT`, or `Color(0.949, 0.831, 0.549)` when also selected | `scenes/hud.gd:2447` |
| short | name ink `Color(0.48, 0.50, 0.56)` | `scenes/hud.gd:2448` |
| short, per ingredient | the numeral beside each cost glyph turns `Color(0.804, 0.427, 0.376)`; covered ingredients are `Color(0.482, 0.796, 0.518)` | `scenes/hud.gd:2469` |
| locked | **absent.** Locked rows are not drawn at all | `scenes/hud.gd:1737`, `1822-1830` |
| unavailable | **absent.** `_works_row` never reads `can_craft` | `scenes/hud.gd:2439-2451` |
| buildable | **absent.** Same reason | `scenes/hud.gd:2439-2451` |

The absences are the important half of this table.

**Locked has no row.** `_unlocked` (`scenes/hud.gd:1737`) filters the catalogue to rows whose gating tech
is researched, and `bazaar_action()` walks only that filtered list (`scenes/hud.gd:1822-1830`). The
counter's only account of the locked half is one sentence at the bottom of the tab —
`"%d more wait behind research"` in `Color(0.451, 0.402, 0.280)` (`scenes/hud.gd:2376-2380`). This is a
shipped decision, `#S34b`, argued in the comment at `scenes/hud.gd:1731-1736`, and it is defensible. It
does mean that on the counter, "locked" is not a swatch and cannot be given one.

**Unavailable and buildable have no row expression either.** Grep for `can_craft` over `scenes/hud.gd`
returns five lines: the declaration at `150` and four inside `_draw_bazaar_detail` (`2645`, `2647`,
`2662`, `2663`). Nothing else in the file reads it. Standing at a Bazaar and standing a hundred metres
from one produce byte-identical WORKS rows; the entire difference is one 8pt sentence on the detail
plate.

### 1.2 The detail plate's verb, `_verb_button` (`scenes/hud.gd:2524`)

| state | how it is drawn | cite |
|---|---|---|
| buildable (`ready`) | filled pill in `UI_ACCENT`, verb in `Color(0.08, 0.07, 0.04)`, plus the key hint `ENTER` | `scenes/hud.gd:2530`, `2532`, `2534-2535`, `2695` |
| not buildable | pill filled `Color(1, 1, 1, 0.05)` over the modal, verb in `Color(0.44, 0.46, 0.52)`, **no** key hint | `scenes/hud.gd:2537`, `2539`, `2695` |
| nothing to run (`RESEARCHED`, `HELD`) | no pill at all: a tick stroked in `STATE_INK` then the word, both `Color(0.48, 0.70, 0.52)` | `scenes/hud.gd:2555`, `2564-2571` |
| the reason it is dead | one line of 8pt text centred above the button, `Color(0.58, 0.48, 0.32)` | `scenes/hud.gd:2697-2699` |

`MNU-18`'s observed complaint — *"the disabled BUILD button ... requires inference"* — is answered by the
first two rows of that table and by the ledger's own note that the button was distinct all along and had
simply never been photographed live (`docs/MENU_MATRIX.md:585`). The live and dead buttons are 139.8
luma steps apart (§2). The defect is not the button. It is that **one dead button covers three states**:

| the plate says | locked | not at a Bazaar | short in the pack |
|---|---|---|---|
| pill fill | `Color(1,1,1,0.05)` | `Color(1,1,1,0.05)` | `Color(1,1,1,0.05)` |
| verb ink | `Color(0.44,0.46,0.52)` | `Color(0.44,0.46,0.52)` | `Color(0.44,0.46,0.52)` |
| the word | `LOCKED` | `BUILD` / `BUY` / `RESEARCH` | `BUILD` / `BUY` / `RESEARCH` |
| the note | `behind Automation` | `at a claimed Bazaar` | `short 3 Ingot` |

Cites: `scenes/hud.gd:2640-2643` (tech locked), `2645-2647` (tech live/short), `2656-2659` (machine and
rack locked), `2662-2663` (machine and rack live/short). Two of the three states are separated by nothing
but the note sentence.

**The machine and rack LOCKED branch cannot execute.** `_draw_bazaar_detail` gets its `kind` and `id`
from `bazaar_action()` alone (`scenes/hud.gd:2595`), and `bazaar_action()`'s WORKS arm indexes only
`open_machines()` and `open_rack()` (`scenes/hud.gd:1822-1830`), both of which are `_unlocked`-filtered
(`scenes/hud.gd:1737-1745`). Every id that reaches `scenes/hud.gd:2656` therefore satisfies
`lock == &"" or sim.is_researched(lock)`, and the branch's condition is false by construction. Grep for
`"kind": "` across the tree returns four producers, all in `bazaar_action()` (`scenes/hud.gd:1828`,
`1830`, `1834`, `1842`), plus two unrelated `knobs` entries in `scenes/hover_info.gd`; the control grep
for the bare token `kind` in `scenes/hud.gd` returns 29 lines, so the narrow search was working. The
`LOCKED` verb is reachable for techs (`scenes/hud.gd:2640`) and dead for machines and rack items.

### 1.3 The BENCH chip, `_draw_tech_chip` (`scenes/hud.gd:2988`)

| state | plate | dot | name | unlock icons |
|---|---|---|---|---|
| researched | `Color(0.078, 0.113, 0.086)` (`2995`) | `Color(0.38, 0.78, 0.44)` (`3003`) | `STATE_INK` (`2998`) | undimmed (`3013`) |
| next available | `Color(1,1,1,0.040)` (`2997`) | `UI_ACCENT` (`3003`) | `UI_TEXT` (`2999`) | black scrim at 0.22 (`3014`) |
| locked | `Color(1,1,1,0.022)` (`2997`) | `Color(0.22, 0.24, 0.30)` (`3003`) | `Color(0.40, 0.42, 0.48)` (`2999`) | black scrim at 0.45 (`3014`) |
| selected | `Color(0.176, 0.153, 0.098)` plus 2px `UI_ACCENT` spine (`2992-2993`); name `Color(0.949, 0.831, 0.549)` when also next (`2999`) | — | — | — |

The BENCH is the one surface that expresses all four admissibility states, which makes it the right
frame to design the family against.

### 1.4 The rest, for completeness

- Pack wells repeat the row's selection language exactly: `Color(0.176, 0.153, 0.098)` plus a 2px
  `UI_ACCENT` spine (`scenes/hud.gd:2137-2138`), and the held item wears a 7pt `HELD` badge in
  `Color(0.949, 0.831, 0.549)` (`scenes/hud.gd:2152-2153`).
- The hotbar's active slot swaps a `UI_EDGE` border for a 2px `UI_ACCENT` one and adds a gold glow
  (`scenes/hud.gd:4024`, `4026`).
- The detail plate's have/need chip colours only the numerator: green `Color(0.482, 0.796, 0.518)` or red
  `Color(0.804, 0.427, 0.376)` on `have`, with `/need` in `UI_TEXT_FAINT` (`scenes/hud.gd:2868-2873`).

---

## 2. The greyscale pass

**Convention, named once and used throughout: Rec.709 weights on gamma-encoded sRGB,
`Y = 0.2126R + 0.7152G + 0.0722B`, reported in 0–255 steps.** This is the convention
`tools/check_selection_reads.gd:189-190` already measures greyscale survival with, and picking it means
this table can be compared against that layer's results without a conversion. Rec.601 is not used
anywhere below. On this palette the two disagree by up to 12.4 steps — the researched dot reads 171.0 in
709 and 158.5 in 601 — so the choice is not cosmetic.

**Contrast ratios are a different quantity and are labelled as such.** Where a ratio appears it is WCAG
relative luminance: channels linearised (`c/12.92` below 0.04045, `((c+0.055)/1.055)^2.4` above), weighed
0.2126/0.7152/0.0722, then `(L1+0.05)/(L2+0.05)`. This is `tools/check_text_contrast.gd:184-201`
reimplemented, and it was calibrated against that layer's own two anchors before any of the palette was
measured: white on black returned 21.0000 (must be exactly 21 by construction) and `#767676` on white
returned 4.5422 against the published 4.54. A gamma-encoded luma in the same formula returns 2.05 for the
second anchor, so the calibration separates the two quantities by a factor of two. No ratio below is
computed from the luma column. Translucent plates are composited over black, which is the ground the
palette was authored against.

### 2.1 Every state ink and plate, in luma

| element | cite | Y709 | Y601 | Δ |
|---|---|---:|---:|---:|
| `UI_TEXT` | `65` | 211.1 | 211.1 | 0.0 |
| `Color(0.949,0.831,0.549)` selected-name gold | `2447` | 213.1 | 212.7 | +0.4 |
| `UI_ACCENT` | `61` | 169.3 | 168.5 | +0.8 |
| `STATE_INK` | `2555` | 163.3 | 156.5 | +6.8 |
| cost glyph green | `2469` | 180.8 | 171.0 | +9.9 |
| cost glyph red | `2469` | 128.4 | 136.1 | −7.8 |
| bench dot, researched | `3003` | 171.0 | 158.5 | +12.4 |
| bench dot, locked | `3003` | 61.2 | 61.4 | −0.2 |
| `UI_TEXT_DIM` | `66` | 147.2 | 147.2 | 0.0 |
| `UI_TEXT_FAINT` | `80` | 137.0 | 137.0 | 0.0 |
| row name, short | `2448` | 127.5 | 127.7 | −0.2 |
| precondition note ink | `2699` | 124.9 | 125.4 | −0.5 |
| dead verb ink | `2539` | 117.3 | 117.5 | −0.2 |
| bench name, locked | `2999` | 107.1 | 107.3 | −0.2 |
| `UI_EDGE` | `41` | 86.0 | 86.0 | 0.0 |
| selected row/chip fill | `2442` | 39.2 | 39.2 | +0.1 |
| dead verb pill, over modal | `2537` | 29.5 | 29.5 | −0.1 |
| bench chip, next, over modal | `2997` | 27.1 | 27.2 | −0.1 |
| bench chip, researched | `2995` | 26.4 | 25.4 | +1.1 |
| plain row fill, over modal | `2445` | 24.7 | 24.8 | −0.1 |
| bench chip, locked, over modal | `2997` | 22.8 | 22.9 | −0.1 |
| `UI_MODAL`, over black | `85` | 17.6 | 17.7 | −0.1 |
| live verb ink | `2532` | 17.8 | 17.7 | +0.1 |

### 2.2 Which pairs collapse

| pair | Y709 separation | verdict |
|---|---:|---|
| bench chip plate, **researched vs next** | **0.7** | collapsed |
| bench **dot, researched vs next** | **1.7** | collapsed |
| bench chip plate, researched vs locked | 3.6 | collapsed |
| bench chip plate, next vs locked | 4.3 | collapsed |
| dead verb pill vs an ordinary row's surface tint | 4.8 | collapsed |
| dead verb ink vs `UI_TEXT_FAINT` | 19.7 | too close to signify |
| dead verb ink vs the short-row name ink | 10.2 | too close to signify |
| selected row fill vs plain row fill | 14.5 | survives, weakly; the spine carries it |
| bench name, researched vs next | 47.9 | survives |
| cost glyph green vs red | 52.5 | survives as a level, see the caveat below |
| row name, affordable vs short | 83.6 | survives |
| verb ink, live vs dead | 99.5 | survives |
| bench name, next vs locked | 104.0 | survives |
| bench dot, next vs locked | 108.0 | survives |
| verb pill, live vs dead | 139.8 | survives |

Read plainly:

1. **The BENCH's state light is carried by hue alone.** The dot is the chip's dedicated state mark, and
   researched-green sits 1.7 steps from next-gold. `tools/check_selection_reads.gd:45` sets `EPS` at
   `3.0 / 255.0` — the per-pixel threshold below which that layer refuses to count a luma difference as a
   change at all — so this pair would not register as one changed pixel in the repository's own greyscale
   instrument. In greyscale, a finished rung and the rung you can buy right now have the same lamp. The chip plate behind them is 0.7 steps apart, which is worse. The distinction survives
   only on the name ink (47.9) and on the unlock-icon scrim, neither of which is the mark a player is
   scanning for.
2. **The three chip plates are one plate.** 22.8 / 26.4 / 27.1 across locked, researched and next is a
   4.3-step total range. Whatever the chip plate is doing, it is not reporting state.
3. **The dead pill is not distinguishable from ordinary furniture.** At 29.5 against a plain row's 24.7
   and `UI_SLOT`'s 29.3, the disabled button's plate reads as a surface tint. It is rescued by its ink
   (117.3, 99.5 steps from the live ink) and its border-free pill shape, not by its fill.
4. **The green/red cost pair survives as a level but not as a comparison.** 52.5 steps is a real value
   step, and by `MNU-32`'s criterion it survives greyscale. But the two never appear on the same
   ingredient: you are asked to judge one numeral's brightness in isolation, beside a different icon, at
   9pt. Whether that reads as a state is a question a level difference cannot answer — see §5.

### 2.3 The contrast column, and the six greys nobody named

`tools/check_text_contrast.gd` holds a 4.5:1 floor over nine pairs of **named** constants. Every ink in
§1 that carries state is a literal, so none of them is in that population. Measured the same way:

| ink | cite | on its actual plate | ratio |
|---|---|---|---:|
| `UI_TEXT`, affordable row name | `2447` | plain row fill | 11.80 |
| gold, selected + affordable name | `2447` | selected row fill | 10.29 |
| cost glyph green | `2469` | plain row fill | 8.99 |
| `STATE_INK` word | `2570` | `UI_MODAL` | 7.67 |
| cost glyph red | `2469` | plain row fill | 4.99 |
| precondition note | `2699` | `UI_MODAL` | 4.63 |
| **short row name** | `2448` | plain row fill | **4.44** |
| **cost glyph red** | `2469` | **selected** row fill | **4.20** |
| **short row name** | `2448` | **selected** row fill | **3.74** |
| dead verb ink | `2539` | dead pill | 3.66 |
| **bench name, locked** | `2999` | locked chip fill | **3.38** |

The dead verb ink at 3.66 is a declared exemption, not a new defect: `tools/check_text_contrast.gd:50-51`
writes it out by name as "deliberately quiet and exempt under every readability standard that has an
opinion about disabled controls". The rows in bold are not exempt. Two of them are worse **because** the
row is selected: putting the cursor on a row you cannot afford lifts its plate from 24.7 to 39.2 while
its ink stays at 127.5, so the row the player is reading is the least readable row on the screen. That
inversion follows directly from `scenes/hud.gd:2447-2448`, where the selected-name lift is inside the
`if afford` branch and is therefore cancelled whenever the row is short.

Underneath all of it is a ramp nobody wrote down. Six cool greys, all at hue 220–225°, saturation
0.14–0.20, spaced almost evenly in value:

| ink | cite | Y709 | on `UI_MODAL` |
|---|---|---:|---:|
| `UI_TEXT_DIM` | `66` | 147.2 | 6.15 |
| `UI_TEXT_FAINT` | `80` | 137.0 | 5.39 |
| row name, short | `2448` | 127.5 | 4.73 |
| dead verb ink | `2539` | 117.3 | 4.10 |
| knob label, off | `1999`, `3536` | 109.3 | 3.66 |
| bench name, locked | `2999` | 107.1 | 3.54 |

Two of the six have names. The bottom two are 2.2 steps apart and are the same colour for every practical
purpose. This is the same shape as the finding that produced `UI_TEXT_FAINT` — four literals doing one
job across eight sites (`scenes/hud.gd:67-79`) — recurring one layer down, at the state layer, and it is
why §4 spends its effort on which *rung* each state sits on rather than on inventing new hues.

The green family has the same problem in miniature: `STATE_INK` 163.3, the researched dot 171.0 and the
cost-covered green 180.8 are three unrelated literals at hue 127–131° meaning three versions of "this is
fine".

---

## 3. The text-only pass

Strip every colour. Keep the words, the glyphs, the plates and the positions. Can the five states still
be told apart?

| state | what is left | survives? |
|---|---|---|
| locked, on BENCH | the word `LOCKED` in the verb pill (`2640`); the note `behind <tech>` (`2642-2643`); the unlock icons carry a heavier scrim, 0.45 against 0.22 (`3014`) — a value cue, so it survives greyscale, but it is not a *word* | **yes**, on the word |
| locked, on WORKS | nothing. The row does not exist. Only the aggregate line `"N more wait behind research"` (`2379`) | **n/a** — there is no per-thing state to survive |
| unavailable (away from a Bazaar) | the note `at a claimed Bazaar` (`2647`, `2663`), 8pt, centred above the button; and the absence of the `ENTER` hint (`2695`) | **marginally.** One sentence, nowhere else on the screen |
| affordable / short | the deficit sentence `short 3 Ingot` (`_shortfall_note`, `2738-2746`) on the plate. On the **row**, nothing: the cost numeral prints the same digits either way (`2469`) | **plate yes, row no** |
| buildable | the word `ENTER` beside the verb (`2695`) — present only when `ready` — and the pill's filled-versus-quiet plate | **yes** |
| selected | the 2px spine at a position no other row has (`2443`), the plate fill, and the detail plate below re-printing the thing's name, art and blurb (`2675-2677`) | **yes**, three times over |

**The two failures are precise and small:**

1. **The cost glyphs on a row carry affordability in hue alone.** `_cost_glyphs` (`scenes/hud.gd:2459`)
   prints the same string for a covered and an uncovered ingredient and changes only the ink
   (`scenes/hud.gd:2469`). Remove colour and the row stops saying whether you can afford it. The row's
   *name* ink still carries the whole-row verdict at 83.6 steps, so the row is not silent — but "which
   ingredient am I short of", which is the reason the per-ingredient colouring exists at all, is a pure
   hue channel. The detail chip has the same shape (`scenes/hud.gd:2869-2870`).
2. **The BENCH dot carries three states in hue alone at two of its three values.** Green 171.0 versus
   gold 169.3 (`scenes/hud.gd:3003`). Locked at 61.2 separates fine; researched and next do not.

Everything else survives, and two things survive better than the ticket credits: the dead button says
what it is short of (`_shortfall_note`, shipped, `docs/MENU_MATRIX.md:585-586`), and the `ENTER` hint is an
existing, working, colour-free "you may press this now".

---

## 4. The proposed swatch family

### 4.1 The constraint that shapes it

The palette's usable text ramp has three rungs that clear 4.5:1 on the modal: `UI_TEXT` (211.1, 12.57:1),
`UI_TEXT_DIM` (147.2, 6.15:1), `UI_TEXT_FAINT` (137.0, 5.39:1) — and the bottom two are 10.2 steps apart,
which is one rung for state purposes. The next rung down, `UI_EDGE`, is 2.57:1 and below the floor.

**So lightness can carry two state levels here, not four.** Any family that tries to give locked,
unavailable, short and buildable four distinct lightnesses either invents inks the palette does not have
or pushes two of them under the contrast floor — which is exactly what the current code does, at 3.38,
3.54, 3.66 and 4.44. Shape has to carry the rest. That is the design decision this review returns, and it
is the reason the family below has one ink for three states and three glyphs to tell them apart.

### 4.2 The family

Two amber values in §1 are unnamed literals at eight and three sites respectively — the selected-name
gold `Color(0.949, 0.831, 0.549)` and the selected plate fill `Color(0.176, 0.153, 0.098)`. Both are
`UI_ACCENT`'s hue: 42.3° against the accent's 43.2°, in a file where every amber literal sits between
36.9° and 43.2°. They should be names derived from the accent, and the family below assumes they are:
`GOLD_PALE` and `PICK_FILL`.

**The derivation is clean in HSV and not in RGB, and that constrains how it can be written.** In HSV,
`GOLD_PALE` is the accent at 0.67 of its saturation and a value of 0.95 — reproducing the literal to a
maximum channel error of 1.9/255 and +1.50 in Y709 — and `PICK_FILL` is the accent at 0.71 of its
saturation and 0.22 of its value, to 0.3/255 and +0.20. Both residuals are under
`check_selection_reads`'s `EPS` of `3.0 / 255.0` (`tools/check_selection_reads.gd:45`), the threshold at
which this repository stops counting a channel difference as a change, so switching to the derived form
is invisible. In RGB there is no single scale that produces either: `UI_ACCENT * 0.22` reproduces
`PICK_FILL`'s red exactly and misses its blue by 8.2/255, and no lerp between `UI_ACCENT` and any
existing plate constant fits all three channels at one `t`.

That matters because the channel form is the one this file has proven a `const` will take —
`RAIL_ON_FILL` at `scenes/hud.gd:261-263` is `Color(UI_RAIL.r + RAIL_ON_LIFT.r, …)` and compiles. **A
`const` initialised from `Color.from_hsv(…)` has no precedent anywhere in this tree** — a grep for a
`const` whose initialiser is a static call returns zero across every `.gd` file, and both halves of that
pattern were controlled against something that must return: the same `const …` prefix with a `Color(`
initialiser matches ten lines in `scenes/fine_terrain.gd`, and the `X.y(` tail matches call sites
everywhere. `from_hsv` appears once in the tree, at runtime, in `scenes/world_renderer.gd:1061`. Whether
GDScript folds a static call into a constant expression
was **not verified — no Godot process was run for this review**. The builder should try the `const` form
first and fall back to `static var` if the parser rejects it; either way the value is derived from
`UI_ACCENT` and moves when the accent moves, which is the property being bought. What should not happen
is a third copy of the literal with a comment explaining it.

| state | ink / plate | derived from | non-colour cue | Y709 | nearest neighbour |
|---|---|---|---|---:|---|
| **selected** | plate `PICK_FILL`, 2px `UI_ACCENT` spine, name `GOLD_PALE` | `UI_ACCENT` | the spine's *position* — the only 2px vertical at the row's left edge — plus the detail plate re-printing the thing | fill 39.2, spine 169.3 | +14.5 to the plain row fill; the spine is +144.6 against it |
| **buildable** | pill filled `UI_ACCENT`, verb ink `Color(0.08,0.07,0.04)` | `UI_ACCENT` | the pill is *filled*, and the key hint `ENTER` appears only here | pill 169.3 | +151.7 to the unfilled pill |
| **affordable** | row name `UI_TEXT`; per-ingredient numeral keeps green | `UI_TEXT` | the numeral prints bare: `3` | 211.1 | +74.1 to the blocked ink |
| **short** | row name `UI_TEXT_FAINT`; the uncovered numeral prints its **deficit with a sign**: `−3` | `UI_TEXT_FAINT` | the leading minus, plus a *stacked-chips* glyph on the pill | 137.0 | +74.1 to affordable; 0 to the two below, by design |
| **unavailable** | pill ink `UI_TEXT_FAINT` | `UI_TEXT_FAINT` | a *place* glyph on the pill (the Bazaar mark the rail already draws) | 137.0 | 0 to short, separated by glyph and word |
| **locked** | pill ink `UI_TEXT_FAINT`, word `LOCKED` | `UI_TEXT_FAINT` | a *lock* glyph on the pill; on BENCH, the 0.45 unlock-icon scrim already in place | 137.0 | 0 to short, separated by glyph and word |

Four changes make it work, and each removes a measured defect rather than adding decoration:

1. **The dead pill loses its fill and gains a 1px `UI_TEXT_FAINT` outline.** Filled-versus-outlined is a
   shape difference readable at any size and in any colour, and it retires the `Color(1,1,1,0.05)` fill
   that measures 4.8 steps from ordinary furniture. `UI_TEXT_FAINT` on the modal is 5.39:1, clearing both
   the 4.5:1 text floor and WCAG's 3:1 non-text floor; the present `UI_EDGE` would be 2.57:1 and clears
   neither.
2. **The reason moves onto the pill as a glyph.** Three shapes — lock, place, stacked chips — for the
   three reasons a verb is dead. The note sentence stays where it is and keeps saying the specifics
   (`short 3 Ingot` is more use than any glyph), but it stops being the only carrier.
3. **The uncovered cost numeral prints its deficit with a sign.** `−3` instead of `3`. This is the one
   change that fixes the text-only failure in §3, and it answers a question the row currently cannot:
   *how* short. The arithmetic already exists in `_shortfall_note` (`scenes/hud.gd:2738-2746`); it is not
   reaching the row.
4. **The selected-name lift stops being conditional on affordability.** `scenes/hud.gd:2447-2448` becomes
   two independent decisions: the plate and spine say *selected*, the ink rung says *affordable or not*.
   That removes the 3.74:1 and 4.20:1 rows, which are the only two places where selecting something makes
   it harder to read.

For the BENCH dot, whose collapse is the sharpest finding in §2: give **researched** a filled disc and
**next** a filled disc with a ring around it, or drop the dot for researched in favour of the tick the
plate already uses at `scenes/hud.gd:2568-2569`. Any shape difference will do; a 1.7-step value
difference will not. The ink can stay green — the point is that green must stop being the *only* thing
that differs.

### 4.3 What the family deliberately does not do

It does not give **buildable** a row-level mark. It could — `can_craft` is a field on the HUD and the row
could read it — but a gold row that is not the selected row breaks `MNU-06`. Buildable stays a property
of the plate's verb, where gold's second sanctioned meaning already lives.

---

## 5. `MNU-06`: no new conflict from the family, three pre-existing ones surfaced

The family needs gold twice: on the selection (spine, plate fill, selected name) and on the live verb
pill. `MNU-06` sanctions exactly that pair by name — *"the pair a naive split would separate — the
selected row's spine and the button that acts on it — is the one place the doubling CARRIES meaning"*
(`scenes/hud.gd:51-53`; the same argument in prose at `docs/MENU_MATRIX.md:511-512`, and rows 1 and 2 of finding 8's gold table). So
the proposal introduces no conflict, and it is compatible with the shipped rule only because it refuses
to put buildable-ness on a row.

**But the review turned up three sites that conflict with the rule as written, and they were invisible to
the census that produced it.** Finding 8 is an enumeration of `UI_ACCENT`'s *call sites*
(`docs/MENU_MATRIX.md`, "An enumeration, from source, of `UI_ACCENT`'s call sites in `scenes/hud.gd`").
The rule it shipped is about the colour gold. Those are different populations. Scanning
`scenes/hud.gd` for colour literals in the amber band (hue 20–60°, saturation above 0.15) returns 41
literals against 132 total, beside 19 code lines mentioning `UI_ACCENT`. Three of the 41 are doing the job
"gold never labels" forbids:

| site | value | hue | contrast on `UI_MODAL` | what it is |
|---|---|---:|---:|---|
| `scenes/hud.gd:2411` | `Color(0.451, 0.365, 0.180)` | 41.0° | 2.98 | the `MACHINES` / `THE RACK` group headings |
| `scenes/hud.gd:2273` | `Color(0.451, 0.365, 0.180)` | 41.0° | 2.98 | the head band's heading, same literal |
| `scenes/hud.gd:2376` | `Color(0.451, 0.402, 0.280)` | 42.8° | 3.35 | `"N more wait behind research"` |
| `scenes/hud.gd:2699` | `Color(0.58, 0.48, 0.32)` | 36.9° | 4.63 | the precondition note — a state carrier |

`UI_ACCENT` itself is 43.2°. All four are the same hue family at lower value, and all four are pure
information: two headings, a count, and a sentence. `MNU-06`'s first pass moved three headings and three
headline numbers off gold for precisely this reason; these were not in the list because they are literals
and the census counted a constant.

**This is surfaced, not resolved.** Two of the four are `MNU-06`'s business and not `MNU-18`'s. The one
that is `MNU-18`'s business is the precondition note at `scenes/hud.gd:2699`: it is a state carrier, it is
amber, and moving it to `UI_TEXT_DIM` would both settle the gold question for that site and lift it from
4.63:1 to 6.15:1. That single change is recommended and flagged as touching `MNU-06`'s territory; a
builder should not make it without `MNU-06`'s owner agreeing, because it is the same decision as the
other three and deciding it here would decide them by precedent.

---

## 6. What this review could not determine

Listed so nobody reads the document as more settled than it is.

1. **Whether a 52.5-step luma difference between two nine-point numerals, never adjacent, reads as a
   state.** §2.2 establishes that the green/red cost pair survives greyscale as a level. It does not
   establish that a player can use it, because the comparison is never presented — you see one numeral
   beside one icon, not the pair. This needs a rendered frame and a naive eye, and it is the reason §4
   proposes the signed deficit rather than trusting the level.
2. **Whether the three proposed reason glyphs are legible at the pill's size.** The pill is 24px tall
   (`VERB_H`, `scenes/hud.gd:2514`) on a 640×360 canvas. A lock, a place mark and a stack of chips at
   roughly 9px square is an assertion about the glyph set, not a measurement. Draw them and look.
3. **Whether the BENCH's collapsed dot has ever been seen.** It cannot be judged from the archive,
   because the archive does not contain the state. `_moment_bench_next.png` is a fresh save with nothing
   researched — every dot is gold or grey. `_moment_bench_full.png` is a finished ladder — every dot is
   green. **The frame where a green researched dot sits beside a gold next dot has never been captured.**
   That is precisely the `MNU-10` failure mode restated: the state nobody photographed is the one that
   holds the defect.
4. **The archived BENCH frames are stale and cannot be used to review the current plate.**
   `_moment_bench_full.png` shows `RESEARCHED` in a grey pill with the note `already yours` above it and a
   `64/2` price chip below it — all three of which the current code removed. Both frames were committed
   at `97fe8cc` (2026-08-18, *"the matrix photographed the counter from across the room"*); `_state_plate`
   arrived at `aef4587` (2026-08-20, *"the counter stops lying about what it is showing you"*), verified
   by `git log -S'_state_plate' -- scenes/hud.gd`. Any visual review of the state forms needs a re-shoot.
5. **Everything in §2 and §4 is arithmetic over authored constants, not over pixels.** It is blind by
   construction to compositing against a lit world behind a 0.90 plate, to the vignette, and to
   antialiasing on small type. The counter is drawn on `UI_MODAL` at 0.985 alpha, so the exposure is
   small, but it is not zero and nothing here measured it.
6. **`scenes/settings.gd` was not examined.** It has its own engaged and disengaged control states —
   `scenes/hud.gd:1999` and `3536` show the same knob-label pair living in the HUD — and whether the
   family extends there is unreviewed. Two agents hold that file.
7. **Whether a `const` will accept `Color.from_hsv`.** §4.2 gives the derivation and the fallback; the
   parse is one command and it was not run.
8. **Nothing here was run.** No Godot process was started; the machine lock is held elsewhere. The
   contrast implementation was calibrated against `tools/check_text_contrast.gd`'s own two published
   anchors and reproduces them to 21.0000 and 4.5422, which is evidence the instrument is right and not
   evidence that the layer would pass.
