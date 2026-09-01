class_name UiTheme
extends RefCounted

## THE PAGE'S INK AND ITS PLATES, owned in one place. Lifted from `legacy/scenes/ui_theme.gd`
## (`docs/LEGACY_GAP.md` T1 #7) — the numbers AND the measurements that justify them, because the
## measurements are the asset. Every ratio quoted below was measured by legacy's own
## `check_text_contrast` layer against the plates each ink actually prints on; a rebuild that re-picked
## these by eye would be throwing away work it cannot recover by trying harder.
##
## LIFTED WHOLE RATHER THAN TRIMMED TO TODAY'S CONSUMERS, and that is a deliberate departure from how
## `view/visuals/miner_look.gd` was ported. There, unreachable BRANCHES were omitted, because a branch
## that can never be true is one nobody can test and it reads as supported. A colour token is not a
## branch: it cannot be silently wrong, it has no execution path, and the thing that makes it valuable —
## the measured ratio against a named plate — is exactly what gets lost if a later session re-derives it
## by eye. So the ink ladder comes over intact and the tokens with no consumer yet are marked.
##
## What is NOT lifted: legacy's bazaar and settings LAYOUT constants (`BAZAAR_RAIL`, `BAZAAR_PAD`, the
## rail skin). Those are geometry for specific pages that do not exist here, and geometry — unlike a
## contrast ratio — is re-derivable from the page once the page exists.
##
## Deliberately NOT merged into `view/visuals/material_look.gd`, for legacy's own stated reason: that
## file is the WORLD's palette (rock, ore, the things in the shaft). A user-interface palette is a
## different subject that happens to also be colours, and merging them makes "where does this colour
## live" a question with no principled answer.

## --- The plates ------------------------------------------------------------------------------------
##
## Legacy's finding, ported with the constants: the HUD used to hold the two brightest values in the
## frame, which pulled the eye to the chrome and away from the play space. Both are stepped down here.
## **Nothing in the UI should ever be brighter than lit rock.**
const UI_BG := Color(0.07, 0.08, 0.115, 0.90)        ## panel fill; 90% because furniture sits over the world
const UI_EDGE := Color(0.30, 0.34, 0.42)             ## panel border
const UI_EDGE_HI := Color(0.52, 0.58, 0.68, 0.45)    ## top bevel highlight -> panels read as RAISED, not outlined

## The modal plate, opaque on purpose. `UI_BG` is 90% because furniture is meant to sit over the world;
## a modal is not furniture, and at 0.90 legacy's objective banner read straight through the settings
## page. NO CONSUMER YET — there is no modal in this build.
const UI_MODAL := Color(0.062, 0.070, 0.094, 0.985)

## The rail behind a tab strip, and the empty hotbar slot well. NO CONSUMER YET.
const UI_RAIL := Color(0.043, 0.049, 0.070, 0.92)
const UI_SLOT := Color(0.11, 0.12, 0.16, 0.95)

## --- The inks --------------------------------------------------------------------------------------

## GOLD NEVER LABELS AND NEVER COUNTS. It marks only what the player's input is connected to: the
## selection, the verb that acts on it, an engaged control, the next available step. Legacy found nine
## sites where the accent was pure information and moved every one of them to a text colour. Carrying
## that rule over matters more than carrying the colour, because the colour is enforceable only by the
## rule.
const UI_ACCENT := Color(0.80, 0.66, 0.30)

## "This will not do what you think." Measures 5.33 on brass and 6.33 / 6.02 on the two washes the same
## numerals land on elsewhere. NO CONSUMER YET.
const UI_WARN := Color(0.96, 0.46, 0.30)

## The type ramp, three rungs, and the third one is a finding rather than a colour.
##
## `UI_TEXT_FAINT` replaced four literals doing one job across eight sites (`0.36/0.39/0.45` five times,
## plus `0.34/0.37/0.43`, `0.45/0.48/0.56`, `0.26/0.28/0.34`) which measured between **2.04:1 and
## 3.96:1** against the plates they printed on, while the two rungs above them clear 4.5:1 with room.
##
## THERE IS NO FOURTH RUNG, and legacy wrote down why rather than leaving the gap unexplained. The
## obvious repair was another step down the ramp, which already carries a unit: `UI_TEXT_DIM` minus
## `UI_TEXT_FAINT` is 0.04 on every channel. That colour measures 4.70 / 4.49 / 4.19 on the three plates
## in question — so a rung below this one **cannot** clear 4.5 where it would be needed. The quiet those
## sites were reaching for does not exist in this palette.
const UI_TEXT := Color(0.80, 0.83, 0.89)
const UI_TEXT_DIM := Color(0.54, 0.58, 0.66)
const UI_TEXT_FAINT := Color(0.50, 0.54, 0.62)

## "Already yours" — owned rungs, a researched name, a verb with nothing left to run. Three surfaces,
## one meaning, so it is one colour. NO CONSUMER YET.
const STATE_INK := Color(0.48, 0.70, 0.52)

## --- Layout ----------------------------------------------------------------------------------------

## The authoring canvas. Everything the page lays out is in these coordinates and is scaled to the
## window, which is why a layout number in a HUD painter is a number you can reason about rather than a
## fraction of an unknown viewport.
const CANVAS := Vector2(640, 360)


## Legacy's `Hud._panel`, the one drawing primitive every chip and plate is built on. Fill, then a
## one-pixel bevel highlight along the TOP edge only, then the full border.
##
## The bevel is the whole reason panels read as raised rather than as outlined boxes, and it is why this
## is a function rather than three call sites: legacy drew ~205 panels and every one of them got the
## bevel because they all came through here. `docs/DECISIONS_LEDGER.md` and the director's own standing
## note (`menus must read 2026`) both say elevation, not borders.
##
## `alpha` multiplies every layer's own alpha rather than replacing it, so a fading panel keeps the
## 0.90/0.45 relationship between its fill and its bevel instead of flattening to one value.
static func panel(ci: CanvasItem, rect: Rect2, alpha: float = 1.0) -> void:
	ci.draw_rect(rect, Color(UI_BG, UI_BG.a * alpha))
	ci.draw_line(rect.position + Vector2(1.0, 1.0),
		rect.position + Vector2(rect.size.x - 1.0, 1.0),
		Color(UI_EDGE_HI, UI_EDGE_HI.a * alpha), 1.0)
	ci.draw_rect(rect, Color(UI_EDGE, UI_EDGE.a * alpha), false, 1.0)
