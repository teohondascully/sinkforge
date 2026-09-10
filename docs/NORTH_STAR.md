# North star: what this is supposed to feel like

**Status: normative for feel, provisional in its remedies.** Written 2026-09-10 after the first
playthroughs this project has had from a driver that could actually play the game. It exists because
the repo had four documents about how the frame should look (`VISUAL_QUEUE.md` on legibility,
`TASTE_QUEUE.md` on open art forks, `EXPERIENCE_EVALUATION.md` on the harness, `archive/FEEL_GAP.md`
from before the pivot) and none that said what the thing should FEEL like. Without that sentence, every
finding from a blind playtest reads as "the player was confused", every fix reads as "add a sentence
explaining it", and six batches in a row produce labels, rings, readouts and reworded lessons. That
drift is not a failure of any one session. It is what happens when the only written standard is
comprehension.

The director's words, which this document exists to hold: *"I'm more concerned about just the entire
Tiny Glade / Noita north star for design feel and uniqueness. This game doesn't pass as 2026, it passes
as 2016."*

---

## 1. The bar, stated so it can be failed

**Tiny Glade** and **Noita** are not being cited as art direction. They are cited because each one
answers a question this project has been answering with text.

**Tiny Glade: the game teaches itself by responding.** It has almost no HUD and almost no words. You
learn what a wall is by dragging one and watching it thicken, sag around a rock, and grow a doorway
where a path meets it. Every input has a visible, immediate, physical consequence, and the consequence
IS the explanation. Nothing is ever announced.

**Noita: the world is made of stuff, and the stuff obeys rules you can see.** Sand falls and piles.
Water flows downhill and finds the low spot. Burn a rope and what it held drops. You are never told any
of this and you never need to be, because a single frame of the world behaving teaches it. Its identity
is not its pixel size, its palette, or its lighting. Its identity is that **the world answers back**.

These two make one bar, and it is a single sentence:

> **Everything the player does to the world produces a physical consequence in the world, and that
> consequence is the whole explanation.**

Measured against that sentence, this build does not pass. It is not close. That is the finding, and
the rest of this document is the evidence and the consequences.

**One thing this does NOT change.** `GDD.md` §1 refuses Noita as a *movement* reference and gives the
argument (Noita's frictionless feel comes from flight, which breaks R1). That argument still holds and
this document does not reopen it. The director's Noita is the Noita of falling sand, not of flying.
The two are compatible: take the material, refuse the flight.

---

## 2. What the build actually does, measured

Two playthroughs on `691c005c`, 2026-09-10. `s_feel_01` opened a fresh game; `s_back_01` opened the
rung-4 save and drove the ladder to rung 7. Both were driven by the session that wrote the code, with
the source open, the receipts visible and a calibrated screen-to-cell map. This matters: every failure
below is a failure that survives a driver who knows everything.

### 2.1 The world does not answer back. At all.

| The player does | The world does |
|---|---|
| Removes 42 cells of earth in one blow | Nothing. No debris, no dust, no sound cue, no camera response. |
| Undercuts a mass of rock | Nothing. It hangs. |
| Cuts the ground out from under their own boots | Nothing. They stand on air. |
| Digs a hole | The hole looks exactly like a cave that was always there. |
| Completes their first automation | Two 20x40 px icons gain a green dot and a number. |

Nothing in this table is a bug report. Each row is a place where the game had an opportunity to explain
itself by behaving and took the opportunity to say nothing instead. That silence is what 2016 is.

### 2.2 The trap: a player who digs down cannot get back up

The most expensive finding, and the one that most cleanly proves the point. `s_back_01` descended
7.5 m to the crew's cache in 71 bursts, then spent **515 bursts** failing to climb out, using jump,
mantle, both grapple bindings, and cut-the-ceiling-then-jump. It rose 2 m and then sat at the same cell
for 365 consecutive commands.

The arithmetic: `Body.JUMP_VELOCITY_PX_S` 365 against `GRAVITY_PX_S2` 900 gives an apex of 74 px =
**4.6 m**. The shaft was **5.2 m** deep. The player is trapped by sixty centimetres, in a slot too
narrow to mantle.

The grapple ANCHORS correctly -- the rope and its anchor marker are drawn -- and then the line wraps on
the shaft's own lip and 240 ticks of held reel move the body zero pixels. `GDD.md` §1 says, in bold:
*"The rope and grapple are this game's answer to the same problem, and should be treated as the
vertical traversal primitive, not one feature among several. Fast attach, fast climb, no fumbling,
auto-anchor at shaft mouths."* **None of those four properties is true today.** The document's most
load-bearing traversal claim has never been exercised by anything except a unit test.

### 2.3 Descent is a pixel-hunt, not a verb

`sim/mining/footing.gd` (D0509) spares the body's four support cells from every blow whose aim is not
exactly one of them. D0509 is a good decision -- it stopped three strangers from being dropped into
holes they did not mean to dig. Its consequence at the controls was never measured: **to go down, the
player must land the aim on one of four 4-px cells under their own boots**, and every near miss
silently hollows out the rock around them instead. `s_feel_01` cut eleven cells straight down beneath
itself and descended zero. `s_back_01` needed 31 bursts to fall its first 1.5 m, and managed it only
because the driver read `Footing` in the source and computed the support row by hand.

The `cut_through` lesson currently says "a hole has to be a little wider than you before you drop in".
That sentence describes the symptom of a spare rule. It is not a rule of the world, and no amount of
rewording it will make the verb feel like digging.

### 2.4 The payoff beat has no frame

Rung 6 is captioned, in the ladder's own words, *"Stand back -- the fuelled Drill bores the vein and
pours ore and coal into the forge below. First automation!"* It completed between two bursts while the
driver stood four metres away looking straight at it. The drill does not visibly bore. No ore falls.
No light changes. The exclamation mark is in the text and nowhere else.

### 2.5 The frame is furniture over mud

Counted off single frames: **seven dark rounded rectangles on screen at once** (depth chip, objective
banner, minimap, machine inspector, hotbar, lesson card, damage floater), plus floating all-caps world
labels which collide with each other -- "MOUTH" is drawn on top of "FORGE" at the shaft mouth. At the
`cut_through` moment there were five lines of instructional prose in the left third of the play area
and three more across the top.

Behind the furniture: one uniform brown noise field from the surface to 7 m down, across a band change,
with no strata and no structure; caves and dug space the same near-black; no depth haze; no
particulate; and nothing lit except the miner's own lamp. **The lamp is the single most 2026 thing in
the build and it works** -- which is the proof that the rest is a choice, not a limit.

---

## 3. What would have to be true

In the order that buys the most feel per unit of work. Each item names how it would be judged, because
"it feels better" is not a finding.

### T1. Loose material falls, and piles

The one change that pays three times: it is the feel fix, it is the identity, and it is `GDD.md` §13's
position two -- *"holes: gravity routing. free. dug, not built"* and *"the player's first automation
should be a hole they dug, not a machine they bought"* -- which is **unbuildable today because nothing
falls**. Clay and sand slump; hardrock does not. An undermined mass drops.

*Judged by:* undercut a shelf and watch it come down; the first automation in a session is a chute the
player cut, with no machine placed.

### T2. The body obeys the same gravity as the material

The support-spare rule stays (D0509 earned it), but the aim must not have to hit a 4-px target for the
world to respond. Cutting the ground under yourself should drop you, every time, with the fall being
the feedback. And a shaft the player dug must be climbable by the primitive the GDD already named.

*Judged by:* a competent driver descends 10 m and returns to the surface in under 30 commands. Today
that number is unbounded -- 515 and counting.

### T3. Every removal produces debris

Dust at the face, chips that fall and settle, a lip on the cut. A dug hole must not look like a cave.

*Judged by:* a still frame of a dug shaft is distinguishable from a still frame of a natural void by
someone who did not watch it happen.

### T4. The first automation gets a frame of its own

Something falls. Something glows. The camera notices. If rung 6 completes and a watching player cannot
say what just happened, the rung has no content, only a predicate.

### T5. Warm against cool, at every band

Astra's diagnosis point 3, still unfixed: nothing in the frame is warm against anything cool below the
surface. The forges have fire in their icons and light nothing.

### T6. Delete the prose the world can say

Every lesson that could be an embodied cue should become one. The miner physically failing to reach is
better than a sentence about 3.2 metres. **This item removes shipped work, including work shipped
yesterday, and that is correct.**

*Judged by:* the count of on-screen dark rectangles, and the count of prose lines in the play area at
any moment. Both are measurable per frame and both should fall.

---

## 4. The rule this document exists to enforce

**If the answer to a playtest finding is a new sentence on screen, it is probably the wrong answer.**

Six batches of blind strangers produced labels, rings, distance readouts and reworded lessons. Each
individual change was defensible and several measurably worked -- delivery went from 0 of 6 to 4 of 6.
But instructional furniture is what 2016 looks like, and a game that needs seven panels to explain
itself has a feel problem that no eighth panel will fix. The strangers were answering the question they
were asked, which was "were you confused". Nobody was asking whether the world was alive.

A finding gets a sentence only when the world genuinely cannot say the thing. That case is rarer than
six batches of evidence would suggest.
