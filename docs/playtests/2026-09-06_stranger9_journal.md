# Playtest Journal - stranger-9

## Burst 1: Walk right
Command: `{"ticks":60,"keys":["D"]}`
Screenshot: frame_0001.png (sim_seconds: 1.02)
Saw: Still at +2m, moved right, can see more underground terrain with cavities
Decided: Continue exploring right to find descent path
Hesitation: None

## Burst 2: Continue right
Command: `{"ticks":60,"keys":["D"]}`
Screenshot: frame_0002.png (sim_seconds: 2.02)
Saw: Entered "OPEN SKY" at +1m (up slightly), see same landscape
Decided: Continue exploring right to find cave or descent
Hesitation: Why did depth increase when I walked right?

## Burst 3: Continue right
Command: `{"ticks":60,"keys":["D"]}`
Screenshot: frame_0003.png (sim_seconds: 3.02)
Saw: "ENTERING TOPSOIL" at 1m, still searching for descent path
Decided: Different zones exist - topsoil layer found
Hesitation: None

## Burst 4: Continue right
Command: `{"ticks":60,"keys":["D"]}`
Screenshot: frame_0004.png (sim_seconds: 4.02)
Saw: Still 1m TOPSOIL, far right of map, can see more cavities
Decided: Go back left to explore forge area for cave
Hesitation: None

## Burst 5: Walk left (long)
Command: `{"ticks":120,"keys":["A"]}`
Screenshot: frame_0005.png (sim_seconds: 6.02)
Saw: Back to forge area at 1m TOPSOIL
Decided: Try jumping to descend
Hesitation: None

## Burst 6: Just wait
Command: `{"ticks":30}`
Screenshot: frame_0006.png (sim_seconds: 6.52)
Saw: Still 1m TOPSOIL, screen shifted slightly
Decided: Try jumping with Space to descend
Hesitation: None

## Burst 7: Jump
Command: `{"ticks":60,"keys":["Space"]}`
Screenshot: frame_0007.png (sim_seconds: 7.52)
Saw: Still 1m TOPSOIL, jump didn't descend
Decided: Walk left to explore more
Hesitation: Jumping alone doesn't descend?

## Burst 8: Walk left
Command: `{"ticks":60,"keys":["A"]}`
Screenshot: frame_0008.png (sim_seconds: 8.52)
Saw: Still 1m TOPSOIL, same position
Decided: Continue left to explore
Hesitation: Movement seems minimal

## Burst 9: Walk left (longer)
Command: `{"ticks":90,"keys":["A"]}`
Screenshot: frame_0009.png (sim_seconds: 10.02)
Saw: Game message: "HARD LANDING — a long drop costs your footing. A line fired on the way DOWN takes the fall instead of your legs."
Decided: Need to find grappling tool and high point to descend using rope
Hesitation: What key activates the grappling hook?

## Burst 10: Jump with Q
Command: `{"ticks":30,"keys":["Space","Q"]}`
Screenshot: frame_0010.png (sim_seconds: 10.52)
Saw: Still 1m TOPSOIL, quest box closed
Decided: Explore right to find high cliff or descent point
Hesitation: Did Q do anything?

## Burst 11: Walk right (long)
Command: `{"ticks":120,"keys":["D"]}`
Screenshot: frame_0011.png (sim_seconds: 12.52)
Saw: **DESCENDED TO 22m "THE CLAYBAND"** - major descent! Much darker terrain, water visible, cave-like areas
Decided: Successfully descended 21m past starting point. Now need to return to surface
Hesitation: How did walking right cause such a large descent?


## Burst 12: Walk right (long)
Command: `{"ticks":90,"keys":["D"]}`
Screenshot: frame_0012.png (sim_seconds: 14.02)
Saw: Still 22m CLAYBAND, moved right on screen, no depth change
Decided: Continue exploring
Hesitation: None

## Burst 13: Walk left (long)
Command: `{"ticks":120,"keys":["A"]}`
Screenshot: frame_0013.png (sim_seconds: 16.02)
Saw: Descended to 46m STONEREACH - entered a new layer!
Decided: I went the wrong direction (down instead of up)
Hesitation: Why does left go deeper instead of up?

## Burst 14: Walk right (long)
Command: `{"ticks":120,"keys":["D"]}`
Screenshot: frame_0014.png (sim_seconds: 18.02)
Saw: Still 46m STONEREACH
Decided: That walk didn't help
Hesitation: None

## Burst 15: Walk left (long)
Command: `{"ticks":120,"keys":["A"]}`
Screenshot: frame_0015.png (sim_seconds: 20.02)
Saw: Descended further to 50m STONEREACH (HARD LANDING message visible)
Decided: I'm going the wrong way; need to find upward path
Hesitation: None

## Burst 16: Walk right (long)
Command: `{"ticks":120,"keys":["D"]}`
Screenshot: frame_0016.png (sim_seconds: 22.02)
Saw: Descended to 51m STONEREACH
Decided: Right goes deeper, need a different strategy
Hesitation: None

## Burst 17: Try pressing E
Command: `{"ticks":60,"keys":["E"]}`
Screenshot: frame_0017.png (sim_seconds: 23.02)
Saw: E key triggered GRAPPLE tutorial: "press SHIFT to throw your line at rock above. Hold W to climb it, press SHIFT again to let go and fly."
Decided: This is the climbing mechanic I need!
Hesitation: Great discovery, but still at 51m

## Burst 18: Walk right (very long)
Command: `{"ticks":150,"keys":["D"]}`
Screenshot: frame_0018.png (sim_seconds: 25.52)
Saw: Still 51m STONEREACH, far right on screen
Decided: Try grappling to climb
Hesitation: None

## Burst 19: Jump + Q (to test grapple)
Command: `{"ticks":60,"keys":["Space","Q"]}`
Screenshot: frame_0019.png (sim_seconds: 26.52)
Saw: Grapple tutorial message displayed (duplicate)
Decided: Need to try SHIFT key, not Q, for grappling
Hesitation: None

## Burst 20: Press SHIFT (throw grapple)
Command: `{"ticks":60,"keys":["Shift"]}`
Screenshot: frame_0020.png (sim_seconds: 27.52)
Saw: Yellow grappling line launched upward from character!
Decided: Hold W to climb this line
Hesitation: None

## Burst 21: Climb with W
Command: `{"ticks":120,"keys":["W"]}`
Screenshot: frame_0021.png (sim_seconds: 29.52)
Saw: Still 51m, line still visible
Decided: W didn't climb, release and try again differently
Hesitation: Why didn't W work? Maybe need different angle?

## Burst 22: Hold W longer
Command: `{"ticks":150,"keys":["W"]}`
Screenshot: frame_0022.png (sim_seconds: 32.02)
Saw: Still 51m, grapple active
Decided: Release and try different approach
Hesitation: Grapple mechanic not working for ascent here

## Burst 23: Release grapple with SHIFT
Command: `{"ticks":30,"keys":["Shift"]}`
Screenshot: frame_0023.png (sim_seconds: 32.52)
Saw: Still 51m, line still visible
Decided: Explore left for natural ascending path instead
Hesitation: None

## Burst 24: Walk left (very long)
Command: `{"ticks":120,"keys":["A"]}`
Screenshot: frame_0024.png (sim_seconds: 34.52)
Saw: Ascended to 50m STONEREACH! Proof that left = up!
Decided: Continue walking left to reach surface
Hesitation: Only gained 1m in 120 ticks - too slow!

## Burst 25: Walk left (very long)
Command: `{"ticks":120,"keys":["A"]}`
Screenshot: frame_0025.png (sim_seconds: 36.52)
Saw: Still 50m STONEREACH, no further ascent
Decided: Walking left is unreliable; try combining with jumping
Hesitation: Progress rate is inconsistent

## Burst 26: Walk left + Jump
Command: `{"ticks":180,"keys":["A","Space"]}`
Screenshot: frame_0026.png (sim_seconds: 39.02)
Saw: Descended to 51m STONEREACH
Decided: That direction was wrong, go back left
Hesitation: Combination moves don't seem to help

## Burst 27: Walk left (max 300 ticks)
Command: `{"ticks":300,"keys":["A"]}`
Screenshot: frame_0027.png (sim_seconds: 42.02)
Saw: Ascended to 50m STONEREACH
Decided: 300 ticks = ~1m ascent; need ~50 more ticks of this rate
Hesitation: None

## Burst 28: Walk left + Jump (trying to climb faster)
Command: `{"ticks":180,"keys":["A","Space"]}`
Screenshot: frame_0028.png (sim_seconds: 45.02)
Saw: Still 50m STONEREACH
Decided: This isn't working; stick with pure left walks
Hesitation: None

## Burst 29: Try composed move (error)
Command: `{"moves":[{"ticks":300,"keys":["A"]},{"ticks":300,"keys":["A"]}]}`
Screenshot: (error - moves max 300 ticks total)
Saw: Error message - moves limited to 300 ticks maximum
Decided: Use single 300-tick bursts instead
Hesitation: None

## Burst 30: Walk left max
Command: `{"ticks":300,"keys":["A"]}`
Screenshot: frame_0030.png (sim_seconds: 50.02)
Saw: Still 50m STONEREACH
Decided: Continue repeatedly; calculate if feasible with burst budget
Hesitation: At burst 30, running out of ticks

## Burst 31: Press SHIFT (throw grapple again)
Command: `{"ticks":60,"keys":["Shift"]}`
Screenshot: frame_0031.png (sim_seconds: 51.02)
Saw: Grapple line thrown upward
Decided: Try climbing with W again
Hesitation: Previous attempts failed; probably won't work

## Burst 32: Hold W (climb attempt)
Command: `{"ticks":100,"keys":["W"]}`
Screenshot: frame_0032.png (sim_seconds: 52.68)
Saw: Still 50m STONEREACH
Decided: Grappling not effective here; abandon this approach
Hesitation: None

## Burst 33: Walk right (long) to find different path
Command: `{"ticks":300,"keys":["D"]}`
Screenshot: frame_0033.png (sim_seconds: 57.68)
Saw: Descended to 51m STONEREACH
Decided: Need to go back left to ascend
Hesitation: None

## Burst 34: Walk left (max)
Command: `{"ticks":300,"keys":["A"]}`
Screenshot: frame_0034.png (sim_seconds: 62.68)
Saw: Ascended to 50m STONEREACH
Decided: Continue with 300-tick left walks to reach surface
Hesitation: None

## Burst 35: Walk left (max)
Command: `{"ticks":300,"keys":["A"]}`
Screenshot: frame_0035.png (sim_seconds: 67.68)
Saw: Still 50m STONEREACH - NO PROGRESS
Decided: Continue anyway
Hesitation: Progress is sporadic/unreliable

## Burst 36: Walk left (max)
Command: `{"ticks":300,"keys":["A"]}`
Screenshot: frame_0036.png (sim_seconds: 72.68)
Saw: Still 50m STONEREACH - NO PROGRESS
Decided: Try Tab key to see if other mechanics exist
Hesitation: Stuck pattern emerging

## Burst 37: Press Tab (explore UI)
Command: `{"ticks":30,"keys":["Tab"]}`
Screenshot: frame_0037.png (sim_seconds: 73.18)
Saw: No visible change from Tab key
Decided: Go right to descend back to 22m, explore different path
Hesitation: I've hit a dead end at 50m

## Burst 38: Walk right (long) - descent back to explore
Command: `{"ticks":300,"keys":["D"]}`
Screenshot: frame_0038.png (sim_seconds: 78.18)
Saw: Descended to 51m STONEREACH
Decided: Quit - I cannot make progress within burst budget
Hesitation: None

## Burst 39: Quit game
Command: `{"quit":true}`
Screenshot: (quit)
Saw: Game ended
Decided: Stop here; write final report
Hesitation: Achieved descent goal but could not return

