# Playtest Journal - Stranger 3

## Initial State
- Screenshot: frame_0000.png
- Game shows: "Mine 4 ore 0/4" objective
- Character (yellow hard hat) standing on surface
- Message: "Stand by the RINGED silver-flecked rock at your feet, point at it and hold LMB"
- Controls shown: A/D move, SPACE jump, LMB mine
- Visible world: trees, terrain, machines (FORGE visible), day/night cycle (showing OPEN SKY +2m)
- Map on right showing world layout

---


## Burst 1 - Attempt to mine
- Command: Point mouse at [650,410], hold LMB for 120 ticks (2 seconds)
- Saw: Objective still "Mine 4 ore 0/4" (unchanged). "LMB mine" control text disappeared from bottom.
- Decided: Try pointing at a different rock. The instruction says "at your feet" so I should look for the rock closest to my character's position.
- Hesitation: Unclear which of the yellow circles is the actual "RINGED silver-flecked rock." There are multiple yellow rings visible on screen.


## Burst 2 - Successfully mined ore
- Command: Point mouse at [545,390], hold LMB for 120 ticks
- Saw: Objective now shows "✓ Mine 4 ore" with green checkmark - COMPLETE! Time changed from +2m to +1m. New UI showing "Ore" with inventory displaying "7" ore units. Forge structure glowing with orange/red color.
- Decided: Explore what to do with the ore. The Forge is visible to the left. Try moving towards it or interacting with machines to see if I can process the ore.
- Hesitation: No new objective text appeared yet. Unclear what the next step is. Should I approach the Forge? Interact with a machine?


## Burst 3 - Move left towards Forge
- Command: Walk left (A key) for 60 ticks (1 second)
- Saw: New objective appeared! "Forge 2 ingots 0/2". Instruction text: "Walk to the RINGED forge, stand beside it and press Q to feed it the ore, then wait: the ingo..." (text cut off, likely says "ingots"). Forge structure visible on left with yellow ring marker. Time still shows +2 m.
- Decided: Continue walking left to reach the forge structure so I can interact with it.
- Hesitation: Text is cut off. Also, my character appears still on the right side of the screen despite walking left - need to move more to reach the forge.


## Burst 4 - Continue walking left
- Command: Walk left (A key) for 120 ticks
- Saw: Character moved to left side of screen, now standing right by forge area. Yellow ring marker visible. Time shows +8 m. Still have 7 ore.
- Decided: Try pressing Q to feed ore to the forge.
- Hesitation: None - the yellow ring seems to be the interaction point.

## Burst 5 - Press Q to feed ore
- Command: Press Q for 30 ticks
- Saw: Ore inventory UI disappeared from bottom of screen. Gear/wheel icon appeared in the forge area, suggesting it's processing. Objective still shows "Forge 2 ingots 0/2" with no progress yet.
- Decided: Wait for the forge to finish processing and produce the ingots.
- Hesitation: The instruction text says "then wait: the ingo..." (cut off). Unclear how long to wait.


## Burst 6 - Wait for forge
- Command: Wait (idle) for 180 ticks (3 seconds)
- Saw: Ore inventory UI reappeared at bottom, still showing 7 ore. Gear icon disappeared. Objective still shows "Forge 2 ingots 0/2" - no progress.
- Decided: The forge might not have been activated. Try pressing Q again.
- Hesitation: Unsure what went wrong. No error message displayed.

## Burst 7 - Press Q again
- Command: Press Q for 30 ticks
- Saw: Same result as before - ore inventory disappeared, gear icon appeared in forge area. Objective still 0/2.
- Decided: Wait much longer (5 seconds) to see if forge needs more time to process.
- Hesitation: Is the forge even receiving input? Do I need to power it first?

## Burst 8 - Wait 5 seconds
- Command: Idle for 300 ticks (5 seconds)
- Saw: Instruction text under the objective disappeared (only "Forge 2 ingots 0/2" remains). Ore inventory shows 7. Gear icon gone. No progress on objective.
- Decided: The forge doesn't seem to be working as expected. Explore to find if there's an ingot output location or if I need to power the forge first.
- Hesitation: The forge mechanic is not working. Maybe I'm at the wrong location, or the forge needs power/activation.


## Burst 9 - Move right to explore
- Command: Walk right (D key) for 120 ticks
- Saw: Camera moved, showing more structures. Yellow ring markers visible. Still in center area. Time still +1 m. No progress on objective.
- Decided: Continue exploring to find ingots or understand forge better.
- Hesitation: Unsure if forge mechanic is working. Need to find either ingot output location or different forging process.

## Burst 10 - Continue right
- Command: Walk right (D key) for 120 ticks
- Saw: Entered new zone - message "ENTERING TOPSOIL" displayed. Location changed from "OPEN SKY" to "TOPSOIL". Still have 7 ore, objective 0/2.
- Decided: Recognize this is a layered world. Continue exploring.
- Hesitation: None yet, but the forging still not working.

## Burst 11 - Move further right
- Command: Walk right (D key) for 90 ticks
- Saw: Still in TOPSOIL zone. Message still displayed. Can see various structures with yellow ring markers.
- Decided: Return to forge area to investigate different interaction method.
- Hesitation: Maybe I'm using the wrong interaction key for machines?

## Burst 12 - Return to forge area (walk left)
- Command: Walk left (A key) for 120 ticks
- Saw: Back in forge area. "ENTERING TOPSOIL" message still showing. Can see FORGE label on structure. Yellow ring markers on multiple structures.
- Decided: Try pressing Tab to see if there's UI/inventory I'm missing.
- Hesitation: The forge process doesn't seem to be working. Need to find what I'm doing wrong.

## Burst 13 - Press Tab
- Command: Press Tab for 30 ticks
- Saw: No visible change. No UI appeared.
- Decided: Try pressing E key to interact with machines, since Q didn't seem to produce results.
- Hesitation: Still uncertain what the correct interaction method is.


## Bursts 14-19: Continued forge attempts
(Various attempts with Tab, E, RMB, Space keys - none worked)

## Burst 20 - Dragging ore to forge (breakthrough!)
- Command: Drag from ore inventory [640,630] to forge [515,385]
- Saw: Ore inventory UI changed! Now shows two slots instead of one - Left: "11" ore, Right: "3" (brown/orange icon). Yellow line visible connecting forge to inventory. This is a major change!
- Decided: The dragging mechanic is the correct interaction! Wait to see if forge completes.
- Hesitation: What does "3" on the right represent? Are they ingots?

## Burst 21 - Wait for forge
- Command: Wait for 240 ticks (4 seconds)
- Saw: Inventory unchanged - still shows "11" ore and "3" of the other item. Objective still shows 0/2. No progress.
- Decided: Try clicking on the right slot to pick up the items.
- Hesitation: The forge shows "3" of something but the objective doesn't recognize it as 2 ingots.

## Burst 22 - Click right slot
- Command: Click on right slot [680,635] with LMB
- Saw: Right slot highlighted with orange ring. Nothing else changed.
- Decided: Try dragging the right slot out of inventory.
- Hesitation: Still unclear what the "3" represents.

## Burst 23 - Drag right slot upward
- Command: Drag right slot [680,635] to [640,400]
- Saw: New yellow-outlined circle appeared on ground above forge area. Inventory still shows "11" and "3". Objective still 0/2.
- Decided: Items can be dragged from inventory to the world. Try dragging to a delivery location.
- Hesitation: Does this register as collected, or do I need to deliver them somewhere?

## Burst 24 - Drag ingots far left
- Command: Drag right slot [680,635] toward left [200,400] (toward starting area)
- Saw: Objective instruction text REAPPEARED (was hidden). Tutorial message: "TOO FAR — the red slashed square means the rock is past your reach. Your reach is about a body length: step closer, then hold LMB." Inventory still "11" and "3", objective still 0/2.
- Decided: There's a reach mechanic. Items need to stay within reach distance. Drag ingots back closer to forge area.
- Hesitation: What's the right location to drop the ingots to register them as forged/collected?


## Burst 25 - Drag ingots back to forge
- Command: Drag right slot [680,635] back to forge area [515,385]
- Saw: Ingot count changed from "3" to "5"! Physical ingot icons now visible on ground near forge (two outlined boxes/circles). Yellow line connecting inventory to forge area visible.
- Decided: The dragging mechanic is creating/transferring items. Closer inspection needed.
- Hesitation: Why did the count increase? Is dragging repeatable?

## Burst 26 - Click on ingot object
- Command: Click on ground object [568,395] with LMB
- Saw: Red slashed square appeared - "TOO FAR" error returned. Ingots are out of reach distance from character position.
- Decided: Character must move closer to ingots to interact with them.
- Hesitation: The reach mechanic is limiting interaction distance.

## Burst 27 - Walk right toward ingots
- Command: Walk right (D key) for 120 ticks
- Saw: Entered new zone "THE CLAYBAND" (22 m depth). Large transition message displayed. Much darker terrain. Character moved to new area.
- Decided: Walked too far, entered wrong zone. Need to navigate back to forge area.
- Hesitation: The world has distinct depth zones with different visual themes.

## Burst 28-30 - Navigation attempts  
- Bursts 28-30 spent walking left and right through CLAYBAND and STONEREACH zones (46m depth). Character got lost navigating deep layers. Found yellow ring marker still visible at distance.

## Burst 31 - More navigation
- Command: Walk left (A key) for 240 ticks
- Saw: Reached 50m STONEREACH (even deeper). "TOO FAR" message still showing. Ingots location still visible as yellow ring at distance.
- Decided: Too deep, need to find way back to surface forge location.
- Hesitation: Navigation in deep areas is complex and inefficient with basic movement.

## Burst 32 - Tutorial: Grapple Mechanic
- Command: Walk left (A key) for 240 ticks continued
- Saw: NEW TUTORIAL: "GRAPPLE — press SHIFT to throw your line at rock above. Hold W to climb it, press SHIFT again to let go and fly." Ore Vein discovered: "16 ore — stand a Drill just above it"
- Decided: Grapple hook is the movement system for vertical traversal! Can use it to climb toward ingots.
- Hesitation: Game has complex traversal mechanics beyond simple walking.

## Bursts 33-35 - Grapple attempts
- Attempted to use grapple mechanic (Shift + W keys). Limited success in navigating. Still stuck at 50m STONEREACH depth with ingots visible but unreachable.
- Game ended at burst 36.

