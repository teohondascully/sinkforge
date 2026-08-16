# THE BAZAAR — one counter, three tabs

> **Status: SHIPPED** as #S33 (2026-08-16), with one deviation from the text below. Chosen with the user
> over two alternatives (walk-between-physical-stations; a hybrid of both).
>
> **Deviation:** rows are **22px, not 24** — 24 gave nine rows per column, and the twenty rows §2 promises
> are the reason the scrolling viewport could be deleted, so the row height moved rather than the promise.
> The Rack is no longer the stub §6 describes: #S32 landed the tool-shapes design first, so it opened
> stocked with the four bits.
>
> **Its LOOK was reworked as #S34** — this document specs the counter's *shape* (one panel, three tabs, no
> scrolling, same everywhere), and that shape is what shipped and what stays. The surface on top of it is in
> `docs/FEEL_GAP.md` STRIKE 34, along with two changes that revise §3 and §7 below:
>
> * **WORKS lists only what you can BUILD.** §3 said the Rack shows locked rows naming the tech that
>   unlocks them. In play that was thirteen greyed rows out of sixteen — decision paralysis in the place you
>   go to get things. The locked half moved to BENCH, greyed, under the rung that unlocks it, and WORKS
>   carries one line saying how many wait there. §7's "every row that is locked names the tech that unlocks
>   it" is therefore satisfied on the BENCH rather than on the counter.
> * **PACK gained a verb** (ENTER holds the thing under the cursor), and the panel gained a DETAIL PLATE
>   along the bottom, which is where a row's description, price and verb now live.

## 1. What is actually wrong today

Not a vibe — six specific things, five of which are visible in the source:

1. **One 360px column does three unrelated jobs.** `HUD._pack_geometry()` stacks the inventory grid, the
   craft list and the research bench into a panel 360 wide on a **640×360** canvas. It uses barely half the
   screen and then runs out of room vertically, so the craft list lives in a bounded scrolling viewport with
   `_craft_scroll_max` clamping. The source records the playtest that forced it: *"automation fell off the
   bottom, unreachable."* That is the cramming talking, and the fix at the time was a scrollbar.
2. **You read the tech ladder in one screen and act on it in another.** `T` draws the graph
   (`_draw_tech_overlay`); the research verb is `R`, inside the pack screen, only when `can_craft`. Look
   here, act there.
3. **`R` is two unrelated verbs.** Research, and "configure the splitter/hopper you are aiming at",
   disambiguated by context. Two jobs on one key is a thing you have to be taught.
4. **The pack screen changes SHAPE depending on where you stand.** Away from a Bazaar `can_craft` is false,
   the recipe rows and the whole research section vanish, and you get a single hint line. So you cannot plan
   a build while you are down a shaft — the one place you actually want to.
5. **The staging is wasted.** `scenes/bazaars.gd` runs a block-by-block cosmetic transformation — awning,
   banners, lantern, a shopkeeper NPC who walks in — and then interacting with the thing dims the world to
   82% black and shows a floating box that could belong to any game.
6. **There is no shop.** Everything is crafted from your own materials. There is nowhere for "buy a second
   pick early" to live, which is the surface the tool-shapes idea needs.

## 2. The shape

**One panel. Three tabs. Same panel everywhere.**

```
 +--------------------------------------------------------------+
 |  THE BAZAAR                 ( PACK )  [ WORKS ]  ( BENCH )   |
 +----------------------------+---------------------------------+
 |  MACHINES                  |  THE RACK                       |
 |   forge        2 ingot  ok |   stone pick      6 ingot   ok  |
 |   drill        4 ingot  ok |   broadhead      14 ingot   --  |
 |   hopper       3 ingot  ok |   wedge          20 ingot   --  |
 |   generator    8 ingot key |                                 |
 |   lift        10 ingot key |                                 |
 +----------------------------+---------------------------------+
 |  8 ingot - 24 ore - 12 coal              E close   1/2/3 tab |
 +--------------------------------------------------------------+
```

- Width **600** of the 640 canvas (20px margin each side), height **300** (30px top and bottom). Two
  content columns of 288 with a 12px gutter, or three of 188 where a tab wants them.
- **No scrolling viewport.** Two columns at 24px rows gives 20 rows of content in the same space that
  currently fits 8 stacked ones. If a list ever outgrows that, the answer is a third column, not a scrollbar.
- The world behind it is **dimmed, not blacked** — enough to read the stall, the banners and the shopkeeper
  standing next to you. You are at a counter, not in a menu.
- Tabs switch on `1`/`2`/`3` and on the mouse wheel. No new keys to learn beyond what the hotbar already uses.

## 3. The tabs

**PACK** — the full carried inventory, exactly what it draws today, given the whole width. Always live,
everywhere. This is what `E` opens in a shaft.

**WORKS** — two columns. Left: **machines**, the current craft list, unscrolled. Right: **the Rack**, the
shop. A row shows name, price, and one of three states: affordable, unaffordable, or locked-by-tech (with
the tech that unlocks it named — the existing "say WHAT unlocks it" rule stays).

**BENCH** — the tech ladder drawn as the graph `_draw_tech_overlay` already draws, **plus the research verb
on the selected node**. Select a node, see its sample + price + unlocks + what you are carrying, press
Enter. This is the whole of fix #2: the graph and the verb become one screen.

## 4. Away from a Bazaar

The panel opens with the **same layout** — WORKS and BENCH are drawn, readable, and dimmed, with a single
line saying where the verb lives (`at a claimed Bazaar`). Nothing moves, nothing disappears. You can read
every recipe and every tech price from the bottom of a shaft and plan the trip back. This is fix #4, and it
is the whole reason the panel is one shape instead of two.

## 5. Input changes

| Key | Today | After |
|---|---|---|
| `E` | pack screen | **the panel**, on the PACK tab |
| `T` | separate tech overlay | **the panel**, on the BENCH tab |
| `R` | research *and* configure a splitter/hopper | **configure only** |
| `1`/`2`/`3` | hotbar select | hotbar select; **tab select while the panel is open** |
| Enter | — | **research the selected node** (BENCH) / buy the selected row (WORKS) |

`R` losing its second meaning is worth stating plainly: research becomes a thing you do to a node you have
selected and can see the price of, rather than a key you press hoping the right one is next.

## 6. The Rack — deliberately a stub

The Rack is the *surface*; what it sells is a separate design (the tool-shapes idea: picks that differ by
cutting geometry rather than by speed — a Broadhead that takes 2x2 of loose material, a Wedge that drives a
horizontal lance, a Corer that sinks a shaft without touching the walls). Until that is specced, the Rack
sells exactly what `MiningRules` already gates on: the stone pick. **Build the surface, leave the shelves
mostly empty, and let the tool design fill them.** Building it the other way round means guessing an economy
around tools that do not exist.

Pricing principle when they do land: the Rack takes **refined goods** (ingots), not raw ore. It is a sink
for what the factory produces, the same job research already does — so buying a tool is always a reason to
run the factory harder, never a reason to hand-mine more.

## 7. What the harness must say

`tools/check_pack_layout.gd` exists and asserts the panel fits the screen and that the research bench stays
reachable. Extend it, do not replace it:

- every tab's content fits **without scrolling**, at the largest craft list the game can currently produce;
- the panel is the **same size and position** whether or not `can_craft` (fix #4 stated as an assertion);
- every row that is locked names the tech that unlocks it;
- `check_controls` grows a case: `R` aimed at a splitter configures it, and `R` never researches.

## 8. What this deliberately does not do

- **No walking between physical stations.** It was the more diegetic option and it was rejected on the
  complaint that started this: the surface is *annoying*, and adding walking to a menu you open twenty times
  an hour makes it more annoying, not less. The staging is spent on the panel's backdrop instead.
- **No inventory management.** No sorting, no filters, no drag-and-drop. The pack is small on purpose.
- **No new economy.** The Rack spends ingots, which the game already produces and already sinks into
  research. Nothing here introduces a currency.
