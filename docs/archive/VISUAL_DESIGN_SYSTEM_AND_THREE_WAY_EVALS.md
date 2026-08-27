> **Archived from `docs/VISUAL_DESIGN_SYSTEM_AND_THREE_WAY_EVALS.md`, extracted 2026-08-26.** The
> three-way visual experiment protocol — general methodology, not tied to any specific screen. The
> 50-atomic-findings audit and the priority-sequence mapping were left in the untracked original: both are
> about pre-pivot Bazaar-era screens that no longer exist. This project's visual work is out of scope for
> the current one-month vertical-slice push; kept for when it resumes.
>
> **Path update, 2026-08-27:** "the untracked original" above now has an address —
> `docs/archive/VISUAL_DESIGN_SYSTEM_AND_THREE_WAY_EVALS-postpivot-edit-2026-08-25.md`, moved there while
> closing the `.git/info/exclude` hole (ANVIL step 1). Same file, same extraction relationship; it just
> stopped being untracked.

# Three-way visual experiment protocol

Every selected visual component receives three treatments before integration.

## Option 0 — baseline

Capture the current component unchanged. Record the exact commit, state, viewport, zoom, seed, renderer,
and input pose. This is the control, not a straw man.

## Option A — conservative repair

Fix the diagnosed problem while preserving the existing geometry, art assets, and interaction model.
Answers: "Can we remove the obvious defect with low risk?"

## Option B — system-level correction

Apply a coherent visual rule to the component and its immediate siblings — e.g. replace a label with a
source-bound state indicator, give all controls one focus/disabled/active family, make a light derive from
source/occlusion/falloff, give terrain two distinct variation languages rather than repainting one tile.

## Option C — distinctive alternative

A more opinionated direction that could make the game memorable. Must remain playable and compatible with
the world; allowed to change layout, silhouette, typography, palette role, or effect language. Not
permission for a global rewrite — a bounded provocation to reveal whether the current design is merely
familiar because nobody tried a stronger idea.

## Required comparison

All three options must use: the same gameplay state, seed and camera pose, viewport and zoom, input
sequence where motion matters, renderer and machine conditions, and capture naming/evidence format. For a
UI component, capture quiet, active, disabled, focused, and error states. For terrain, capture daylight,
underground, lamp-lit, fresh-excavation, and material-boundary states. For motion, capture a short ordered
sequence, not only a still.

## Evaluation rubric

Score each option 0–10, with one evidence sentence per dimension:

| Dimension | Weight | Question |
|---|---:|---|
| First-read hierarchy | 20 | Does the eye know what matters first? |
| Game identity | 20 | Could this belong to this game and not any generic survival game? |
| Play legibility | 15 | Can a first-time player infer the next useful action? |
| Material/physical honesty | 15 | Do objects, light, terrain, and effects behave like their meanings? |
| Integration | 10 | Does the treatment improve the surrounding frame rather than one isolated object? |
| Motion/state clarity | 10 | Does it communicate transitions, commitment, tension, and consequence? |
| Restraint | 5 | Does it remove noise rather than add a new layer of noise? |
| Cost and risk | 5 | Is the improvement proportionate to implementation and regression risk? |

The director selects the option. The agent may recommend one but may not silently choose its favorite. A
visually attractive option that lowers first-read hierarchy or play legibility is rejected.

## First-time-player review questions

After seeing each option for 400ms, ask: What is the player supposed to notice first? What can the player
do right now? What object or material is most important? What changed between baseline and treatment? What
do you think will happen if you interact with it? Does anything look like debug scaffolding or a
placeholder? Does this look like a game with a specific authorial taste?

For active sequences, additionally ask: Did the visual state explain why the action succeeded or failed?
Did the effect make the action feel heavier, sharper, or more deliberate? Did any helper or effect obscure
the thing being acted upon?

The actor/evaluator must distinguish "the player could not understand the game" from "the evaluator could
not understand the game." A failed review is a finding only after the test fixture and actor capability are
validated.

## Isolation and integration rules

- Experiments happen in one disposable visual-design workspace or temporary duplicate of the selected code
  slice.
- Do not create a fleet of feature worktrees.
- Do not edit gameplay, save schema, thresholds, or unrelated visual systems while comparing options.
- Do not overwrite canonical captures.
- Do not run two Godot or harness processes concurrently.
- Preserve each option as a patch, branch ref, or exported diff until the director chooses.
- Integrate only the selected option against current `main`.
- Run the strongest relevant functional and visual verification after integration.
- Rejected options remain documented with the reason they were rejected.

## Definition of success

This programme succeeds when a new player can look at a frame and say, without coaching: what the place is;
what the player is doing; what matters now; what is solid, empty, wet, valuable, or dangerous; which
machine is physical and what it is doing; what the next action might be; and why this looks like this game
rather than a generic prototype.

It does not succeed because every panel has a border, every material has more noise, or every screenshot is
technically free of collisions.
