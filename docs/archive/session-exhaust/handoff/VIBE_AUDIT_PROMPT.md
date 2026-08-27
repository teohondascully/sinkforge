# The subjective audit — copy-paste prompt

Hand this to a fresh auditing session. It is deliberately written to be pasteable whole.

Everything below the line is the prompt.

---

You are auditing a game called **SINKFORGE** and I want the subjective half — the half no test can
measure. I have twenty-odd harness layers that prove the code does what it says. None of them can tell me
whether the game has a soul. That is your job, and I want it graded, not described.

**Repo:** `/Users/thondascully/Projects/sinkforge` — read anything. Do not modify anything, do not commit,
do not lower a threshold. You are a critic, not a contributor.

## What the game claims to be

A 2D side-on game about **digging a factory into solid earth**. You start on the surface with a pickaxe,
carve down through rock, find ore, and build machines that mine and haul and smelt for you while you go
deeper. Movement is a grappling hook and a winch. The pitch it is chasing is *"Factorio × Terraria, with
gravity that matters."* The world is meant to be solid ground you tunnel INTO — not a cave system you walk
through. It is made in Godot 4.6 by one developer with AI assistance.

Judging it against that pitch is part of the assignment. If it is not that game, say what game it actually
is, and say whether that game is better.

## How to actually see it

You cannot judge this from source. Get pixels.

```
cd /Users/thondascully/Projects/sinkforge
# Renders a canonical MOMENT to _moment_<name>.png. NOT --headless (headless draws blank frames).
# ALWAYS go through with_machine.sh — another session shares this machine and two Godots corrupt
# each other's save state.
bash tools/with_machine.sh --script res://tools/capture_moments.gd -- boot
```

Moments available: `boot` (the first frame a new player ever sees), `delve` (bottom of a dug shaft, lamp-lit,
rock on every side), `room` (a torch-lit work chamber — the only shot showing the back wall as a plane),
`swing` (mid-arc on a live grapple line), `map` (the large minimap over a dug world), `teach` (a rope caught
on a corner with the tutorial bubble that fires for it), `counter` / `works` / `bench` (the Bazaar shop panel
on each of its three tabs), `pack` (two galleries plugged with different materials — a shot whose subject is
a *difference*). Each takes an optional zoom index: `-- delve 1`.

Also: `history/` holds 242 dated screenshots of the game's whole visual life, oldest to newest. `assets/sprites/`
holds the hand-authored pixel art. `docs/` holds the design bible — `GDD.md`, `DECISIONS.md`, `PROGRESSION.md`,
`LODE.md`, `BAZAAR.md`, `MATERIAL_SPINE.md`, and `FEEL_GAP.md`, which is a 26-entry log of every presentation
change and why it was made.

Look at the pictures before you read the docs. I want your reaction to the artifact, not to the intent. Read
the docs after, and then tell me where the two diverge — a gap between what a document promises and what a
screenshot delivers is one of the most useful things you can find.

## Score these. All of them. 0–10, one decimal.

For each: the score, **one sentence of evidence naming a specific file, frame, or moment**, and **the single
highest-leverage change** — the one thing that moves this score most per unit of work. Not a list of five.
One.

1. **Thumbnail Stopping Power** — a stranger scrolling a store page sees one 300px frame for 400ms. Does
   their thumb stop? 0 = indistinguishable from every other brown pixel game; 10 = you'd click.
2. **Era Signature** — where on the 2003→2026 line does this sit, and *what specifically* dates it? Terraria
   reads 2003; Noita reads 2026; both are pixel games, so the answer is not resolution. Name the tells.
3. **Personality Quotient** — does this game have a voice? Opinions, jokes, cruelty, a house style, anything
   that reveals a person made it? 0 = a competent asset flip; 10 = you could identify the designer from a
   screenshot.
4. **Addiction Architecture** — grade the compulsion loop mechanically. Where is the "one more" hook, how
   long is the gap between wanting and getting, and what is the *first* moment a player would put it down?
5. **The First Ninety Seconds** — from launch to the first thing that felt good. Time it in real seconds if
   you can. What happens in that window, and what should?
6. **Verb Feel** — the game's core verbs are dig, swing, haul, build. Rate each separately for tactility:
   weight, feedback, follow-through, the difference between input and impact.
7. **Material Honesty** — does stone read as stone, water as water, metal as metal? Or is everything the same
   substance wearing different hues?
8. **Sprite Craft** — judge the hand-authored pixel art in `assets/sprites/` as pixel art: silhouette
   readability, palette discipline, animation weight, hue variation vs value ramps, whether it holds up at
   1× and at 4×. Be specific and technical. Name what a working pixel artist would fix first.
9. **The Placeholder Index** — inventory everything still reading as programmer art. Not "needs polish" —
   list the actual objects, and rank them by how much they cheapen the frame they appear in.
10. **Diegetic Integrity** — what fraction of the interface is *in* the world versus floating chrome on top
    of it, and does the chrome earn its place? Is the HUD the most vivid thing on screen? (It should not be.)
11. **Lore Load-Bearing** — is the fiction doing structural work, or is it a coat of paint over a systems
    game? Would deleting every word of story change how the game plays? If the answer is no, that is a
    finding, and say whether it *should* be no.
12. **World Coherence** — does the place feel like a place with rules, or a set of mechanics in a shared
    coordinate space? Does the geology imply a history?
13. **Descent Legibility** — the game's whole arc is going down. Put two frames side by side, shallow and
    deep. Can you tell which is which without the depth counter? Does the world visibly change as a reward?
14. **Surprise Budget** — how often does something new happen? Estimate the novelty half-life: at what point
    does the player stop meeting things they haven't met?
15. **Soundstage** — read `scenes/sfx.gd` and the audio docs. Judge the design on paper: how many distinct
    voices, does the space have depth, does the mix have a hierarchy, what is the game's *silence* like?
16. **Cruelty Calibration** — where is this game on punishing↔generous, is that placement deliberate, and
    does it match the fiction? A game about grinding through rock might *want* to hurt.
17. **Menu Craft** — the shop and inventory panels. Do they look like 2026 software? Elevation or borders,
    does the world defocus behind a modal, do costs read as glyphs or as text, is there a wall of locked rows?
18. **Ambition Coherence** — it's chasing Factorio × Terraria. Is it becoming both, neither, or a third thing?
    If a third thing, name it. This is the most important question here.
19. **Name Recall** — would you remember this game tomorrow? What is the one image that would stick? If
    nothing would, say so plainly, because that is the finding that outranks the other seventeen.
20. **The Fun Tax** — units of friction per unit of payoff. Where is the player paying and not being paid?

## Then, three syntheses

- **The kill list.** What should be *deleted*? Features, systems, or visual elements that cost more than
  they return. Be aggressive; nobody else will be.
- **If you had one week.** Ordered, specific, with your reasoning for the order. Assume one developer.
- **Where has the effort actually gone?** Read `git log`, the docs, and the harness. Judge the ratio of
  invisible work to visible work, and say whether it is wrong. I have my own answer to this and I am
  deliberately not telling you, because your independent read is worth more than your agreement.

## How to be useful to me

- **Do not be encouraging.** I have no use for a report that opens by telling me what is working. If
  something works, one clause is enough, then move to what doesn't. Flattery costs me a rewrite.
- **Cite pixels.** "The rock reads flat" is unusable. "In `_moment_delve.png` the rock two cells from the
  lamp and the empty shaft behind it are within four units of luminance, so the wall has no edge" is a fix.
- **Separate what you saw from what you concluded.** Mark inferences as inferences. I have spent two days
  finding gauges that reported confidently about the wrong population, and a confident wrong sentence from
  you costs me a day.
- **Predict before you measure.** Where you have a hypothesis, write it down before you check it, and then
  report whether you were right. Being wrong in writing is worth more to me than being right silently.
- **Argue with the docs.** They were written by the person who made the mistakes. If `FEEL_GAP.md` says a
  problem was fixed and the screenshot says otherwise, the screenshot wins and I want to know.
- **Say the thing you think is too harsh.** Especially about #19. The most valuable sentence in the last
  audit was a blind tester saying "I cannot reliably tell solid rock from empty air, and I want to say that
  loudly." That one sentence redirected a week. Give me that sentence.

Deliver as a single markdown report: the twenty scores in a table with an overall, then the evidence and
recommendation for each, then the three syntheses. Lead with the three findings you would defend hardest.
