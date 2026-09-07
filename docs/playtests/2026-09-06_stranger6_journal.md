# Playtest Journal

## Session Start
Initial screenshot shows: Mining game, objective "Mine 4 ore 0/4", character with yellow hard hat, trees, underground caverns, machinery labeled "FORGE" to the left.

---


## Burst 1 (ticks: 30, sim_seconds: 0.52)
**Sent**: Wait and observe
**Saw**: Same initial state - no changes
**Decided**: Look for the ringed ore to mine
**Hesitation**: Wasn't sure which exact rock was "ringed silver-flecked"

## Burst 2 (ticks: 120, sim_seconds: 2.52)
**Sent**: Click and hold LMB at pixel [570,410] for 2 seconds - targeting a circular outline below the character
**Saw**: MAJOR CHANGE - Objective now shows "✓ Mine 4 ore" (green checkmark). Two new UI panels appeared: "Ore Vein - 13 ore — stand a Drill just above it" on right, and "Ore - 11" inventory at bottom. Character is now above ground standing on a rock formation.
**Decided**: The objective is complete! I have 11 ore. Now I need to find/place a Drill by an ore vein. Explore the world to find machinery or understand progression.
**Hesitation**: Confused why mining once gave 11 ore when objective was "Mine 4 ore". Did I mine multiple deposits? Or was the 4 a different target?


## Burst 3 (ticks: 60, sim_seconds: 3.52)
**Sent**: Walk left to FORGE
**Saw**: New objective "Forge 2 ingots 0/2" appeared with instructions "Walk to the RINGED forge, stand beside it and press Q to feed it the ore"
**Decided**: Navigate to the forge and interact with it
**Hesitation**: None

## Burst 4 (ticks: 60, sim_seconds: 4.52)
**Sent**: Walk right back to FORGE structure
**Saw**: Character moved toward forge, objective still shows 0/2
**Decided**: Click on forge to interact
**Hesitation**: Not sure if I was close enough

## Burst 5 (ticks: 30, sim_seconds: 5.02)
**Sent**: Press Q to interact with forge
**Saw**: Forge started glowing, "-11 ore" floated up, indicating ore was consumed. Objective now shows "Forge 2 ingots 0/2" (unchanged counter but forge is working)
**Decided**: Wait for forge to produce ingots
**Hesitation**: Why did -11 ore appear if the ratio is 2 ore -> 1 ingot?

## Burst 6 (ticks: 120, sim_seconds: 7.02)
**Sent**: Wait for forge to produce ingots
**Saw**: Objective changed to "Forge 2 ingots 1/2", "+1 ingot" text floated up, Forge panel appeared showing "2 -> 1" conversion rate, Ingot inventory shows 1
**Decided**: Wait for second ingot
**Hesitation**: None

## Burst 7 (ticks: 120, sim_seconds: 9.02)
**Sent**: Wait for second ingot
**Saw**: Objective changed to "✓ Forge 2 ingots" with GREEN CHECKMARK, "+1 ingot" floated up, Ingot inventory now shows 2
**Decided**: Objective complete! Now explore to find next task
**Hesitation**: No new objective appeared yet

## Burst 8 (ticks: 60, sim_seconds: 10.02)
**Sent**: Wait and observe
**Saw**: Objective still shows "✓ Forge 2 ingots", no new objectives yet
**Decided**: Explore the world to the right
**Hesitation**: No obvious next step shown

## Burst 9 (ticks: 60, sim_seconds: 11.02)
**Sent**: Walk right (D key)
**Saw**: NEW OBJECTIVE "Get wood 0/1" appeared! Instructions: "Hold LMB on a tree's brown TRUNK, not its leaves — sixteen cuts make a block". View shows "ENTERING OPEN SKY" transition message, can see trees in background
**Decided**: Go to the tree and cut its trunk to get wood
**Hesitation**: Why does the inventory show "Wood: 1" if objective is 0/1?

## Burst 10 (ticks: 60, sim_seconds: 12.02)
**Sent**: Continue walking right toward tree
**Saw**: Location changed from "OPEN SKY" to "TOPSOIL" (transition message), "Ingot 2" still visible, Wood still shows "1"
**Decided**: I've gone too far right. Need to go back left to the tree
**Hesitation**: Confused about wood inventory vs objective counter

## Burst 11-17 (ticks: multiple, sim_seconds: 13-27)
**Sent**: Multiple attempts to click and hold on tree trunk with LMB (bursts 11, 12, 14, 16, 17)
**Saw**: Yellow/orange box outline appeared on tree when clicking (indicating interaction), but objective counter remains stuck at "0/1". HARD LANDING message repeatedly appeared
**Decided**: Continue trying different positions and timings on the tree
**Hesitation**: The tree interaction doesn't seem to be working as expected. The objective isn't progressing despite clicking on the tree trunk

## Burst 18 (ticks: 30, sim_seconds: 27.52)
**Sent**: Wait and observe
**Saw**: Yellow box still visible on tree. Objective still 0/1
**Decided**: Try a different approach - maybe explore other areas or reassess the situation
**Hesitation**: Stuck on wood objective. May need to try a different tree or find a different mechanic


## Burst 19-32 (Summary of navigation attempts)
**Pattern**: Multiple long bursts attempting to navigate between deep caverns and surface areas, trying different directions
**Saw**: Transitioned through multiple biomes: TOPSOIL (2-7m), CLAYBAND (22m), STONEREACH (46-50m). Discovered new mechanics tutorials:
  - Burst 23: "TOO FAR — reach mechanic" (must be within one body length to interact)
  - Burst 27: "GRAPPLE — throw line with SHIFT, climb with W, release with SHIFT"
  - Burst 32: "PUMP IT — hold W bottom of arc, S at top"
**Decided**: Repeatedly attempted to navigate back toward surface to retry wood gathering
**Hesitation**: Each navigation attempt was inefficient and led to deeper areas rather than surface. The map layout was confusing.

## Session Summary
- **Total bursts spent**: 32 out of 60 budget (53% of budget used)
- **Objectives completed**: 2 out of 3
  1. ✓ Mine 4 ore (completed burst 2, sim_seconds: 2.52)
  2. ✓ Forge 2 ingots (completed burst 7, sim_seconds: 9.02)
  3. ✗ Get wood 0/1 (never progressed despite ~12 dedicated attempts across bursts 11-32)
- **Game mechanics discovered**: Mining, ore transport, smelting, reaching/interaction range, grappling, pumping

