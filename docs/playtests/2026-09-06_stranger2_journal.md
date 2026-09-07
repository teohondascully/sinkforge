# Playtest Journal - Stranger 2

## Session Start
Starting at frame_0000.png. Game shows mining tutorial starting.


## Burst 1-5: Mining Tutorial
**Burst 1** (ticks 60, 1.01s sim): Pointed at ground ore, held LMB for 1 second.
- SAW: Character mining animation, ore being targeted with red outline
- DECIDED: Continue mining longer to extract ore
- HESITATION: Not sure if mining was working; confused about ore vs clay difference

**Burst 2** (ticks 120, 3.01s sim): Continued mining same location for 2 seconds.
- SAW: Inventory popup appeared showing "Clay 1" - I had mined clay, not ore
- DECIDED: Wrong target; need to find different ore deposit marked "RINGED silver-flecked"
- HESITATION: What's the difference between ore and clay? Why did one count as ore in inventory but not for quest?

**Burst 3** (ticks 30, 3.51s sim): Released mouse and observed.
- SAW: Clay inventory still showing
- DECIDED: Try mining a different golden-ringed deposit

**Burst 4** (ticks 90, 5.01s sim): Mined ore deposit to the right at mouse [690,430]
- SAW: Red outline showing mining target, no progress on ore counter
- DECIDED: Still wrong ore type; try the larger deposit

**Burst 5** (ticks 90, 6.51s sim): Mined the larger ore deposit to the left at [545,380]
- SAW: GREEN CHECKMARK! "✓ Mine 4 ore" quest completed! Inventory now shows Clay 1, and slot 2 shows "6" (ore)
- DECIDED: Quest complete; look for next objective
- HESITATION: The quest said 0/4 but inventory shows 6 ore; why the count mismatch?


## Burst 6-37: Forge and Wood Quests

**Burst 6** (ticks 30, 7.01s): New quest appeared "Forge 2 ingots 0/2"
- SAW: Quest box with instruction to use forge; interface showing forge takes 2 ore -> 1 ingot
- DECIDED: Walk to forge to begin
- HESITATION: None, instruction was clear

**Burst 7-8** (ticks 60-60, 9.01s-9.35s): Walked right toward starting position
- SAW: Inventory changed from ore+clay to just ore
- DECIDED: Position at forge and press Q to feed ore

**Burst 9-13** (ticks 20-120, 9.35s-13.68s): Fed ore and produced ingots
- SAW: First forge cycle produced 1 ingot; quest showed 1/2
- DECIDED: Feed more ore and continue
- HESITATION: Inventory showed clay, not ore, confusing

**Burst 14** (ticks 30-90, 15.68s): Quest completed "✓ Forge 2 ingots 2/2"
- SAW: Green checkmark; inventory showed 2 ingots, 1 clay
- DECIDED: Wait for next quest

**Burst 15** (ticks 60, 16.68s): New quest "Get wood 0/1"
- SAW: Instruction "Hold LMB on a tree's brown TRUNK, not its leaves — sixteen cuts make a block"
- DECIDED: Walk to trees and mine trunk

**Bursts 16-37** (ticks 80-300, 19.5s-74.18s): STUCK on wood quest
- SAW: Successfully mined tree leaves (trees visibly lost foliage), got red outline targeting on trunks, found feedback "TOO FAR" when too distant
- DECIDED: Tried multiple approaches - different trees, different positions, longer mining durations
- RESULT: Never reached 1/1 on wood quest
- HESITATION: What mechanic completes wood mining? Need specific tool? Wrong target? Wrong mechanic?

## Summary of Completions
- Mine 4 ore: COMPLETED at 6.51s sim
- Forge 2 ingots: COMPLETED at 15.68s sim
- Get wood: FAILED after 15+ attempts

## Key Learnings
- Mining ore: Find ore deposits, hold LMB
- Forging: Walk to forge, press Q to feed ore, wait for production (2 ore -> 1 ingot, 0.7s cycle)
- Mining wood: Attempted extensively but never succeeded; visible progress on trees but no quest completion
- Character reach is about "one body length"
- Game shows feedback messages for invalid interactions

