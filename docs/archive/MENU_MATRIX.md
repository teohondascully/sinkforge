> **ARCHIVED 2026-08-27.** Untracked since the 2026-08-25 pivot. `docs/archive/PIVOT_PLAN_2026-08-25.md`
> §1 scoped this as REWRITE (keep the settings/accessibility/keybinding methodology, cut the
> Bazaar-specific counter findings) — the "Edited 2026-08-25" header below suggests that edit was done,
> but it was never committed. Moved here rather than promoted to the live tree, on the same reasoning as
> `AGENT_PLAY_EVALUATION_PROTOCOL.md`'s header. Kept for provenance.

---

# The menu matrix

> **Edited 2026-08-25** for the run-based pivot: sections specific to persistent-world design were
> removed or marked below. The rest of this document is unchanged and still describes current reality.

A screenshot register for the menu screens in fresh, midgame and full-catalogue states, built before the
redesign so that the redesign has something to be judged against. The requirement it answers is `MNU-10`:
build a screenshot matrix for fresh, midgame and full-catalogue menu states, register named captures
before redesign, and do not optimise only a fully unlocked developer state. The `MNU-*` queue itself is
in `docs/VISUAL_RECOMMENDATIONS_SURFACE.md`.

All twelve captures are canonical `_moment_*.png` and tracked, so they are a baseline and not a scratch.

| moment | rung | screen |
|---|---|---|
| `pack_fresh` | a new save | PACK, what you carry |
| `works_fresh` | a new save | WORKS, what you can build |
| `bench_fresh` | a new save | BENCH, the research ladder |
| `pack_full` | every reachable id, all research | PACK |
| `works_full` | every reachable id, all research | WORKS |
| `bench_full` | every reachable id, all research | BENCH |
| `counter` | midgame, 24 each of six staples | PACK |
| `works` | midgame | WORKS |
| `bench` | midgame | BENCH, with a locked node selected |
| `works_short` | midgame, pack emptied | WORKS, with a row you cannot afford selected |
| `bench_next` | midgame | BENCH, with the actionable rung selected |
| `settings` | n/a | SETTINGS, which is not a Bazaar tab |

The middle rung was already present under three older names: `counter`, `works` and `bench`, all posed by
`_at_the_counter`, which grants 24 each of six staples with four machines unlocked. It is `counter` and
not `pack`, because there is a separate `pack` moment posed by `_at_the_packing`, a different scene
entirely. So the register is three rungs across three tabs, plus two brief-named states and the settings
page: twelve frames, seven of them new.

## Why the matrix existed at all

There was exactly one menu moment before this: `_at_the_counter`. That is the middle rung, and it is the
state that happens to look tidiest. Enough items that the grid is not empty, few enough that it is not
crowded, and a price the player can nearly afford. Every judgement anyone had made about these screens
was made about that one state.

The three rungs took about an hour to add and found four things in the first sitting. Three of them were
in the game. One was in the fixture.

---

## 1. `clear dig plan` was drawn below the bottom of the screen

Reproduces. Fixed in `d3e4be7`.

The settings page drew twenty-two key bindings at 13.8px from y=74 inside a panel 332 tall at y=14:

```
panel  Rect2(90, 14, 460, 332)     floor y = 346      canvas 360 tall
quickload        y = 350.0    chip 340.0..353.0   below the panel floor
clear dig plan   y = 363.8    chip 353.8..366.8   below the SCREEN
```

The last binding in the list was drawn, and registered as clickable, off the bottom of the canvas.

**Why this is the matrix's finding and not a coincidence.** `tools/check_hud_layout.gd` opens with "THE
HUD MUST NOT PRINT ON TOP OF ITSELF, OR OFF THE EDGE OF THE SCREEN", carries "settings open" in its state
matrix, asserts clipping in every state with no exceptions, and had been green every run since it was
written. The warning already existed in a weaker form: a green layout test is not proof of a modern menu.
That understated it. It was not proof of an on-screen one either.

The layer probes `Hud.panel_probe`, which `_panel()` and `_round_rect()` append to. A binding chip is not
a panel. The population is panels and the claim is the HUD. The layer was never wrong; it was answering a
smaller question than its name, and nothing in a passing run says which question it answered.

**The instrument that can see it.** The page already publishes the right population for a different
reason. `_settings_hits`, `_knob_hits` and `_alert_hits` are the rects that `settings_click`,
`hover_click` and `alert_click` route a real press through, so they cannot drift from what is clickable,
because they are what is clickable. Two claims: on screen at all, and on the plate that owns them. Two
failures became passes across the fix, with a rejection control that displaces one rect and requires the
predicate to catch one more.

**The fix is a split, not a squeeze.** The row step that fits 22 bindings between the header and the
floor is 12.4px against 10pt type, which trades an invisible control for an illegible one. Two columns of
eleven on a 592×286 centred plate, with the geometry named as constants so the layer measures the numbers
the drawing uses.

## 2. The price chip drew need/have while three comments called it have/need

Reproduces. Fixed in `5a8ca9c`.

A fresh save priced the Forge at `3/0`, a fraction with a zero denominator, in the first screen a new
player opens. The full save priced the same Forge at `3/64`, which reads as five percent of the way there
while you are carrying twenty-one times what it asks.

`_detail_chip`'s own docstring said "One have/need chip". The detail plate above it said "its price as
have/need chips". `tools/mock_bazaar.gd` said it a third time. The code drew `"%d/%d" % [need, have]`.
Nothing tested the order, so three sentences were the only specification and all three said the opposite
of the pixels. It now draws `"%d/%d" % [have, need]`.

Neither rung alone shows this. The midgame rung prices things at roughly what you are carrying, where
`3/4` and `4/3` both look like plausible ways round.

## 3. Settings and the Bazaar are two grammars in one game

Reproduces. The prototype is `tools/mock_settings.gd`; nothing there ships.

|  | THE BAZAAR | SETTINGS (before) |
|---|---|---|
| plate | `_round_rect`, r=8, alpha 0.985 | `draw_rect`, hard corners, alpha 0.90 |
| ground | scrim 0.42, tinted, world blurred | scrim 0.55, pure black, world sharp |
| structure | rail, columns, detail plate | two columns of text |
| the selected thing | drawn large, named, priced, with the verb on a button | nothing is selected |
| opened by | `E` / `T` | `ESC` |
| drawn by | `_draw_inventory_overlay` | `_draw_settings_overlay` |

The 0.90 is not cosmetic. `UI_BG` is 90% opaque because furniture panels sit over the world and are meant
to. A modal is not furniture. At 0.90 the objective banner, drawn earlier on the same strip in bright
type on its own dark plate, read straight through the settings page in the capture. Ten percent of a lit
banner over an unlit panel is about twice the panel's own value. The plate is opaque now, as of
`d3e4be7`.

The rest is the redesign's subject rather than a bug fix, and it has an explanation in the repository.
`docs/FEEL_GAP.md` records that three proposals were drawn over real frames of the real game with
`tools/mock_bazaar.gd`, and the counter in the game today came out of that round. Settings never went
through it. One screen was designed and the other was written.

### The prototype

Regenerate with `godot --path . --script res://tools/mock_settings.gd`. It needs a real window, and its
output (`_mock_settings_a.png`, `_mock_settings_b.png`) is gitignored, following the convention
`mock_bazaar.gd` already uses: the tool is the artefact and the picture is a render of it.

The prototype draws its proposals over a real frame, on the counter's own numbers (`Hud.BAZAAR_SIZE`
608×348, `BAZAAR_RAIL` 56, `BAZAAR_HEAD` 48, `BAZAAR_DETAIL` 88), read rather than copied, because the
whole argument is that this is the same object. Three changes, in descending order of how much they
matter:

1. **Settings is a tab.** The rail already teaches that a digit opens a face of this object. A fourth
   face costs one glyph and removes an entire second modal grammar from the game. The rail is 348 tall
   and three tabs use 242 of it, so the room was already there.
2. **The bindings get a detail plate.** Twenty-two rows carry equal weight today, and remapping is "click
   the small chip on the right of the row you want". The counter's answer to exactly this problem was to
   draw the selected thing large, say what it is for, and put the verb on a real button. A key binding
   wants that more than a machine does: the row says `grapple  F`, and the plate says what grapple
   *does*, which is the sentence a first-timer is short of. A key legend that says what a key is for is a
   different document from a key legend that says which key it is.
3. **Feel and audio sit beside the keys.** WORKS already established the two-column shape, and this page
   has the same shape: the keys are a long list and the levels a short one.

### The prototype argues against the brief, and the brief probably wins

The brief says Settings should get an independent compact utility layout instead of the Bazaar shell. The
prototype proposes the opposite: Settings as a fourth face of the Bazaar shell. The conflict is recorded
here rather than quietly reconciled, because a prototype that contradicts its own brief is either a
mistake or an argument, and which one has to be stated.

The argument for the tab: the two grammars are the photographed defect, the rail already teaches that a
digit opens a face of this object, and one shell is one thing to maintain and one thing to learn.

The argument for the brief, which is stronger: the counter is a place. You walk to a claimed Bazaar and
stand at it, and "at a claimed Bazaar" is printed on the WORKS plate as a precondition. Settings is not a
place and has no precondition; it is the pause menu. Folding it into the counter would say the game's
audio levels live at a ruin you have to reach, which is false and would be the first thing a player
tested. "Compact utility" is also a real distinction. A settings page should be smaller than the counter
rather than the same 608×348 object, because it is a utility and not a destination.

So the brief's prototype exists too, as variant `b` of the same tool: an independent compact page that
borrows the counter's material (rounded plate, elevation instead of borders, key caps instead of bordered
rectangles, a blurred backdrop) without borrowing its shell or its size. 296×266 against the counter's
608×348 is 37% of the area, which is what makes "compact" a measurement rather than an adjective. That
figure read "roughly a third" until it was divided out; 0.372 is nearer two fifths, and rounding a
measurement toward the adjective it was meant to replace is the failure mode in miniature.

Variant `b` also has to solve something a repaint would not, and the solution is the interesting part.
Twenty-two bindings do not fit in a compact page and never will. The shipped fix, two columns of eleven,
only fits because that page is nearly full-screen. So the remap table becomes its own page, opened from a
single row that carries the count and its own key: `keys · 22 bindings, all rebindable · K`. That is the
honest split. The four things a player touches often are small and immediate, and the table they touch
twice a year gets the width it needs when they ask for it.

Variant `a` stays as the counter-proposal. It is not deleted and it is not the recommendation.

Variant `b`'s first render put its `keys` row 29 pixels below the bottom of its own plate: a mock whose
entire argument is that the settings page outgrew its panel, overflowing its panel, by the same method, a
height chosen by eye instead of summed. It is recorded in the source rather than quietly corrected,
because two independent instances of one mistake is a habit and not a slip.

One finding survives both layouts, and it is the reason the prototype was worth drawing: a key legend
that says what a key is for is a different document from a key legend that says which key it is. That is
content rather than shell, and it is missing from the page in both designs today.

### The register is complete

`works_short` (`1cc50b1`) added WORKS with an unaffordable row selected, and `bench_next` (`97fe8cc`)
added the BENCH with the actionable node selected, which is the brief's "one actionable path and late
locked branches". The board's own screen had never been photographed showing it. The register is now
twelve frames.

The first `works_short` did not contain the contrast it was made for. See finding 5.

---

## 4. The six white squares were a fixture defect

Does not reproduce in the game. Fixed in `2ca780d`.

The first `pack_full` capture showed six blazing white tiles in the middle of the grid. The mechanism is
real and confirmed in source twice, independently: `Visuals.draw_item`'s default arm fills a flat rect
with `item_color`, whose last line is `return Color.WHITE`. The fallback for "I do not know what this is"
is the brightest, highest-contrast mark available on a dark screen.

Every one of the six was an id the game cannot put in a pack. The fixture's `_catalogue()` walked
`src/data/materials` and `src/data/machines` and took every `.tres` on disk:

- `dirt_wall`, `stone_wall`, `shale_wall`, `deepslate_wall`, which have `layer = &"wall"` and are the
  background plane. You dig *through* them; `mine()` never touches them.
- `leaves`, because `FactorySim.mine`'s foliage branch yields a sapling or nothing. The leaf block is
  never pocketed.
- the machines the world places rather than sells, which have no craft path, since `machine_icons` is
  built by iterating `MainView._craftable`.

A fixture that reaches a state the game cannot reach does not surface bugs. It manufactures them, in the
most convincing form there is, which is a screenshot. `MNU-10` says not to optimise only for a fully
unlocked developer state, and the same sentence forbids optimising for an unreachable one.

Two things about how long this survived are worth keeping. The mechanism was confirmed in source and a
photograph of it existed, which is the evidence standard everything else here is held to, and it was
still wrong. And the two questions asked about it were "does the fallback exist and is it white" (it does
and it is) and "are there white squares in the capture" (there were). Neither question can distinguish a
shipped defect from a fixture in an impossible state. Two agreeing verifications of the wrong predicate
are not two verifications.

The guard that would have caught it is now in `tools/check_item_reads.gd` (`a6d2234`). That layer's
`_check_vocabulary` already closed the drift between its hand-kept item list and `visuals.gd`'s match
arms, in both directions, with a non-vacuity floor. It is a good guard whose universe is
`_items_the_view_knows()`, read out of `visuals.gd`. An id the *game* can hand a player and the *view*
has never heard of is absent from both sides of that comparison and passes by construction. The list
agreed with the code, and nobody asked whether either agreed with the game. The third direction,
`_check_pack_vocabulary`, takes its population from the data by the rule the pack is actually filled:
`_ids_the_pack_can_hold()` walks the material defs minus `leaves`, the recipe inputs and outputs, and
`MainView.CRAFT_TOOLS`. It carries a planted-unknown control, `not_a_real_item`.

`docs/FEEL_GAP.md:187` records that this exact failure mode has shipped once, on ids that were reachable:
carried terrain blocks drew as blank white squares in the hotbar. That one was real and is long fixed. It
is the reason the third direction is worth having even though it is green today.

---

## What each rung is for

- **fresh** is the only rung that shows an empty layout: one item in the grid, a full-width detail plate
  for a wood pickaxe, and a price of `0/3`. Findings 1 and 2 are both fresh-rung findings, and nothing
  about the midgame capture would have raised either.
- **full** is the only rung that shows density: the grid populated across several rows, the top-right
  resource strip filled, three columns of machines in WORKS instead of one. It is also the rung that
  manufactures defects the moment its universe drifts from what the game can reach, so its derivation is
  now the rule `FactorySim` fills a pack by, rather than a directory listing.
- **settings** is not a rung. It is in the matrix because it is the one screen that is not a face of the
  counter, and the capture is what made that legible as a design fact rather than a code detail.

## What the matrix did not find, recorded so it is not re-litigated

- `works_fresh` carries "16 more wait behind research — press 3 for the BENCH". That is the correct
  pattern, a count plus a pointer instead of a wall of locked rows, and it is already there. The redesign
  must not lose it.
- `bench_fresh` shows the entire ladder with every node visible and dim. That is also correct. The BENCH
  is the one screen whose whole job is "what comes next", and the locked future belongs there and nowhere
  else.
- PACK is not redundant with the ten-slot hotbar and is not up for removal. It is the only view of what
  you are carrying beyond ten types.

---

## 5. Every menu capture was taken from across the room

Reproduces. Fixed in `97fe8cc`.

`capture_moments` posed every Bazaar moment by writing `main._hud.can_craft = true`. `MainView._process`
recomputes that field from `_near_bazaar()` on every frame, so the write was gone long before the
shutter, sixty settle frames later.

So the ten menu frames, the seven built as the redesign's baseline and the three older ones they were
built to complete, all photographed the counter as seen by somebody standing nowhere near it. The
Bazaar's verb is a gold button when you are at a claimed frame, and a dead plate under a note naming its
precondition when you are not. The archive contained no picture of the button.

The tell was in the frame the whole time. `works_full` holds sixty-four of every input, prices the Forge
at a green `64/3`, and greys out BUILD under the note "at a claimed Bazaar". That image was read as the
design.

It also destroyed `works_short`, which existed for one reason: the brief's "WORKS with available and
unavailable selected". Both arms drew the same dead plate for the same reason, a variable neither arm
controlled, so the contrast the capture exists to show was not in it, while the fixture's own docstring
claimed it was. A fixture that writes a field the game recomputes has posed nothing.

### What the guard could not have been

`_contamination` already refuses a frame that is not what the moment claims, and it is a good instrument:
it caught a real `E` and `P` keypress landing in `_moment_delve.png`. It checks a `CALM` baseline
overridden by an `EXPECT` table, whose keys are properties on `main`: `_inventory_open`, `_paused`,
`_settings_open`, `_show_help`, `_title_open`, `_minimap_mode`. `can_craft` lives on `main._hud`, so it
was not merely unchecked, it was not expressible in the table's vocabulary. A state assertion whose
population is the fields somebody thought to list will pass, every time, on the field they did not.

### The fix poses the world, not the flag

`_stand_at_a_bazaar()` claims the ruin that worldgen leaves near the surface by placing its last post
through `sim.place_block`, which is the real path: it consumes the wood, marks `_bazaars_dirty` and sets
`fill`. The body then stands in the frame's interior. `can_craft` comes out of the same computation the
game uses, and there is nothing left to overwrite. The wood is not refunded, because callers grant their
staples after standing, so the pose is exact without a rollback that would put the pack in a state a
placing player could not be in.

Two guards, in both directions:

- the moments that claim to be at the counter refuse a frame where `can_craft` is false. Control: stub
  the helper to return false, and `works_full` exits 1, refuses, and keeps the previous PNG.
- the fresh rung refuses one where it is true, because the fresh rung's whole claim is that it is the
  game's opening state, where the ruin is unclaimed and the dead button is honest. A one-directional
  guard would have passed a fresh capture that had wandered into a Bazaar.

The fresh trio's committed pixels were left alone. Its pose did not change, only a line that never took
effect, so re-shooting it would have put capture noise in the archive and nothing else.

---

## 6. The first frame ever taken with the verb live read `BUILDENTER`

Reproduces. Fixed in `97fe8cc`.

Four pixels between a 10pt tracked verb and its 8pt key hint reads as one word. `_detail_hold` drew the
same construct with the hint hardcoded twenty pixels out: two buttons in one plate, disagreeing by a
factor of five about how far a verb sits from its key, both numbers guesses and only one of them ever
looked at.

The fixed 104px plate also could not hold the longest verb this screen produces. RESEARCH is eight
tracked characters in a button sized for BUY.

Neither is findable without a live capture, and there had never been one. This is finding 5's dividend:
the register is not documentation of the screens, it is the only instrument that can see them.

The fix is one `_verb_button`, one named gap, and a width derived from the verb rather than asserted over
it, with the blurb beside it wrapping against the real width instead of the guessed 104. A blurb that
wraps against a guessed width runs under a real button.

## 7. The screen explained every blocker except the one a player hits

Reproduces. Fixed in `97fe8cc`.

The detail plate has a line for the precondition it cannot meet: "at a claimed Bazaar", "behind
Automation", "research Ironworks first". Every one of those fires for a reason outside the pack.
"already yours" was on that list and is not a precondition — it is a state, and it was printed beside
`RESEARCHED` saying the same thing twice on one plate, so it is gone and the state carries its own mark.

Stand at a counter and select something you cannot afford, which is the single most common dead end in
the game, and the line was blank. A grey button, no sentence, and a red numeral in a price chip as the
whole account of why nothing happens when you press ENTER. The brief asks for exactly this state and says
the plate has to answer why not.

`_shortfall_note` now produces `short 3 Ingot`. That is the deficit rather than the price, because the
price is already on the chips two lines up and repeating it answers a question nobody asked, and it
includes the sample material a tech's analysis needs, which is a cost the chips never showed at all.

It was invisible for precisely as long as the captures were, because a fixture standing away from the
Bazaar always takes the one branch where the note is never empty.

## 8. What gold means

Not a defect report. An enumeration, from source, of `UI_ACCENT`'s call sites in `scenes/hud.gd` as they
stood before the treatment described at the end of this section. There were 29 of them. A grep today
finds `UI_ACCENT` on 18 lines of code plus its declaration and four comments, and the difference is the
treatment rather than drift in the count.

The brief says the gold rectangles carry six unrelated meanings. Counted, it is nine, and the constant's
own comment named three of them ("FORGED, selected slot, current step") as if they were examples of one.

| # | what gold is saying | sites | where |
|---|---|---|---|
| 1 | this is what you have selected | 8 | rail tab, pack slot spine, WORKS row spine, tech chip spine, hotbar slot border and glow, the selected item's name, title swatch |
| 2 | this is the live verb, press it | 1 | `_verb_button` |
| 3 | this is the next step | 4 | tech `is_next` dot, objective bullet, hint bubble rule, title goal line |
| 4 | this is a heading, or a plate's top rule | 6 | title rule, `_panel(accent)`, PRODUCTION, CONTROLS, settings header, tooltip spine |
| 5 | this is the headline number | 3 | depth, FORGED count, grand total |
| 6 | this mode is on | 2 | `PAUSED (P)`, the fast-forward chip |
| 7 | this control is engaged, or this is its value | 3 | binding chip while capturing, slider fill, settings chip active |
| 8 | something is wrong | 1 | stalled machine count |
| 9 | there is more, off the edge | 1 | `_more_mark` |

Eight of the nine are the same sentence, "look here", at different levels of precision. That is a
legibility cost and a design question, and it belongs in a palette proposal rather than an overnight
repaint. The brief is explicit: do not paint over these one by one before a menu language is chosen.

The ninth is a contradiction rather than a preference, and it is fixed. Row 8 drew a machine's stalled
count in the accent, on the one panel that also uses the accent for its heading (row 4) and its grand
total (row 5). A player who has learned across the whole game that gold means selected, available, yours
was being shown a fault in it, two rows under a gold number meaning the opposite.

The game already had the answer eight pixels away. The left-edge alert stack reports the same fact, about
the same machines, out of the same `sim.machine_problems()`, in `Color(0.96, 0.46, 0.30)`. That is
`UI_WARN` now, and both places say it the same way.

Note what the code said about itself. The line's comment read "green when all are running, amber when
some are stalled". The author named a warning role the palette did not have and reached for the nearest
amber-looking constant, which was the accent. The intention was right and was never re-derived from the
artefact: one word, in a comment, naming a colour the game does not own.

### Two pairs a palette proposal has to separate

- Row 7 puts the capturing chip and the active chip in the same gold on the same page. One means "this is
  the current value", the other means "the game is waiting for you to press a key". A settings page where
  the thing you are changing and the thing it currently is look identical is `MNU-26`'s alignment
  complaint restated as colour.
- Rows 1 and 2 are both gold and are usually adjacent: the selected row's spine, and the button that acts
  on it. That pairing is arguably correct, because it is the one place the doubling carries meaning, and
  it is the reason a proposal should not simply split the constant nine ways and call it done.

A palette split that renames without re-colouring is a fudge. Nine constants that all resolve to the same
gold would document the ambiguity and change nothing a player sees. A proposal has to say which of the
nine stop being gold.

---

# The ticket ledger

Per ticket: frame, observed problem, treatment hypothesis, files claimed, before and after evidence,
functional and accessibility checks, and one of SHIP, REVERT, RUN ONE MORE CONTROL, or DEFER. Terminal
statuses are SHIPPED, REJECTED, BLOCKED, INVALID and SUPERSEDED.

Only the tickets actually touched are listed. A ticket with work against it is not a ticket that closed;
most of those below are still open on purpose, with the reason written next to each rather than implied
by a status word.

**Corrected 2026-08-20.** This paragraph said *"five of the nine below"*, which was the tally on
2026-08-18 and was never re-derived as sections were added. The ledger carries thirteen sections
covering fifteen tickets — `MNU-06`, `07`, `10`, `11`, `12`, `18`, `20`, `25`, `26`, `27`, `29`, `29a`,
`30`, `31`, `32`. A sixteenth, `MNU-28`, has one moved line and no section of its own; it is recorded
inside the settings rebuild. A count written beside a growing list is a count that stops being true
without anything changing it.

**Corrected again, later the same day, and the second correction is the more interesting one.** The
sentence above went on to name nine tickets *"still open in whole or in part"* — `06`, `07`, `12`, `18`,
`20`, `25`, `26`, `29`, `32` — and three of those nine were not open when it was written. `MNU-20` and
`MNU-32` were closed by the very commit that wrote this paragraph, in their own headings, forty lines
apart; `MNU-12`'s remaining half merged twenty-nine minutes later. Re-derived from the code rather than
from the previous count, five are open in whole or in part — `06` and `07` in part, `18`, `26` and `29`
whole — with `25` pending the ruling described in its own section. The first correction fixed the
arithmetic and copied the list; a tally is not re-derived until its *members* are, and a list is the
part that goes wrong silently, because a wrong total looks wrong and a wrong member does not.

## `MNU-10`: the screenshot matrix (SHIPPED)

| | |
|---|---|
| frame | all of them, which was the complaint |
| observed | one menu state had ever been photographed (`_at_the_counter`), the one where the grid is neither empty nor crowded and the price is nearly affordable |
| treatment | three rungs across three tabs, plus settings and two brief-named states, for twelve canonical captures; the full rung derived by the rule `FactorySim` fills a pack by rather than from a directory listing |
| files | `tools/capture_moments.gd`, twelve `_moment_*.png` |
| evidence | findings 1, 2, 5, 6 and 7 above. Four of the five were found in the first sitting after a rung was added, and none of them is visible in the midgame rung |
| checks | `_contamination` refuses a mispose in both directions, and the at-the-counter direction is proven to fire |
| verdict | SHIP. The register is not documentation of the screens; it is the only instrument that can see them |

## `MNU-32`: accessibility is a visual requirement (SHIPPED — selection 2026-08-18, contrast and focus 2026-08-20)

| | |
|---|---|
| frame | the hotbar on the bare screen; the counter's WORKS rows and PACK wells |
| observed | `MNU-06` had just concentrated "this is the thing you can act on" into one colour and stripped that colour off seven surfaces wearing it as trim. The rule is correct, and it puts the game's whole affordance signal into a single channel. If that channel is hue, the tidying made the game less legible |
| treatment | none needed, as it turns out. This is a measurement that could have demanded one |
| files | `tools/check_selection_reads.gd`, `tools/run_harness.sh` |
| verdict | SHIP. Every selection mark in the game is a value change and not only a hue |

The measurement needs no element-finding, which is why it is worth having. Locating "the selected row" in
a frame means re-deriving the layout inside the instrument, and a layout copy is wrong the day the layout
moves. This file already records the name plate being drawn at a selection's arithmetic position while
the wells were drawn at a clamped one, which is the same bug in the other direction.

Instead: move the selection, and ask which channels notice. `|B − A|` in RGB is the whole cue, the same
in luminance is what survives greyscale, and `|A − A′|` is the floor. A mark carried by hue alone stays
large in the first and collapses to the floor in the second.

The prediction was registered before the run, on the reasoning that the counter's picked row draws a
filled plate, which is a value change before it is a hue one, and that the hotbar's lit slot swaps a
`UI_EDGE` border for `UI_ACCENT` at roughly double the luma. The layer's own header records the result:
six arms, 99 to 100% of every cue surviving luminance, at a peak step near 150 of 255.

Each surface is measured twice, and the clipped figure is the one asserted on. Moving the counter's
cursor also rewrites the detail plate with a different name, sentence and icon, and moving the hotbar's
rewrites the name plate. Those changes are large and purely luminous, and unclipped they swamp the mark
on the row. That is not a confound to apologise for, since a plate that names the selected thing is a
better non-colour cue than a spine is, but it is a different claim, so the mark gets its own arm.

Proved red by knockout. The picked PACK well was repainted a magenta at essentially the same luma as the
unpicked composite, with the gold spine recoloured to match, giving a mark that exists only in hue. The
clipped arm went to zero kept and the layer failed, while the untouched WORKS arm stayed at 100%. The
unclipped figure fell much less, which is what the clip buys.

`KEEP_MIN` is 0.90, set after six observations at 99 to 100% rather than guessed before them. Four bounds
invented in advance have been wrong in this repository. A hue-only mark scores near zero here, so there
is no near-miss region between that and the floor. `CUE_MIN` is 800 px, the floor that keeps the arm from
passing on a frame where nothing moved.

**Both halves closed 2026-08-20.**

*Contrast.* 125 text/plate pairs enumerated from the draw calls — not from constant names, since one name
lands on several plates. **Eleven were under 4.5:1; all eleven fixed by lifting ink, no plate recoloured.**
Worst was 2.98 (the ledger heading and both works group titles) and 3.35 ("N more wait behind research",
BENCH); the 4.20 cost-shortfall red became `UI_WARN` at 5.33. Seven literals across eleven sites became four
names. `GOLD_DIM` is `UI_ACCENT` under a named **uniform** drop, which holds hue exactly at 43.2 degrees
(equal channel offsets leave channel differences alone) and lands at 5.40 beside `UI_TEXT_FAINT`'s 5.39 —
the gold rung of one ramp. Measured in **WCAG relative luminance** (sRGB linearised), calibrated on
`#767676`-on-white = 4.542 against the published 4.54. That is NOT the gamma-encoded Rec.709/601 "luma" used
elsewhere in this repository, and the two are different quantities.

`check_text_contrast.gd` went from 9 pairs to 13 and now composites an ink's own alpha — the case that had
actually been failing. The live verb's key hint reads 8.30 at full strength and **3.77 as drawn**. Its
`_alpha` returns 0.0 on a missing name rather than 1.0: an error path returning the passing value is exactly
how a thinned ink reads green.

*Focus-visible.* The enumeration corrected the ticket's own premise. `scenes/settings.gd` has no input
handling at all — it is a static model; the page is drawn by `Hud._draw_settings_*` and driven by
`MainView._settings_input`. And `move_settings_row` opened with `if settings_cat != CAT_CONTROLS: return`, so
**on AUDIO and FEEL the arrow keys did nothing whatsoever**. Those controls were not focusable-without-a-
focus-state; they were unreachable, and a focus state cannot be drawn on a control that can never be focused
— so the fix had to include the traversal.

`_focus_ring` is a 2px `GOLD_PALE` outline on `grow(2.5)` with a dark keyline inside, plus the counter's
spine for row-shaped controls: the hotbar cursor's idiom at double weight, not a new invention. It is
distinguishable from selected and from hover on **three channels, any one sufficient** — shape (nothing else
on the page outlines; selection fills, hover lifts), weight (2px against the 1px every nearby edge is drawn
at), and inset (the only state painting *outside* a control's box, so it survives on a chip already filled
gold for being ON).

Reached: four audio sliders, the mute chip, three feel chips, RESET KEYS, twenty-two binding rows, the title
lamp swatch. Not reached, and recorded rather than silently skipped: alerts, machine-config knobs and the
minimap ping are mouse-only, and giving them a keyboard route is a navigation model rather than a focus
state. The settings rail is reachable by `1`/`2`/`3` but by no cursor, so there focus and selection are the
same thing and a separate caret would manufacture the very ambiguity the requirement forbids.

**A finding that did not survive its own population check, kept because the reasoning is the point.**
`UI_ACCENT` is Y709 169.3 and daylit surface terrain composites into the 180s, which reads as the
act-on-this colour losing to the ground exactly where a new player starts. **The population is empty.** All
`UI_ACCENT` draw sites are in `hud.gd` and every one lands on `UI_BG`, `UI_MODAL`, `UI_RAIL`, `UI_SLOT` or a
wash — the hotbar's backing `_panel()` is unconditional, so even the slot border sits on `UI_BG`. The only
accent mark over the world is the title's "PRESS ENTER", under an 0.82 veil that is already the scrim the
proposed fix wanted: 6.54:1 over daylit ground. Lifting the accent would have moved every passing site, plus
the derived `GOLD_PALE`, to fix zero reachable ones.

Two further errors in that same finding, both worth naming. The "180s" figure included `LIT_LIP`, a 1px
sky-facing highlight at Y709 242.9 — the brightest *pixel* is not the *plate*, and nothing is drawn on it.
And "dimmer than the ground" is a **saliency** claim, not a contrast one: WCAG contrast is symmetric, so the
number shows luminance proximity rather than a legibility failure. A saliency ticket may be worth opening;
it is not this one, and it needs a different instrument. The narrower survivor, unmeasured and recorded as
such: `Visuals.MACHINE_STYLE`'s generator casing is `Color(0.80, 0.66, 0.26)` at Y709 168.5 and IS drawn in
world space, so the luma is reachable even though the accent is not — whether a generator ever stands on
daylit ground is a placement question nobody has measured.

## `MNU-06`: gold means one thing (SHIPPED — three passes, the last on 2026-08-20; a fourth role and the plate titles remain)

> _[Section removed 2026-08-25, pivot: the Bazaar counter's gold-affordance color rules are dead design. See git history for the original text.]_

## `MNU-18`: locked, unavailable, affordable, selected and buildable are distinct (OPEN, partly treated)

> _[Section removed 2026-08-25, pivot: the Bazaar counter's BUILD-button state rules are dead design. See git history for the original text.]_

## `MNU-20`: costs read as a bill of materials (SHIPPED)

> _[Section removed 2026-08-25, pivot: the Bazaar counter's price-chip layout is dead design. See git history for the original text.]_

## `MNU-25`: outcome, cost, why-unavailable and action in one group (the consolidation SHIPPED 2026-08-20; one criterion awaits a ruling)

> _[Section removed 2026-08-25, pivot: the Bazaar BENCH detail-plate consolidation is dead design. See git history for the original text.]_

## `MNU-27` and `MNU-29`: settings alignment, and the binding list (SHIPPED (the clipping), OPEN (the rest))

| | |
|---|---|
| observed | the last of twenty-two bindings was drawn, and registered as clickable, below the bottom of the screen, in a page `check_hud_layout` had passed every run since it was written |
| treatment | two columns of eleven on a 592×286 plate, with the geometry as named constants so the layer measures the numbers the drawing uses |
| evidence | finding 1. Two failures became passes, with a rejection control |
| checks | the new assertion judges `_settings_hits`, the rects a real press routes through, so it cannot drift from what is clickable |
| verdict | SHIP. `MNU-29`'s scrollable focused surface is a redesign and stays open |

## `MNU-26`: settings without the modal bulk (OPEN, direction decided)

RULED is not a terminal status. This ticket is OPEN; what follows is a design-decision record rather than
a closure. The implementation below has landed, and `MNU-26` closes when its acceptance criterion, that
audio and accessibility settings remain reachable in one or two steps, is signed off against the named
frames. Closure proof will be the four `history/147-*` frames listed at the foot of the next section,
plus `check_hud_layout`'s settings arms.

### EVIDENCE BLOCKER CLEARED (2026-08-24) — the review can now actually happen

`settings`, `pack_fresh`, `settings_audio`, `settings_controls` and `settings_feel` (the last never shot
before) were re-shot against current `main` HEAD (`5511a17`, manifest regenerated `1119aec`) — all five now
share one renderer signature (`7f2d734618`), the property the manifest's own header asks for. This does
**not** close `MNU-26` itself: the acceptance criterion below is still a judgment call about reachability,
not something a re-shoot can answer by itself. What follows (kept below, unedited) is the ORIGINAL blocked
finding, preserved as the record of what was true 2026-08-20 through 2026-08-24 — read it for the
reasoning, not for the current state of the captures it names.

### HISTORICAL — BLOCKED ON EVIDENCE (2026-08-20): every frame this closure could be signed off against is a picture of a build that no longer exists

The blocker is on the register, not on the code. Nothing below is withdrawn and no defect is alleged
against the implementation; what is unavailable is the review.

- **The four `history/147-*` frames** were written by `09ea44c`, the settings rebuild itself, and the
  page has moved three times since. `e4a6a7c` fixed the rail printing `2 AUDIO` when 2 is CONTROLS.
  `1f0e478` took `SET_DETAIL` from 56 to 36, which is **20px off every page height in those frames** —
  the geometry recorded under *Measured* below (AUDIO 432×210, CONTROLS 432×273, FEEL 432×196) is the
  page after that cut, not the page photographed. And `65e07c5` changed which surfaces are suppressed
  while a modal is up, which is what decides whether the objective banner still prints across the
  plate's top edge in a settings shot — the defect those very frames are cited for below. The closure
  proof predates three rounds of change to the thing it would be proving.
- **The canonical menu captures are older still.** `_moment_settings.png` and `_moment_pack_fresh.png`
  were both last written by `d0ac976` on 2026-08-18 03:12 and carry renderer signature `9f26ff4788`
  (`docs/CAPTURE_MANIFEST.md:52`, `:62`). `git log --name-only d8bcc87..HEAD -- '_moment_*.png'` is
  empty, so neither has been re-shot since — not for the counter shrink (`d8bcc87`, renderer
  `94b89db3bc`), and not for the settings rebuild (`09ea44c`, renderer `c3915437e7`). The same
  signature computed over the tree's drawing sources today is `d3db3ef55a`. **Four renderers, and the
  two canonical frames are pictures of the first of them.**
- **The three per-face moments have never been written at all.** `tools/capture_moments.gd:120-122`
  poses `settings_audio`, `settings_controls` and `settings_feel`, added with the reason beside them
  (`:117-119`): *"a lone `settings` shot photographs AUDIO and says nothing whatever about the other two
  — and CONTROLS is the tall one, the one with twenty-two rows, the one every clipping defect this page
  has ever had lived in."* `git ls-files` finds one `_moment_settings*.png` and it is the lone
  `settings`. **The register can pose the three faces this ruling is about; no tracked frame holds
  them**, and the acceptance criterion — audio and accessibility settings reachable in one or two steps
  — is a claim about moving between those faces.

**What unblocks it:** re-shooting `settings`, `pack_fresh` and the three faces (`capture_moments.gd --
<moment>`, the recipes the manifest already records), then the acceptance review against those. That is
two commits, since `tools/capture_manifest.sh` necessarily lags its captures by one. Until then
"`MNU-26` closes on acceptance review of the named frames" names a review nobody can perform, which is a
worse state than an open ticket because it reads like a step rather than a stop.

The prior round drew two variants and deferred. The review reopened both arguments and took neither,
because the one recorded reason to prefer `b` is false about the code, and the cost of `a` is a live
input conflict rather than a matter of taste.

| | |
|---|---|
| `b`'s stated ground | "the counter is a place with a precondition and Settings is not" |
| what the code says | `E` sets `_inventory_open = true` in `MainView._unhandled_input` with no proximity check. `_near_bazaar()` gates exactly one field, `can_craft`, whose comment reads "the E screen reveals recipes only at the Bazaar" |
| so | the counter is a surface you carry, whose content is partly place-conditional. That is the shape Settings wants. Argument withdrawn |

| | |
|---|---|
| `a`'s cost | a binding capture cannot live inside a tab strip |
| what the code says | `if _settings_open: _settings_input(event); return` is a total intercept, which is what key capture structurally requires: it must be able to swallow any key. Meanwhile `_inventory_open` binds the digit row and the mouse wheel to tab selection |
| so | as a fourth face, rebinding an action to `3` fights the tab strip, `ESC` has to both cancel a capture and close the counter, and the wheel is unbindable by construction. Those handlers exist today |

**The decision.** `MNU-26`'s complaint, verbatim, is that Settings shares none of the panel's grammar. The
fix for that is to share the grammar, not to share the state machine. Merging the state is a strictly
stronger move than the complaint asks for, and it buys the conflict above.

Share the language. Keep the state.

So Settings keeps `_settings_open` and `ESC`, and adopts the counter's plate, rail, head and detail plate,
along with its behaviour: it sizes itself to its active category exactly as the counter sizes to its
active tab. The rail carries `MNU-31`'s categories (AUDIO, CONTROLS, FEEL), which is where the footprint
goes. The page is only as tall as the category you are on, and two of the three are short.

Verdict: **build `c`**. Both prototypes stay on disk as the record of the argument; neither ships.

## `MNU-27`, `MNU-30`, `MNU-31`: the settings page rebuilt on the counter's grammar (SHIPPED)

`MNU-26` is deliberately not in that list. Its direction is decided and its code is here, but its
acceptance criterion is a judgement about reachability that a passing layer cannot make. Closure proof
for the three shipped tickets: the frames named at the foot of this section, plus `check_hud_layout`'s
settings assertions.

What "share the language, keep the state" came to in code:

| | before | after |
|---|---|---|
| plate | `draw_rect`, hard corners, 1px border | `_round_rect` r=8, soft shadow, sheen. Elevation rather than a border |
| ground | scrim 0.55, pure black, world sharp | scrim 0.42 tinted plus vignette, world racked out of focus |
| structure | two columns of text on one fixed plate | rail, one category, detail plate |
| size | `Rect2(24, 37, 592, 286)`, fixed whatever it showed | sizes to the open category, on the counter's 0.13s clock |
| arrival | appears | rises the last 14px, eased out |
| the selected thing | nothing was selected | the row lights and the plate says what it does |
| capture prompt | one sentence at the bottom of the page, next to RESET | on the row that is capturing |

**`MNU-27`, the grid.** The old page had two control columns pretending to be one: slider bars and chips
30px apart down a single stack. That is what "several unrelated columns" meant. There is now one label x,
one control x (`SET_CTRL_DX`, 116) and one value x (`SET_VALUE_DX`, 242), and every control in all three
categories lands on them.

**`MNU-31`, the hierarchy.** AUDIO, CONTROLS and FEEL were a flat pile. They are the rail's three faces
now, reachable by click or by `1`, `2`, `3`. Nothing became harder to find: the page opens on AUDIO and
the rail names all three at all times.

**`MNU-30`, capture is a state.** "Click a binding, then press its new key" was a sentence at the bottom
of the page competing with the reset control. The row being rebound now says `press a key…` in its own
chip, its row lights, and the plate below says `press any key to bind it — ESC cancels`.

**A defect found on the way, small and real.** The mute chip was the only chip on the page whose gold
meant the negation of its own toggle. `{"toggle": "mute"}` drew active on `not Settings.muted`, while
`shake` and `auto_pickup` both drew active when engaged. So the one control that explains why the game is
silent went dark exactly when it had something to say.

**Superseded 2026-08-19: the rule was right and the chip was the wrong place to apply it.** "Gold means
the toggle is engaged" holds for `shake` and `auto_pickup`, whose chips read `ON` and `OFF` and therefore
speak in toggle-state terms. The mute chip does not. Its label reads `MUTED` or `SOUND ON`, which names
the audio state. So the two channels of one chip pointed opposite ways: the chip said `SOUND ON` in dead
grey, and said `MUTED` filled with `UI_ACCENT`, the colour documented one line from its definition as
"selection, the live verb, the next step". The most saturated element on the AUDIO page lit up precisely
when the audio was off, in the same gold as the selected rail tile and the slider fills beneath it.
Neither polarity of a two-state chip could fix that, because the fault was having only two states.
`_settings_chip` now takes a third, `warn`, drawn warm-on-dark with a warm edge. Muted is loud without
claiming to be chosen, and the earlier complaint, that it went dark when it had something to say, stays
fixed.

**`MNU-28` is not closed**, and one line of it moved. The bars are still gold fills; what changed is that
the travelled end carries a bright cap, because a long gold fill with no head reads as a progress meter,
and a meter is a thing you watch rather than a thing you drag. The control family the ticket asks for,
focus, disabled and keyboard states as a set, is untouched. `MNU-29`'s scrollable surface stays open too:
twenty-two bindings still sit in two columns of eleven, they just sit on a plate that admits it.

### What the harness had to become

`check_hud_layout` asserted `SETTINGS_CONTROLS_MIN = 26`, meaning at least 26 clickable controls or it
never opened. One category at a time makes AUDIO register 8, so that floor goes red by design.

It was not lowered. The floor's teeth were always that all twenty-two bindings are registered, on screen,
and on their plate, which is the defect it was written for. That claim now runs against CONTROLS at full
strength. AUDIO and FEEL get the same three assertions plus their own rejection control, which is
coverage the single-screen version never had, because those faces were not separately addressable. The
constant is now `SETTINGS_CAT_MIN`, a per-category floor of `[8, 25, 6]`, and a ledger line requires the
three faces to total at least 39 so nothing can go missing in a future rearrangement.

A floor that encodes the defect it was written beside will read as a regression when the defect is fixed.
The question is never whether it can be made green, but which of its claims was the real one, and whether
that claim still has a population.

The settings arms went from four assertions to six call sites, five of them inside a three-category loop,
so sixteen assertions execute per run. The shot helper poses the category through `Hud.set_settings_cat`,
since the HUD owns it and `main.gd` only asks, and it waits for the panel to stop moving and reports the
residual drift, because a rect read mid-lerp measures how many frames elapsed before the shutter.

### Measured

| | before | after |
|---|---|---|
| panel | 592×286, fixed | sizes to the open category |
| current geometry | n/a | AUDIO 432×210, CONTROLS 432×273, FEEL 432×196 |
| `check_hud_layout` settings assertions | 4 | 16 executed, from 6 call sites |

FEEL's natural height is 166 and it is floored by `SET_MIN_H` at 196, so the shortest category still
reads as a panel rather than a strip.

The HUD footprint was measured across fifteen states before and after. Exactly one row moved, and the
other fourteen were identical, which is what makes the change attributable: a treatment that changes one
row and leaves fourteen untouched is not being credited with someone else's drift. The absolute
percentages from that run are not reproduced here, because the panel geometry has moved since and a
figure quoted out of its build is worse than no figure. `check_hud_layout` reports the footprint on every
run, so it can be re-read rather than remembered.

That control mattered more than it sounds. An earlier run of this layer went red on two collision rows
and reported the entire Bazaar inside the paused screen. A pristine-tree control passed, so the obvious
reading was that the change had caused it, and that was wrong: it never reproduced, and fourteen
identical footprint rows are proof no build difference could have drawn a tech tree into a paused frame.
One failing run plus one passing control is two samples, not a cause.

### The frames

| | |
|---|---|
| `history/147-settings-was-a-slab-whatever-it-showed.png` | the page it replaced |
| `history/147-and-controls-now-fits-a-plate-that-admits-it.png` | twenty-two bindings, the tall face |
| `history/147-and-audio-is-shorter-than-controls.png` | the default face |
| `history/147-and-feel-is-shorter-still.png` | three rows, and the panel is three rows tall |

**What the frames show that the numbers do not.** The before shot is a hard-cornered slab over a sharp
world with four full-width gold bars as the loudest thing on screen, and its `MUTED` chip is grey while
every bar is full gold, which is the inverted-gold defect above, photographed. The after shots have the
world racked out of focus behind a rounded elevated plate, one category, and one alignment.

**A defect the frames also show, which is not fixed here.** The objective banner's second line, "Dig ore
— hold LMB on the metal-flecked rock by spawn", is cut in half by the plate's top edge in both the before
and after shots. It is furniture drawn before the modal and unsuppressed by it. Pre-existing, unchanged,
and now the most visible thing wrong with this screen. It belongs to `MNU-07`, which stays open.

**Fixed since, by `65e07c5`, and recorded here rather than struck out above.** `_draw_objective_line`
was called unconditionally; it is now inside `if not _modal_open():` along with the depth chip, the
production chip, the hotbar, the key legend, the hint bubble and the alert stack
(`scenes/hud.gd:538-563`). The banner does not print over the settings page any more. Two consequences
worth separating: the paragraph above is still an accurate description of **those four frames**, which
is why it stands; and it is no longer a description of the game, which is why any reader reaching for it
as a live defect should stop. It also means the `147-*` frames now differ from the current build in one
more visible way than their geometry — see the evidence blocker under `MNU-26`.

## `MNU-29a`: the silent duplicate key binding (SHIPPED (per-event, guarded))

It was marked SHIPPED once before and was not. The first fix compared `Settings.binding_label`, which
returns `events[0]`, while `Controls.defaults()` gives 17 of its 25 actions two or three events. Resolver
and detector were both blind to a collision on any event but the first, so the live reproduction stayed
three inputs from the page: CONTROLS, `jump`, press the up arrow, after which the arrow climbs and jumps
on every press with nothing said. The demonstration that closed it, rebinding `jump` to `W`, passed only
because `W` happens to be `sf_up`'s first event. It was run on the one input where the bug was visible to
the instrument measuring it. That is why this row now carries a mutant kill instead of a reproduction.

Underneath sat a larger, unticketed bug. `rebind` did `bindings[action] = [spec]`, and `_apply_action`
opens with `action_erase_events`, so every rebind destroyed that action's other events: rebind grapple to
a key and middle-mouse-grapple and right-bumper-grapple are gone. On every rebind, not only a colliding
one. Unannounced, because `_announce_rebind` reports only displaced other actions. Persisted by
`save_settings` and reapplied by `load_settings` on every boot thereafter. It fires on a player who never
picks a used key at all, which makes it the bigger of the two, and it had no ticket. `check_gamepad`
could not see it either, because it reads the static defaults table and never asks `InputMap` what is
live.

Both work at per-event grain now. A rebind moves one event, with the new spec replacing the action's
event of the same device, desk for desk and pad for pad, and displacement takes only the colliding event
from its previous owner, so `climb up` keeps `W` and its stick when the arrow is taken.

**A functional defect wearing a presentation ticket.** `Settings.rebind` wrote the new key and returned;
it had never checked for a conflict of any kind. From defaults: open CONTROLS, click `jump`, press `W`.
`W` is now `climb up` and `jump`. Both fire on every press. The config persists it. Nothing anywhere says
a word, and it survived ninety-odd harness layers, because every one of them asked whether the page drew
correctly and none asked whether the page could lie.

| | |
|---|---|
| observed | two actions holding one key, firing together, persisted, unannounced |
| treatment | the new binding takes the key; every displaced action is unbound, returned to the caller, and announced |
| evidence | `history/149-two-rows-holding-the-same-key-and-saying-so.png`, both rows warn-orange, the plate reading "W is also climb up" |
| known limit | a flagged row can show a key that is not the one clashing. `history/150-the-arrow-that-climbed-and-jumped.png` is the fix working and the limit in one frame: `climb up` is orange while its chip reads `W`, because the collision is on its second event, the up arrow. The detail plate names the real culprit ("Up is also climb up") and the chip cannot, since a row has room for one key. That is the honest cost of detecting at per-event grain while displaying at per-action grain, and it is strictly better than the previous state, where the row was not flagged at all. The real answer is a per-event editor, which is `MNU-29`'s scrollable surface, where 22 rows would become up to 41, and it is deliberately not folded in here |
| checks | `tools/check_binding_conflict.gd`, registered and green, and mutant-killed, which is the part that matters. Restore the destructive `rebind` and it reports 5 failures; revert the detector to the first-event predicate and it reports 3. Both mutants were applied to production code, run, reverted, and the sources verified byte-identical afterwards. It also carries the arm that makes the upgrade a result rather than a claim: the superseded first-event comparison is recomputed beside the new one, on the same state in the same process, and reports nothing |
| **the half this heading was missing (2026-08-20)** | it said SHIPPED, and the door was guarded while the room was never counted. `rebind` made a duplicate impossible to CREATE through the page; `load_settings` read the `bindings` section straight off disk into `apply_bindings` with no conflict check anywhere on that path, so a `settings.cfg` written by the pre-fix build reinstated the duplicate on every boot and both actions fired on every press. Nothing had to be wrong with the current build for it to happen, and the page would only have shown it if you opened it. Closed in `f128b8a`: reconciliation runs after the read and before the apply, at the same `event_labels` grain the detector uses, so the loader cannot decline a conflict the page displays. Precedence is an override over a default, then `Controls.defaults()` order — deliberately not the config's own key order, which is write order and so is the order the player happened to rebind in. An action reconciled down to nothing gets its own free default back, and if nothing is free the duplicate STANDS rather than the action going silent, with the decision recorded so that outcome is distinguishable from a pass that never ran |
| **worth noting about this ledger** | the two documents disagreed and were wrong in OPPOSITE directions. This heading read SHIPPED while the load path was open; the index row in `docs/VISUAL_RECOMMENDATIONS_SURFACE.md` listed three things as remaining, two of which had already shipped. Reading either alone gave a wrong picture of the same ticket, and neither was checked against the code until now |
| verdict | SHIP. `MNU-29`'s scrollable focused surface is still a redesign and stays open |

**Steal rather than refuse, and the reasoning is not aesthetic.** Refusing a used key would make it
unbindable until you first went and cleared its owner, which is a chore on the one page whose entire job
is rebinding. Stealing cannot leave a duplicate behind, the displaced action is left visibly `unbound` on
its own row rather than quietly losing its key, and RESET KEYS is one chip away. `MainView` then says
what it cost: "climb up unbound — that key is taken". A silent steal would be the original defect wearing
a fix: the duplicate gone, and the player still not told what happened to the binding they lost.

### One predicate, or the display and the fix are about different things

`Hud._binding_clashes()` marks a row as clashing by comparing labels. `Settings.rebind` now resolves by
comparing the same labels.

If the resolver compared something else, `InputMap.action_has_event` or a hand-rolled spec equality, the
page could display a conflict the resolver did not resolve, or silently resolve one it never showed. Two
predicates for one relationship is two relationships.

The label is also the thing the player reads off the chip, so the comparison the code makes and the
comparison the player makes are the same comparison.

### Keyboard operation, and why the arrows are raw keycodes

Rebinding used to require a mouse, because the only way to start a capture was to click a chip. That
makes the one page a player visits *because* their input is not working the page they cannot reach
without it. Arrows move a focus cursor, Enter starts the capture, and ESC still cancels and keeps the old
binding.

The cursor is read as physical keycodes, never as actions. Navigating with `Controls.UP` would mean that
rebinding `climb up` changes how you move around the page you are rebinding it on, and rebinding it to
something unreachable would strand you there. Raw keycodes cannot be remapped, so the page stays operable
no matter what the player does to their bindings.

**Focus is not hover, and does not look like it.** Hover is a warm fill under wherever the pointer
happens to be. Focus is a claim about where the next keypress lands, and it persists with no pointer on
screen at all. So focus takes the rail's own gold edge bar, the mark this UI already uses for "this is
the selected one", and the two can sit on different rows without either being ambiguous.

### The knockout is the assertion that matters

"The defaults carry no duplicate binding" passes trivially against a detector that can never fire, and
that is the failure this project keeps finding. So the layer forces a duplicate by writing
`Settings.bindings` directly, past `rebind`, past the very function that now prevents it, and requires
the detector to report both rows and to name each action to the other. Verified: two flagged, both
holding `W`, before any resolution ran.

## `MNU-07`: when the world shows behind a modal (OPEN, the transparency half closed)

`UI_BG` is 90% opaque because furniture sits over the world. A modal is not furniture: at 0.90 the
objective banner read straight through the settings page, and ten percent of a lit banner over an unlit
panel is about twice the panel's own value. The plate is opaque now. The ticket's actual question, a
quiet opaque work surface versus a deliberately contextual counter view, is untouched.

The second half was never transparency at all. The banner, the depth chip, the hotbar and the keybind
strip were being DRAWN over a modal rather than showing through it, so each came out in two pieces — one
half dimmed by the modal's own scrim, the other covered by its plate — and a chip cut by an edge reads as
a drawing fault rather than as a chip. `_modal_open()` is now one rule for the question instead of one
per surface, and the seven world surfaces stand down together while a modal owns the screen.

### Verified against the build rather than against the record (2026-08-20)

Every claim in this section was re-shot before being written down, because the frames the previous
review ran on were pictures of a build that had already moved. **The frame: commit `0149062`, renderer
signature `821c12b26a`, thirteen moments through `capture_moments.gd`'s ordinary path, redirected by
`SF_MOMENT_DIR` so the canonical set was not touched.** Naming the tree matters here more than usual —
three of the findings below were real when they were written and are now pictures of code that no longer
exists, and there is no way to tell those apart from a live defect except by re-shooting.

| claim under review | on `0149062` |
|---|---|
| objective subtitle sliced by the modal's top edge; hotbar protruding below | **not reproduced.** No world furniture survives a modal in `settings_controls`, `pack_full`, `bench_full` |
| settings page drawing bindings below the bottom of the screen | **not reproduced.** Twenty-two bindings, two columns of eleven, every row inside the plate |
| objective banner overprinting the depth chip and the FORGED counter | **not reproduced.** `room`: `15 m THE CLAYBAND` top-left and `FORGED 0` top-right, both whole |
| the hint strip ellipsising its own instruction (`…(face it, press…`) | **not reproduced.** `room` reads `F hook · Q drop · E pack · M map · H keys` in full |
| pack icons darker than the well they sit in, a row of near-black on dark | **not reproduced.** The row cited reads canister, plate, splitter, furnace, wedge, arrow, mark, block, gear — all distinct against `UI_SLOT` |
| depth chip and layer banner contradicting each other | **reproduced, and materially smaller.** They now agree on the layer and differ only on the number: the chip says `15 m` where the banner says `10 METRES DOWN`. The banner names the depth at which the band BEGINS and the chip names where the body is, which is defensible and still reads as a contradiction. **Stays open, and stays a ruling rather than a defect** |

Three of six were fixed by work that landed after the review and before it could be acted on. That is the
cost the capture set imposes when it lags the tree: not a wrong conclusion, but a list of repairs to
things that no longer need repairing, indistinguishable at reading time from the ones that do.

## `MNU-11`: PACK's fresh-game empty space is intentional now (SHIPPED)

> _[Section removed 2026-08-25, pivot: the Bazaar PACK tab's fresh-game layout is dead design. See git history for the original text.]_

## `MNU-12`: the detail plate's vertical dominance in PACK (SHIPPED — clipping and inspector both, 2026-08-20; the height lever refused on evidence)

> _[Section removed 2026-08-25, pivot: the Bazaar PACK tab's detail-plate layout is dead design. See git history for the original text.]_

## What is not claimed

`MNU-01` to `05`, `08`, `09`, `13` to `17`, `19`, `21` to `24`, and `33` to `35` have had no work.
The four screens still read as four dark applications, and nothing above changes that. These are defects
found while building the instrument the redesign needs, not the redesign.

**Corrected 2026-08-20.** This line read *"`MNU-01` to `05`, `08`, `09`, `11` to `17`, `19`, `21` to
`24`, `28`, and `30` to `35` have had no work"*, and it disclaimed six tickets this same file credits
elsewhere: `MNU-30` and `MNU-31` carry a SHIPPED heading, `MNU-32` carries another, `MNU-28`'s one moved
line is recorded inside the settings rebuild, `MNU-11` shipped in `d8bcc87`, and `MNU-12` has the
refusal recorded above — a considered no is work against a ticket even though the ticket stays open.
**The mechanism was the notation.** `30` to `35` and `11` to `17` are shorthand for lists, not claims
about intervals, and each swept up tickets whose sections sit a few hundred lines further up this file.
A range is the cheapest way to write a disclaimer and the easiest way to disclaim something true.
