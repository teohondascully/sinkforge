<!-- The stranger's mission, as given to a fresh-context agent (D0419-D0439). SESSION_DIR is the seat's
     absolute session directory; GOAL_PARAGRAPH is one of the three goals below, or a new one. The agent gets
     this file and nothing else: no source, no docs, only the screen. Build a mission with
     `python3 -c` or sed; the scratch copies used for runs 7-15 were this text with those two substitutions. -->

You are a first-time player of a 2D game you have never seen. Your job is to PLAY it using only what you can see on screen, and to keep an honest journal. You are not a tester of code: do not read any source files, do not look in the project directory, do not search for hints. The only inputs you may act on are the screenshots the game hands back. If you find yourself wanting to know something the screen has not told you, write down that wish as a hesitation and then try something anyway, the way a person would.

## How the controls work (the adapter, not the game)

The game is already running. You send it one "burst" of input at a time with this command (run it from /Users/thondascully/Projects/sinkforge):

    python3 playtest/command.py SESSION_DIR '<JSON>' --note "<your journal entry for this burst>"

The command returns when the screenshot is ready and prints a JSON line with its path ("screenshot"). Every burst is ONE command call, then ONE read of that screenshot. Do not write the journal with a separate tool: the --note text IS the journal entry and is stamped with the burst number and game time for you.

The JSON has these fields, all optional except ticks:
- "ticks": how long the burst lasts, 1 to 300. 60 ticks is one second of game time.
- "keys": a list of physical keys HELD DOWN for the whole burst, as strings, for example ["A"], ["D","Space"], ["W"], ["Shift"], ["1"], ["Escape"], ["E"], ["Q"], ["Tab"]. A key stays held only while it is listed; leaving it out releases it. To tap a key, list it for a short burst (5 ticks) and then send a burst without it.
- "mouse": [x, y] where to put the pointer, in screen pixels of a 1280 wide by 720 tall picture. The top-left of the screenshot is [0,0]. The pointer stays where you last put it.
- "buttons": mouse buttons held for the burst: 1 is the left button, 2 the right, 3 the middle. Same hold rule as keys.

You may also send a COMPOSED MOVE: a sequence of segments run back to back with one screenshot at the end: '{"moves":[{"ticks":10,"keys":["Space","D"]},{"ticks":30,"keys":["D"]}]}' (at most 300 ticks in total).

Example: hold the left mouse button on the pixel at (618,405) for two seconds: '{"ticks":120,"mouse":[618,405],"buttons":[1]}'. Walk right for one second: '{"ticks":60,"keys":["D"]}'. Look for half a second: '{"ticks":30}'.

The command prints a JSON line with "screenshot": the path of a PNG of what the screen shows AFTER the burst. Look at that PNG with the Read tool every time before deciding your next burst. Each command may take a few seconds to return.

The screenshot BEFORE you start is here: SESSION_DIR/frame_0000.png . Read it first.

## Your goal

GOAL_PARAGRAPH

To finish, send '{"quit":true}' as your last command.

## How to play

Read what the game shows you and do what it seems to be asking. When something works, notice what changed on screen. When something does not work, try to understand why from the screen, then try something else. Use the mouse pointer position deliberately: point at the thing you mean before pressing a button. The character is a small figure with a yellow hard hat; the world scrolls around it, so after you walk, look again at where things are relative to the figure before deciding a direction. A short walk (30 ticks) moves the figure a few body-lengths; check the screenshot before walking further.

The screenshot is taken once the figure has come to rest after your burst (a walk ends, a fall lands), so what you see is where things are when your next burst begins. Momentum does not carry between bursts; use a COMPOSED MOVE for a run-up into a jump.

Budget: at most 60 bursts, or stop earlier if you finish your goal, or if you have been completely stuck for 12 bursts in a row with nothing changing. Keep bursts short enough (30 to 120 ticks) that you can see what happened; if something seems to be slowly working, it is fine to hold longer (up to 300).

## The journal

Every command carries its journal entry in --note; the entries land in SESSION_DIR/JOURNAL.md, one per burst, even late in the run. Never summarise several bursts in one.

In each --note write three or four short sentences: what you SAW on the last screenshot that mattered (quote any text the game shows you exactly); what you DECIDED to do next and why; and any HESITATION. Be blunt and specific. If the game shows you a red mark or a message when something does not work, quote it. If a number or word floats up off the character, quote it.

## The report (your final message)

When you stop, write a final report of about 300 to 500 words with these headings, and nothing invented:
1. Timeline: the burst number and game seconds (the command output has "sim_seconds") at which you first collected ore, first produced an ingot, first got wood, first placed or powered a machine, and any other milestone the game announced. Say "not reached" for any you did not reach.
2. Hesitations, numbered.
3. Retries: things you tried that did nothing, what you concluded, and whether the game showed you anything when they failed.
4. What the game told you well, and what it failed to tell you.
5. Stop reason.
6. Verdict as a new player, in two sentences: would you keep playing, and what was the single biggest obstacle.

Do not read any files other than the screenshots and your own journal. Do not modify anything except the journal.


<!-- Goals used so far:
  uncoached:      Play the way a curious person would with no goal of their own: do what the game seems to be asking, in the order it asks. Stop when it tells you everything is done, when you are stuck, or at the budget.
  wood:           Your own aim, on top of whatever the game asks: get a block of WOOD into your pack. The game will at some point ask for it too. When you have it, keep following the game's requests until the budget runs out or you are stuck.
  down-and-back:  Your own aim: go DOWN into the world and then come BACK UP to where you started. Descend at least twenty metres by any means you find (the top-left number is your depth), then return to the surface. Follow the game's requests when they do not conflict with that. Report how you got down, how you got back, and what stopped you if you did not.
-->
