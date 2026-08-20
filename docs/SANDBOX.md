# THE SANDBOX — a contact sheet, not a second game

> **Status: NOTE FOR LATER (2026-08-16).** Raised by the user: *"I wonder if it's worth it to create an
> almost sandbox testing environment so that you can test isolated features like lighting, materials, tools
> etc in a specialized mini sandbox world... ie for ores you could have a sandbox environment with like every
> ore side by side."* With an invitation to push back. This is the push-back and the counter-proposal:
> **yes, and it is worth building — but as a thin parameterised layer over `tools/capture_moments.gd`,
> never as a separate world.** Not scheduled; picked up when a tuning task next justifies it.

## 1. The honest case FOR it, from today

This is not speculative. Shipping the lode's rendering (#S38) cost **four full staging iterations**, each of
which was: hand-author a chamber in `capture_moments.gd`, hand-place torches, hand-pick a cursor warp, run a
~40s windowed capture, `sips`-crop by guessed pixel offsets, look, adjust. The thing being judged —
*does a vein read as a vein, and can you see how much is left?* — is a **comparison**, and a comparison had
to be hand-built: I authored four depletion states side by side because there was no other way to see them
together.

Three specific costs, each of which a sandbox removes:

1. **Comparisons must be hand-staged.** "Full vs two-thirds vs a third vs spent" only existed because I wrote
   the four states out by hand. Every future material question has the same shape.
2. **Worldgen noise swamps the subject.** `check_lode`'s conservation case sums **673,245** units of ambient
   world deposits to assert on a 60-unit vein. It works, but the signal is 0.009% of the number.
3. **One look costs one capture.** Judging N variants means N runs and N `Read`s. The expensive part is not
   the render — it is that each variant arrives in a separate image.

## 2. The push-back: what would make it WORSE than what we have

A sandbox that is its own scene, with its own lighting rig and its own fixture code, is a **second game that
looks like the first one**. Tuning a material there and shipping it is how you get art that was correct in
the lab and wrong in the dark. Specifically it would break the thing that makes our current captures
trustworthy: `capture_moments.gd` boots **`res://scenes/main.tscn`** — the real scene, real veil, real lamp,
real fine-terrain bake — and stages a world inside it. Every capture in `history/` is the actual game.

So the rule that keeps this honest:

> **The sandbox is a FIXTURE, never a scene.** It boots the same `main.tscn` every capture already boots, and
> the only thing it adds is control over what is in the world and what the light is doing.

Second push-back: **the sandbox judges A-vs-B; it never judges "good".** A lineup answers *is this fleck
count more legible than that one* — it cannot answer *does a vein read in a real dark tunnel forty metres
down*, because a lineup deletes exactly the context that question is about. The verdict still belongs to the
real world and to the blind-vision pass. If the sandbox ever becomes where things are signed off, it has
turned into the failure mode above.

> **AND THE ARBITER NAMED IN THAT SENTENCE CANNOT ARBITRATE A LINEUP — 2026-08-20.** This paragraph hands
> the verdict to "the blind-vision pass", and a later pass has now measured what that pass does when
> shown two frames side by side. Twelve zero-context judges, sides balanced six and six, zoom forbidden:
> **12 of 12 called the RIGHT-hand frame the better ground** (p = 0.0005), and 11 of 12 called the LEFT-hand
> frame the glitch. Split by what was actually on screen, both questions land on a tie. The two questions
> are one axis answered by POSITION in opposite directions, which is what makes it position rather than
> taste. An earlier nine-judge four-way ranking was equally empty: mean ranks 2.00 / 2.22 / 2.44 / 3.33
> against a chance mean of 2.50, SE 0.37.
>
> **A contact sheet is a lineup with slots, so this design is the maximally exposed case**, not an
> incidental one: the whole workflow win in §3 is "N variants in one frame", and every variant is therefore
> wearing a position. Building the bays and then asking a blind judge which bay wins would produce a
> confident, reproducible, entirely positional answer.
>
> **What survives is the half that works.** The judges' free-text descriptions were content-accurate in all
> twelve — every one called the speckled frame speckled and the smooth one smooth, whichever side it was on.
> So the rule for this tool is: **ask a blind judge what it SEES in one bay; never ask it which bay it
> prefers.** The lineup is for a human eye and for measurement. If the sandbox is built, the sign-off
> sentence above needs rewriting first, because as written it points the tool at its one broken mode.

## 3. What to actually build

The valuable artifact is not an environment. It is **one image**.

**`tools/sandbox.gd` — a parameterised fixture + contact sheet.**

- **Bays.** A row of identical carved bays in the real scene, one per subject, each with a label rendered
  into the shot. `--subjects=ore,rich_ore,iron,coal` gives four bays, one per material.
- **A second axis, gridded.** `--axis=light:0,0.25,0.6,1.0` or `--axis=depletion:1.0,0.66,0.33,0.0` stacks
  rows. The lode question — *every ore × every depletion state* — is then one command instead of four
  hand-authored states.
- **Controlled light.** The one thing the real world will not hold still. Torch placement and lamp radius per
  row, so "how does this material behave from unlit to fully lit" is a row you can read across.
- **ONE output.** The bays are laid out to fit a single frame and saved as `_sandbox_<subject>.png`. That is
  the actual workflow win: one run, one look, N variants — instead of N runs and N looks.

**Roughly 150 lines**, most of it fixture-building that `capture_moments.gd` already demonstrates. It should
share `capture_moments.gd`'s boot and shutter so there is exactly one way a screenshot gets taken.

## 4. What it is NOT for

- **Not a harness layer.** It renders and saves; it asserts nothing. The `check_*` layers keep owning truth.
- **Not a play space.** No agent drives it. `play_tests` owns whether the game can be played.
- **Not a sign-off venue.** See §2. It proposes; `history/` and the blind-vision pass dispose.

## 5. First job when it exists

`docs/LODE.md` §11 — ore's light response. Every ore material × four light levels × three depletion states,
on one sheet, is precisely the picture needed to tune "special but not overstimulating", and it is the
picture that cannot be hand-staged in fewer than a dozen captures.
