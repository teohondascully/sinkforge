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
