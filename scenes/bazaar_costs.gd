class_name BazaarCosts
extends RefCounted

## THE ONE PLACE THAT DECIDES WHETHER A PRICE CAN BE PAID.
##
## Four surfaces ask that question -- the works row, a detail chip, the price walked under a card, and
## the verb button that goes live or stays grey -- and each of them has to give the same answer about
## the same ingredient, because a reader only ever sees one of them at a time.
##
## It has its own file rather than sitting on `BazaarPage`, and the reason was measured rather than
## felt. Counted as the works tab's helpers, these three tie the detail plate and the works tab into one
## component and the page cannot be separated along the seams it really has; counted as shared, the same
## call graph comes apart into detail, pack, works and bench over a small common core. Seventeen lines
## were holding four units together.
##
## Everything here is `static` and is handed the stock it reads. Nothing holds state, nothing draws, and
## nothing reaches back into a page: a unit that needs an affordability answer depends on this, and this
## depends on nobody. That is the property that has to survive the split.


## The one subtraction, and the one predicate. What this ingredient is short by: positive while the pack
## cannot cover the line, zero or below once it can.
##
## Everything that tells an outstanding ingredient from a settled one reads this and nothing else: the
## order the price is walked in, the card under a detail chip, the sign on both surfaces' numerals and
## the ink they are drawn in. `have < need` was written out at four addresses before, which is
## survivable only while the four cannot disagree. They can, and a mark that disagrees with the colour
## beside it about one ingredient is worse than either cue missing, because each reader only ever sees
## one of them.
static func gap(inventory: Dictionary, item: StringName, need: int) -> int:
	return need - int(inventory.get(item, 0))



## The counter's name for the question, and NOT a second implementation of it. The rule belongs to the
## layer that gates the spend; see `FactorySim.can_afford` for why two copies of it was a bug waiting for
## a disagreement rather than a tidy-up.
static func can_afford(inventory: Dictionary, cost: Dictionary) -> bool:
	return FactorySim.can_afford(inventory, cost)


## The bill-of-materials order: the lines you still owe first, the lines the pack already settles after.
##
## The numerals were the half of this that shipped first, a deficit printing as a signed `-N` instead of
## leaving the subtraction to the reader, and fixing a numeral does not make a row of chips a bill. A
## bill is a list whose outstanding lines are grouped, because the only question anybody brings to a
## price is which lines are still open. Interleaved, that question is a scan of every ingredient and a
## comparison per chip. Grouped, it is a glance at the front of the price, and the count of open lines is
## the length of the first run.
##
## Stable inside each run, so a recipe keeps the order its `.tres` or its rung wrote it in and the only
## thing that ever moves a chip is that ingredient crossing the line. The crossing is the point rather
## than the price of it: the frame where you pick up the last ingot is the frame the owed run gets
## shorter, which is the most direct feedback on the panel and the one thing a static row could never say.
##
## It sorts the works rows and the detail plate alike, so a machine's price does not rearrange itself
## between the row you picked it from and the plate that prices it.
static func order(inventory: Dictionary, cost: Dictionary) -> Array[StringName]:
	var owed: Array[StringName] = []
	var settled: Array[StringName] = []
	for item: StringName in cost:
		if gap(inventory, item, int(cost[item])) > 0:
			owed.append(item)
		else:
			settled.append(item)
	owed.append_array(settled)
	return owed
