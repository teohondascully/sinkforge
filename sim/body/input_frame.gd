class_name InputFrame
extends RefCounted

## One tick's raw input, the same shape a human's input would produce -- `docs/ARCHITECTURE.md` §5's
## "raw" action level, built from the start rather than as a throwaway pre-interface shim
## (`docs/ONBOARDING.md`: "that early validation driver is not a throwaway harness... it is built as
## the raw action level described above from the start"). `interface` doesn't exist yet; this is what
## a `Command` will eventually wrap.

var move_dir: int = 0        ## -1 left, 0 none, +1 right
var jump_pressed: bool = false  ## true only on the tick the button transitioned to held
var jump_held: bool = false     ## true for every tick the button is down
var mantle_hold: bool = false   ## toward-and-up held, docs/ARCHITECTURE.md §9's mantle trigger
var dig_pressed: bool = false   ## true only on the tick the button transitioned to held, same edge-
                                 ## triggered shape as jump_pressed -- one dig per press, not a hold-to-
                                 ## clear-a-wall auto-repeat (docs/DECISIONS_LEDGER.md D0110)

## --- cursor-aim mining (Slice 1, docs/DECISIONS_LEDGER.md D0195) --------------------------------------
##
## `mine_held` is deliberately NOT edge-triggered, and is the one field here that isn't. Mining is
## hold-to-charge: the charge a cell has accumulated is a function of how many CONSECUTIVE ticks the button
## was down while aimed at it, so an edge would throw away the entire signal. `dig_pressed` above keeps its
## edge because it is a different verb (one press, one column) and both exist during Slice 1.
var mine_held: bool = false

## Where the player is aiming, as a TERRAIN CELL, resolved before the frame reaches the sim. The sim is
## engine-free and has no viewport, no canvas transform and no cursor -- turning a pointer into a cell is a
## `view/` job (`view/controls.gd`), and this field is the result crossing the boundary. At Slice 2 this
## becomes `Command.Mine(target_cell)`'s payload.
##
## AIM IS STATE-AFFECTING INPUT, which is why it is recorded per tick alongside the buttons: which cell a
## hold charges depends on it, so a replay that could not restate the aim would diverge. `has_aim` is a real
## bool rather than a sentinel cell compared against null, for the same reason `Controls._posed` is
## (`docs/DECISIONS_LEDGER.md`'s guards-that-cannot-be-false class); cell (0,0) is a legitimate aim.
var has_aim: bool = false
var aim_col: int = 0
var aim_row: int = 0

## --- the line and the rope (A' step 5c, D0360) ---------------------------------------------------------
## `grapple_pressed` is an edge like `jump_pressed`: the tick the throw key went down, the hook flies (or
## chains) toward the aim cell above. `climb_dir` is the vertical axis (+1 up, -1 down), NOT an edge: it
## reels the line in or pays it out every tick it is held, and rides a gripped rope the same way.
var grapple_pressed: bool = false
var climb_dir: int = 0
