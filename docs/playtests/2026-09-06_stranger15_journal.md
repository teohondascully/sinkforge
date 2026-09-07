# Stranger-15 Playtest Journal

## Burst 1

**Command**: Point mouse at the ringed rock near character and hold LMB to mine

**Saw**: The screen shows me at +2m depth in "OPEN SKY". There's a quest box saying "Mine 4 ore 0/4 - Stand by the RINGED silver-flecked rock at your feet, point at it and hold LMB". I see a character with a yellow hard hat in the center. Below on the ground I can see what appears to be machines with rings/circles. Controls shown: A/D to move, SPACE to jump, LMB to mine.

**Decided**: I need to identify the ringed silver-flecked rock. Looking at the visible elements, there appears to be one near my feet. I'll click/hold LMB on it to mine.

**Hesitation**: Not sure exactly which object is the "ringed silver-flecked rock" - there are several mechanical-looking items with rings visible on screen.


## Burst 2

**Command**: Held LMB at position [530,440] for 2 seconds, pointing at what appeared to be the ringed object

**Saw**: The quest updated! Now shows a checkmark "✓ Mine 4 ore" - quest complete. A new UI box appeared saying "Ore Vein - 13 ore — stand a Drill just above it". Below my character I can see an "Ore" item showing "11" (units of ore collected). Gold sparkles float above the character.

**Decided**: Mining worked! The game wants me to place a Drill, but my goal is to descend 20m and return. I should start moving downward to explore the underground. I'll head down to find passage deeper.

**Hesitation**: Not sure if the Drill placement is essential for my descent goal. The quest seems to want me to place drilling equipment, but that might be optional for descending.


## Burst 3

**Command**: Moved right using D key for 1 second

**Saw**: Moved to the right side of the surface area. Still at +2m "OPEN SKY". A new quest appeared: "Forge 2 ingots 0/2 - Walk to the RINGED forge, stand beside it and press Q: the whole stack of ore goes in, then wait — the ingots come to you". I can see various forge/factory structures and the ore (11 units) remains.

**Decided**: I'm still at surface level. I need to find a way down to the underground. I should continue exploring to find passages or shafts that lead deeper. Let me keep moving right to explore the full terrain.

**Hesitation**: Should I complete the forge quest first, or focus on descending? The game is giving me quests but my main goal is to descend and return.


## Burst 4

**Command**: Moved right using D key for 1 second

**Saw**: Depth changed to "2 m TOPSOIL" and a large message appeared saying "ENTERING TOPSOIL". This marks entry into an underground layer. The terrain shows more cave-like structures.

**Decided**: I'm starting to go underground. I need to continue down much further to reach -18m (my target of 20m descent). Let me keep moving right to explore more of this layer and find passages going deeper.

**Hesitation**: Not sure if this TOPSOIL zone is just one layer or if there are multiple layers below. I'll keep exploring to find deeper passages.


## Burst 12

**Command**: Walked right for 1 second

**Saw**: Depth increased to "3 m TOPSOIL"! The terrain is sloping downward as I move right.

**Decided**: Progress! The depth is increasing as I move right. This means I've found a downward slope. I should continue moving right to descend deeper toward my -18m target.

**Hesitation**: None yet - finally finding a way to descend!


---

## FINAL REPORT

### 1. Timeline

- **Burst 1 (2.01 sim_seconds)**: Mined ore successfully. Quest "Mine 4 ore" completed with green checkmark. Collected 11 ore units. Game displayed "Ore Vein - 13 ore — stand a Drill just above it" instruction.
- **Burst 2 (3.08 sim_seconds)**: Mined again, gold sparkles appeared above character, ore count shown as 11.
- **Burst 14 (19.23 sim_seconds)**: Hard landing tutorial message appeared explaining fall mechanic and grappling line.
- **Burst 28 (46.36 sim_seconds)**: Received "Dropped" tutorial explaining machine interaction (must stand beside, not on top).
- **Burst 35 (59.73 sim_seconds)**: Final attempt with maximum right movement before stopping.

**Milestones NOT reached:**
- First ingot production: NOT REACHED (Forge quest never completed despite multiple attempts)
- First wood collected: NOT REACHED
- Descent to 20 meters: NOT REACHED (maximum depth achieved was only 3m TOPSOIL, only 1m below starting +2m)
- Descent with return: NOT REACHED

### 2. Hesitations

1. Uncertainty about coordinate system - positive values suggest "up" but depth indicator used positive numbers (2m, 3m) for underground areas
2. Unclear exact positioning for machine interactions - kept trying Forge from various distances without success
3. Unconfirmed whether starting area had access to deep passages or if progress required completing earlier quests
4. Uncertainty about whether dropped ore was consumed or stored somewhere

### 3. Retries

- **Forge interaction attempts (multiple bursts)**: Stood near Forge, positioned at various distances, pressed Q multiple times - quest never progressed from 0/2. Game showed no error message, just no response.
- **Tab key**: Pressed expecting inventory - nothing happened
- **E key**: Pressed expecting environment interaction - nothing visible occurred
- **Shift key**: Pressed expecting sprint - no visible change to movement speed
- **Extended right movement (Burst 35)**: Held D for maximum 300 ticks attempting to reach far terrain - cycled back to surface area, no access to visible deep caverns

All retries showed no error messages, just quiet failures with no game feedback about why they didn't work.

### 4. What the game told you well

**Good communication:**
- Mining mechanic was intuitive: point cursor and hold LMB
- Depth indicator with zone labels (OPEN SKY vs TOPSOIL) clearly marked progression
- Tutorial messages appeared at contextually appropriate moments explaining mechanics
- Visual layout made ore and structures obviously interactive targets
- Quest objective text was clear and specific

**Failed communication:**
- No indication of how to access deep caverns that are clearly visible below the surface
- No failure message for Forge interaction - silent failure is worse than explanation
- No tutorial or hint about machine positioning requirements (the "body length beside" rule only appeared after the issue)
- Depth coordinate system confusing (positive numbers for underground, no explanation of depth goal format)
- The grappling line tutorial appeared but never showed how to obtain or use such equipment

### 5. Stop reason

Inability to progress toward goal. After 34 bursts exploring:
- Could only reach maximum depth of 3m TOPSOIL (1m descent from +2m starting depth)
- Terrain cycled between +2m and 1m repeatedly regardless of direction
- Deep caverns visible on screen had no apparent access point
- Critical quest (Forge 2 ingots) would not complete, blocking potential progression
- With 26 bursts remaining of 60 total budget, no new discovery strategy remained untested

### 6. Verdict

**Would I keep playing?** No. 

**Single biggest obstacle:** The game presents a clear goal (descend 20 meters and return to surface) but provides no functional access to terrain deep enough to accomplish this. The starting area appears to be a limited tutorial zone with surface and shallow topsoil depth only. There is either a hidden entrance/mechanism to deeper areas that was not communicated, or the starting location is intentionally restricted and progression requires external input (completed quests providing access keys, specific NPC interactions, etc.). Without discovering this access mechanism after 34 attempts, continuation feels like repetitive failure rather than exploration.

