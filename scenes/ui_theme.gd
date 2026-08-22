class_name UiTheme
extends RefCounted

## THE PAGE'S INK AND ITS PLATES, owned in one place.
##
## These lived on `Hud`, which made the page that draws with them the only thing that could name them.
## Every cluster extracted out of that page would have had to reach back for a colour, and the mocks that
## exist to judge a proposed look already did, through `Hud.UI_ACCENT`.
##
## It is deliberately NOT in `Visuals`. That file is the world's renderer: machine casings, glyphs,
## material colours, the things in the shaft. A user-interface palette is a different subject that happens
## to also be colours, and merging them would make "where does this colour live" a question with no
## principled answer.
##
## `Hud` aliases every name below, so its two hundred and five call sites read unchanged and
## `check_text_contrast` still finds them all in the page's own constant map, which is what that layer
## reads rather than trusting a global class cache.

## --- UI skin palette -------------------------------------------------------------------------------
##
## The HUD used to hold the two brightest values in the frame, which pulled the eye to the chrome and
## away from the play space. Both are stepped down here; they keep plenty of contrast against their own
## near-black panels. Nothing in the UI should ever be brighter than lit rock.
const UI_BG := Color(0.07, 0.08, 0.115, 0.90)        ## panel fill
const UI_EDGE := Color(0.30, 0.34, 0.42)             ## panel border
const UI_EDGE_HI := Color(0.52, 0.58, 0.68, 0.45)    ## top bevel highlight → panels read as raised
## Gold never labels and never counts. It marks only what the player's input is connected to: the
## selection, the verb that acts on it, the next available research node, an engaged control. The nine
## sites where the accent was pure information now draw in text colours, and the call sites are
## all in this file, and the roles that kept the accent are walked through below.
##
## A machine's stalled count belongs in `UI_WARN`, not here.
##
## Three of those four roles are now settled, by putting one question to every gold mark in the file
## rather than to the ones anybody remembered: can a player's input reach the thing this mark is on,
## right now? Twenty-four draw sites, and only the ones that answer yes keep the accent.
##
##   The live verb keeps it, because it is the definition: `_verb_button`'s slab, and the title's
##   `[ENTER] descend`.
##
##   The selection keeps it for a mechanical reason rather than a preference. Every gold selection mark
##   here is the argument of the gold verb beside it. The picked row is what `bazaar_action()` acts on,
##   the lit hotbar slot is what a click places, the lit rail tab is the page the keys now drive. That
##   is the verb's own sentence said about the noun, which is why the pair was never worth splitting.
##   Two marks were hiding inside the role without being selection. The settings rail lit its glyph
##   when a category was on or when the pointer was merely over it, so two categories could wear the
##   selection colour at once and the gold one under the hand was not the page you were on; the
##   counter's rail passes `on` alone, and the two rails are otherwise written to be one thing. The
##   pack grid's `HELD` badge marks a well that is usually not the cursor, in the cursor's own colour
##   family, which put two golds meaning two things on one grid.
##
##   The next step splits. The bench's `is_next` lamp keeps gold, since it marks the one node a
##   keystroke can buy and it is the middle rung of a lamp whose other rungs are done and locked. The
##   objective bullet and the hint bubble's spine do not, because both are printed on plates that take
##   no input at all. That is the sentence the item tooltip's spine was already moved off gold for, and
##   it leaves the bare screen carrying gold on exactly one thing, the lit hotbar slot.
##
## An engaged control is the fourth role and it stays open on purpose. `_settings_chip` fills gold for
## on while `_settings_controls` fills gold while it is capturing a key, so a state and a live input
## share one colour on one page. The split is decidable, since capture is where every key you press is
## going while on is a fact about the toggle. The repaint is not: the chip's dark type is a literal on
## a fill no contrast layer can name yet, so moving it would swap a measured pair for an unmeasured one.
const UI_ACCENT := Color(0.80, 0.66, 0.30)           ## gold accent: selection, the live verb, the next step
## The same gold seen under more light, which nine sites wrote out as a bare literal: the lit rail
## glyph, the lit settings glyph, the HELD badge, three detail-plate titles, the selected works row, the
## picked bench chip and the hot slider cap.
##
## It is gold and not a second amber. In HSV it sits at hue 42.3 against `UI_ACCENT`'s 43.2, at 0.67 of
## its saturation and 0.95 of its value. That derivation is clean in HSV and not in RGB: no single scale
## reproduces all three channels, so it is written as a channel lift and moving the accent moves this
## with it.
const GOLD_PALE_LIFT := Color(0.149, 0.171, 0.249, 0.0)
const GOLD_PALE := Color(UI_ACCENT.r + GOLD_PALE_LIFT.r, UI_ACCENT.g + GOLD_PALE_LIFT.g,
	UI_ACCENT.b + GOLD_PALE_LIFT.b)
## The same gold seen under less light, `GOLD_PALE`'s opposite number. It was written as the gold rung
## of the type ramp whose grey rungs are `UI_TEXT` / `UI_TEXT_DIM` / `UI_TEXT_FAINT`, and that claim did
## not survive being tested; see below, and see where its callers went. Three literals were doing this
## one job across five sites with nothing relating any of them to the accent they are a darker cut of:
## `0.451/0.365/0.180` on the pack ledger's heading and the works group titles, `0.451/0.402/0.280` on
## the "N more wait behind research" line and its BENCH pointer, and `0.58/0.48/0.32` on the detail
## plate's refusal note. The same shape as the four literals that became `UI_TEXT_FAINT` one layer up.
##
## Measured against the plates they print on, those three read 2.98, 3.35 and 4.37 to one, every one of
## them under 4.5. Subordinate was the intent at all five sites and they are still plainly subordinate
## here: this lands at 5.40:1 on `UI_MODAL` against `UI_TEXT_FAINT`'s 5.39 on the same plate. It is the
## third rung, in gold, at the third rung's readability. The `BAZAAR` title beside it is `UI_TEXT` at
## 12.57, so nothing has been promoted. A heading that measured 2.98 was not subordinate, it was absent.
##
## The argument for these headings being gold at all was that a rung is not a meaning: this is a type
## weight that happens to be gold, the way `UI_TEXT_FAINT` is a type weight that happens to be grey,
## carrying no affordance claim at any of its sites. The parallel is exactly where it fails. Grey is
## free, because nothing in this file means anything by grey beyond "less of your attention", so a rung
## cut from it inherits nothing. Gold is not free. It is the single channel the whole act-on-this signal
## was concentrated into, said one line from its own declaration, and a rung cut from a colour that
## already carries a meaning inherits the meaning and only changes the volume. So a gold heading says
## "act on this, quietly", which is the sentence that was stripped off seven surfaces to get here.
##
## The direction of the drop is the worst one available, because dim is already spoken for. An
## unaffordable row's name is `UI_TEXT_FAINT`, the dead verb is 0.44 grey, a muted slider is the accent
## at 0.55 alpha: dim is this file's word for "not for you right now". A dimmed cut of the affordance
## colour therefore reads as a disabled affordance, and it was sitting directly over the works rows,
## where dim really does mean you cannot afford it.
##
## So the label sites moved to `UI_TEXT_DIM`, the grey ramp's subordinate rung, which was already an
## asserted pair on this plate rather than a colour invented to receive them. It measures 6.15:1 on
## `UI_MODAL` against this constant's 5.40, brighter rather than quieter, and still a clear step under
## the `UI_TEXT` the rows and the ledger's verdict beside them are drawn in. Three have gone: the ledger
## heading, both works group titles, the research pointer. What is left here is the detail plate's
## refusal note, which is a state rather than a heading and belongs to a pass over that plate.
##
## The drop is uniform, and that is the derivation. Subtracting one value from all three channels leaves
## every channel difference untouched, so the hue is preserved exactly: 43.2 degrees here and 43.2 on
## `UI_ACCENT`, where `GOLD_PALE`'s uneven lift moves the hue by 0.9. It sits at 1.25x the accent's
## saturation and 0.83 of its value, the accent in shadow, which is what a subordinate heading is.
const GOLD_DIM_DROP := Color(0.14, 0.14, 0.14, 0.0)
const GOLD_DIM := Color(UI_ACCENT.r - GOLD_DIM_DROP.r, UI_ACCENT.g - GOLD_DIM_DROP.g,
	UI_ACCENT.b - GOLD_DIM_DROP.b)
## The colour the alert stack uses for a machine in trouble, named so the other site reporting the same
## fact says it the same way instead of reaching for the accent.
##
## A third caller has arrived since. The counter's cost numerals printed a shortfall in
## `0.804/0.427/0.376` at two sites, `_cost_glyphs` and `_detail_chip`, and on the selected row's brass
## plate that literal measured 4.20:1, under the floor. It is the same fact this constant already names,
## said in a second colour that nothing in the file related to the first; the note in
## `_settings_controls` had already written the argument out ("the only other thing in this UI that
## means 'this will not do what you think'") and then reached for a literal anyway. On brass it is 5.33
## now, and 6.33 and 6.02 on the two washes the same numerals land on elsewhere. The green partner is
## untouched: it clears everywhere it is drawn, and moving a passing colour buys nothing and costs a hue.
const UI_WARN := Color(0.96, 0.46, 0.30)
const UI_TEXT := Color(0.80, 0.83, 0.89)
const UI_TEXT_DIM := Color(0.54, 0.58, 0.66)
## The third rung of the type ramp. It replaces four literals doing one job across eight sites
## (`0.36/0.39/0.45` five times, plus `0.34/0.37/0.43`, `0.45/0.48/0.56` and `0.26/0.28/0.34`) which
## measured between 2.04:1 and 3.96:1 against the plates they print on, while the two inks above them
## clear 4.5:1 with room to spare. This is the same role at a value that clears it too.
##
## Named as much as lifted: a literal is invisible to `tools/check_text_contrast.gd`, and a floor can
## only be held against something that has somewhere to be held.
##
## Three more joined it on a second pass, missed the first time because they are not on a named plate:
## `0.40/0.42/0.48` on a locked bench chip (3.38 on the 0.022 wash), `0.40/0.43/0.50` on the settings
## detail plate's placeholder sentence (3.76 on a 0.22 black well over the modal) and `0.42/0.45/0.53`
## on the settings page's own `SETTINGS` word (3.95 on the modal). All three sit at hue 222 to 225
## degrees against this constant's 220, one rung below it in value and nowhere near the floor.
##
## There is no fourth rung, which is a finding rather than an aside. The obvious repair was another step
## down the ramp, which already carries a unit: `UI_TEXT_DIM` minus this is 0.04 on every channel. That
## colour measures 4.70 on the modal, 4.49 on the 0.022 wash and 4.19 on the 0.050 wash, so a rung below
## this one cannot clear 4.5 on the plates these three land on. The quiet those sites were reaching for
## does not exist in this palette. They are this rung: 5.15, 5.55 and 5.39 respectively.
const UI_TEXT_FAINT := Color(0.50, 0.54, 0.62)
const UI_SLOT := Color(0.11, 0.12, 0.16, 0.95)       ## empty hotbar slot well
## The modal plate, which the counter and the settings page carried as two copies of one literal. It is
## opaque on purpose. `UI_BG` is 90% because furniture sits over the world and is meant to; a modal is
## not furniture, and at 0.90 the objective banner read straight through the settings page.
const UI_MODAL := Color(0.062, 0.070, 0.094, 0.985)
## The rail behind both tab strips. `RAIL_ON_FILL` is a plain lift off this value, so a rail that moves
## now takes its own lit tile with it.
const UI_RAIL := Color(0.043, 0.049, 0.070, 0.92)
