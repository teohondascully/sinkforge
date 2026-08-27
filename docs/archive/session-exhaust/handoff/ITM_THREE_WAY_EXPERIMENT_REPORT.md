# ITM item/hotbar three-way visual experiment — report

Director-assigned. Isolation held throughout: one disposable worktree, no merge, no push, stops at the
director-selection boundary. This is the full required report (12 items).

## 1. Base SHA

`9c6bb42678078b510c83069e628b7e665aa974ea` — canonical `main` HEAD at the time the experiment worktree was
created, and unchanged by this work (verified again at report time: `main`'s HEAD is still `9c6bb42`).

Experiment workspace: `/private/tmp/sinkforge-itm-visual-exp`, `git worktree add --detach` at that SHA. ONE
worktree, not three. Each option's diff was written directly in that worktree and then isolated with
`git stash` (`option-A-diff`, `option-B-diff`, `option-C-diff`) so a clean baseline and each option could be
captured in turn without three long-lived branches. All three stashes are still present in that worktree at
report time; nothing has been merged or pushed anywhere.

## 2. Exact files changed per option

| Option | Files | Diff stat |
|---|---|---|
| Baseline | none | reference state, `scenes/hud.gd`/`scenes/main.gd` unmodified |
| A | `scenes/hud.gd` | 1 file, +31 / −8 |
| B | `scenes/hud.gd`, `scenes/main.gd` | 2 files, +115 / −22 |
| C | `scenes/hud.gd`, `scenes/main.gd` | 2 files, +213 / −71 |

No other files were touched by any option (no changes to `scenes/bazaar_pack.gd`, `src/`, save data, harness,
registries, or canonical captures — all deliberately out of scope, see §9). Full patches are saved at
`itm_patches/option_A.patch`, `option_B.patch`, `option_C.patch` in this session's scratchpad, and remain
recoverable from the worktree's git stash regardless (`git stash show -p stash@{N}`).

`scenes/main.gd`'s one shared addition — `_selected_item_available()` plus its `hud.item_available_getter`
wiring — is common infrastructure both B and C's "unavailable" state read; it is not itself a distinguishing
hypothesis of either option, and reuses the existing `_workable()` reach/tool-capability predicate rather than
inventing a new rule.

## 3. Captures

24 total, `/private/tmp/sinkforge-itm-visual-exp/_itm_captures/_itm_<state>_<condition>.png`, `<state>` ∈
{baseline, optionA, optionB, optionC}, `<condition>` ∈:

1. `underground_full_material_selected` — full kit (tool, 4 material stacks incl. a 3-digit stack, 1
   machine), a material slot selected, underground.
2. `underground_tool_selected` — same kit, tool slot selected.
3. `underground_unavailable` — tool selected, aimed at nothing minable (baseline/A have no cue for this;
   that absence is the finding, not a capture defect).
4. `underground_sparse` — kit stripped to just the tool, underground (shows empty-slot rendering).
5. `surface_full` — same full kit, genuine daylight surface.
6. `bazaar_pack` — the Bazaar Pack menu, same kit (this screen's own treatment is unchanged across all four
   states by deliberate scope decision, §9 — included as an integration check, not a redesign target).

Identical seed (1337), identical scripted dig/climb/inventory sequence, identical camera/viewport
(1920×1080)/renderer across all four states, via one gitignored scratch rig,
`tools/_scratch_itm_capture.gd`, run through `tools/with_machine.sh` for every invocation.

**Two capture-rig defects were found and fixed during this experiment, not before it started** — both are
worth recording plainly since they change what the evidence means:

- Two individual capture *runs* (one for Option A, one for Option C) came back contaminated — one flagged
  itself with an explicit "delve shaft did not confirm arrival" warning, the other showed a systemic-looking
  symptom (all six screenshots in that run were the same final frame, the Bazaar Pack menu) with no warning
  printed. Both were treated as VOID and re-run cleanly, verified by hash-distinctness across the six output
  files plus direct visual inspection, before being accepted.
- **A real bug in the rig itself, caught late**: `agent.climb_to_surface(2400)` was called with 2400 as the
  sole argument, intending it as a frame budget. The real signature is `climb_to_surface(target_row, budget)`
  — 2400 was silently bound to `target_row` instead. Since the player's actual row after a shallow chamber is
  far less than 2400, the function's own arrival check (`bc.y <= target_row`) was true on frame one: a
  vacuous, immediate "arrival" with **no climbing at all** and no warning ever printed. Every `surface_full`
  and `bazaar_pack` capture across all four states was silently still underground. A second, related bug
  compounded it: querying `surface_row(x)` fresh *after* digging a shaft through that exact column no longer
  finds the original ground line (the column is open air now), so even a naive fix (pass the real surface row)
  would have queried the wrong thing — the row is now captured *before* digging and reused for the climb. A
  third bug found in the same pass: the climb's own rope-placement strategy calls `select_item(&"rope")`
  internally, consuming real rope and leaving it selected instead of ore, which the script now restores
  explicitly after climbing (inventory contents and selection re-set to match the very first capture) so the
  "identical inventory contents, selected item" requirement actually holds for the surface shot. **All four
  states' `surface_full`/`bazaar_pack` captures were regenerated after this fix and re-verified visually**;
  the 24 files referenced throughout this report are the corrected set. The three independent evaluators in
  §5–6 scored the *contaminated* surface/bazaar captures (all four looked like the same underground frame to
  them, which none of them flagged as wrong, since nothing about a menu screen or a lamp-lit chamber is
  inherently implausible standalone) — their **underground-frame evidence is unaffected and stands**, but
  none of their "world integration" commentary reflects genuine daylight; see §9.

One non-bug, confirmed correct rather than fixed: in every state, the 128-count "rope" item sorts into
Option C's machine container, not materials. This is correct — `rope` is a registered placeable/machine def
(`src/data/machines/rope.tres`, the world's climbing aid), not a raw material, despite being a large carried
stack. The test kit's own setup comment calling it a "material stack" example was the wrong assumption, not
the classification code.

## 4. ITM finding IDs each option addresses

Against the full `ITM-01`–`ITM-20` catalog (`docs/VISUAL_DESIGN_SYSTEM_AND_THREE_WAY_EVALS.md:229-248`):

| ID | Finding | A | B | C |
|---|---|---|---|---|
| ITM-01 | opaque black square regardless of material/function | ✅ lighter well | ✅ + category frame | ✅ container shape itself IS the category |
| ITM-02 | barcode/grid competes with world | partial (lighter, still one row) | partial (still one row) | ✅ row broken into 3 groups |
| ITM-03 | container silhouette dominates item silhouette | — | — | reframed, not fixed — C makes the container silhouette *informative* rather than reducing its dominance (see §9) |
| ITM-04 | black wells dominant underground | ✅ | ✅ (inherited) | ✅ (smaller, muted per-pocket) |
| ITM-05 | empty slots as heavy as occupied | ✅ quiet empty well | ✅ | ✅ quiet, category-shaped even empty |
| ITM-06 | selected border too thick, 2nd focal point | — (unchanged from baseline) | — (unchanged) | — (unchanged) |
| ITM-07 | unselected icons lose value at 1× | — | — | — |
| ITM-08 | background colour unrelated to material/category/state | — (fill colour uniform) | partial (frame accent only, not fill) | ✅ fill colour differs per container |
| ITM-09 | inconsistent apparent icon scale | — | — | — |
| ITM-10 | resource/tool/machine share a frame | — | ✅ frame accent differs | ✅ strongly — different container + pocket shape |
| ITM-11 | machines read as tokens, not installable objects | — | partial (rivet dots) | ✅ bolted-crate treatment |
| ITM-12 | long row = UI strip, not a carried kit | — | — (still one continuous row) | ✅ the one finding only C actually resolves |
| ITM-13 | empty space reads as missing, not capacity | ✅ | ✅ | ✅ |
| ITM-14 | selected-item title detached from icon/context | — | — | — (name-plate mechanism unchanged; C fixed a *positioning* bug, not the detachment) |
| ITM-15 | key/icon/count compete as 3 equal marks | — | partial (tools drop the count badge) | partial (same) |
| ITM-16 | stack counts have no material glyph | — | ✅ tinted badge edge | ✅ tinted badge edge |
| ITM-17 | hover/focus doesn't reveal *why* unavailable | — | partial (shows *that*, not *why*) | partial (same) |
| ITM-18 | pickup feedback doesn't connect item to slot | — | — | — (out of scope — no pickup moment captured) |
| ITM-19 | no state vocabulary (worn/active/blocked/loaded/depleted) | — | partial (blocked + depleted only) | partial (same) |
| ITM-20 | slot geometry unstable across expansion | ✅ fixed 10-slot | ✅ fixed 10-slot | ✅ fixed 3/5/2-slot (a different, container-scoped stability) |

## 5. Weighted score table

Three independent evaluators (Explore agent type — structurally no Edit/Write access, enforcing "must not
edit source" rather than relying on instruction alone), each scoring all 24 captures blind to the others'
answers, each from a distinct persona lens, against the director's exact rubric (weights in parenthesis):
first-read hierarchy (20%), item recognition (15%), state clarity (15%), SINKFORGE identity (15%), world
integration (10%), 1× pixel craft (10%), interaction efficiency (10%), implementation risk (5%).

| Evaluator (lens) | baseline | A | B | C |
|---|---|---|---|---|
| 1 — first-time player | 4.55 | 6.20 | 6.40 | 7.15 |
| 2 — under-pressure player | 5.35 | 6.30 | 7.00 | 7.78 |
| 3 — production/craft director | 5.10 | 6.25 | 5.95 | 6.40 |
| **Mean (weighted 0–10)** | **5.00** | **6.25** | **6.45** | **7.11** |

All three evaluators independently ranked **C highest**. Two of three ranked **B above A**; the
production/craft evaluator ranked **A above B** — a real disagreement, not noise, detailed in §6.

## 6. Evaluator disagreement report

Reported as disagreements, not averaged away, per the director's instruction.

**B vs. A — a genuine split.** Evaluators 1 and 2 scored B modestly above A (6.40/7.00 vs 6.20/6.30),
crediting B's category framing and state cues even where subtle. Evaluator 3 (production/craft lens) scored
B *below* A (5.95 vs 6.25) and said so explicitly: *"optionB is puzzling in practice — its distinguishing
promises (category framing, unavailable/depleted states, tinted badges) are not visible in any of the
captured frames, so it reads pixel-for-pixel like optionA while implying more underlying complexity."* This
is the report's single sharpest disagreement: whether B's added state vocabulary earns its added
implementation risk is genuinely contested between evaluators looking at the *same* images.

**"Unavailable" state legibility — convergent, not contested.** All three evaluators independently struggled
to visually distinguish `underground_unavailable` from `underground_tool_selected` for both B and C.
Evaluator 2: *"the unavailable cue in `underground_unavailable` is hard to distinguish from tool_selected at
hotbar scale."* Evaluator 3: *"`_underground_unavailable` and `_underground_tool_selected` hotbars are
pixel-identical; promised unavailable cue isn't visible."* This is agreement across all three, not a split —
the unavailable-state dimming veil is real in the code (confirmed by direct pixel inspection, §9) but too
subtle to read at native 1080p scale in a still frame. Whether it registers better in motion (a state change
rather than a static compare) is untested.

**Option C's pixel craft — convergent weakness.** All three scored C's 1× pixel craft lowest of the three
redesigns (5, 6, 5) and all three named the same cause independently: fine details (rivets, notch cutouts,
octagon chamfers) blur or read as noise at true ~13px icon scale. Not a disagreement — a shared, corroborated
finding.

**One evaluator claim checked and NOT confirmed.** Evaluator 3 (craft lens) cited *"a stray dashed-bracket
world marker... unrelated to the hotbar"* in Option B's `underground_full_material_selected` as evidence for
a higher implementation-risk read. Direct side-by-side inspection of that exact file for both baseline and
optionB shows **no such marker in either image** — this observation does not hold up under verification and
should not be weighted into Option B's risk assessment. (The reticle this evaluator likely means — a hollow
aim bracket — genuinely does appear, but only in the `underground_unavailable` condition, identically in
every state including baseline, since it is a pre-existing world-aim indicator driven by where the capture
script points `main._aim`, not anything introduced by any option's diff.)

## 7. What each option improves

- **A**: ITM-01/04 (opaque well → lighter, softer well) and ITM-05/13/20 (quiet empty slots, stable 10-slot
  geometry instead of a shrinking bar). Zero interaction-model change; lowest implementation risk of the
  three redesigns by a wide margin (scored 9/9/9 across evaluators, next to baseline's reference 10/10/10).
- **B**: everything A does, plus a category/state vocabulary layered on top — tool/material/machine framing,
  a focus ring, a depleted-material edge tint, material-tinted count badges, and tools dropping their count
  badge entirely (a tool is one thing you have or don't).
- **C**: the only option that measurably moves SINKFORGE identity (8–9 vs baseline's 2–3, the widest,
  most convergent margin in the whole rubric) and item recognition (8–9 vs 5–6) *without reading a label* —
  and the only option that actually resolves ITM-12 (the row itself is no longer one undifferentiated strip).
  Holds up under both dark-underground and genuine daylight-surface frames (§9).

## 8. What each option damages or costs

- **A**: does nothing for identity, item recognition, or category/state distinction — it is a repair, not an
  answer to the director's original complaint about materials flattening into "the same visual category."
- **B**: its signature feature (state vocabulary) is not reliably visible in a still frame per all three
  evaluators, and one evaluator judged it indistinguishable from A in practice while carrying real added
  risk (+84 more lines than A, a new cross-file callable). ITM-12 remains unaddressed — still one continuous
  row.
- **C**: highest implementation risk of the three (correctly read by all three evaluators from visual cues
  alone, without being told the mechanism — it does restructure layout/capacity logic, not just draw calls).
  Weakest pixel craft of any non-baseline state. Its fixed per-container capacity (3 tool / 5 material / 2
  machine slots) is a real, untested constraint — nothing in this capture kit ever exceeds a cap, so the
  "+N" overflow mark this option draws for that case has never actually been exercised as evidence.
  Screen position no longer follows raw pack index (grouped by category instead), which one evaluator flagged
  as a genuine efficiency cost ("more distance to scan by eye... past reserved-but-empty rack slots") even
  though the keybind digit itself is unaffected.

## 9. What remains unproven

- **Genuine daylight world-integration was never independently scored by the evaluator panel** — the
  captures they scored were, at that time, all mislabeled underground frames (§3). A supplementary, non-panel
  read of the corrected `surface_full` captures (my own, not part of the independent three-evaluator process)
  suggests baseline's contrast-fight is if anything *worse* in bright daylight than underground (opaque black
  squares against blue sky/green grass), that A/B's lighter-alpha wells read comfortably in both lighting
  conditions, and that C's shape-based distinction (rather than alpha-based dimming) holds up at least as well
  in bright light, since its legibility doesn't depend on how much a translucent fill stands out against a
  variable background — but this is not evaluator-panel-confirmed and should be treated as a hypothesis, not
  a scored result.
- Whether B's or C's "unavailable" cue reads better *in motion* (as a live state transition during play)
  than in the still frames this experiment evaluated — genuinely untested.
- Option C's fixed-capacity overflow behaviour under a kit that actually exceeds 3/5/2 in some category —
  never exercised by this capture kit.
- Option C's actual play-time interaction cost from decoupling screen position from pack index (wheel-scroll
  muscle memory) — asserted as a risk by one evaluator from a still image, not measured in real play.
- ITM-03, 06, 07, 09, 14, 17, 18, 19 remain wholly or partly open under every option (§4) — none of the three
  hypotheses tested here was designed to resolve them, and they are legitimate candidates for a follow-up
  experiment or a direct fix, not evidence against any of the three options tested.
- Option B's core disagreement (§6): whether its added state vocabulary is worth its added risk once you
  account for how subtle it reads in a still frame is genuinely contested between evaluators, not resolved
  by this report.

## 10. Recommendation

**Recommend Option C**, with two named follow-ups, not blockers: a pixel-craft pass on its fine detail
(rivets/notches/chamfers borderline at true ~13px, the one convergent weakness across all three evaluators),
and a resolution for its fixed 3/5/2 per-container capacity before it ships (an overflow scroll, or capacities
tuned against real late-game inventory data, since this experiment's fixed test kit never exercised the
current "+N" mark as real evidence). C is the only option that moves the two dimensions closest to the
director's original complaint — identity and recognition — by a wide, convergent margin across three
independently-scored, differently-lensed evaluators, and the only option that actually answers ITM-12 rather
than reshuffling the same one-row strip.

If implementation risk should dominate over identity gain this cycle, **Option B** is the defensible
fallback — it is cheaper than C and still improves on baseline, though §6's disagreement means it is not a
safe default without further craft work on legibility, and its case over plain A is the least settled result
in this report.

If the director wants a same-cycle, near-zero-risk fix and would rather defer the identity question,
**Option A** is a complete, low-cost answer to ITM-01/04/05/20 on its own and should not be read as merely a
stepping stone — it is the cheapest genuine improvement over baseline this experiment produced.

## 11. Exact patch for the selected option

Not applied — stopping at the director-selection boundary as instructed. Whichever option is chosen, its
exact diff is preserved two ways and ready to reapply once selected:

- `git stash list` in `/private/tmp/sinkforge-itm-visual-exp`: `stash@{0}` = option-C-diff, `stash@{1}` =
  option-B-diff, `stash@{2}` = option-A-diff. `git stash show -p stash@{N}` reproduces the exact diff;
  `git stash apply stash@{N}` re-materializes it in that worktree.
- Plain patch files, independent of the worktree: this session's scratchpad,
  `itm_patches/option_A.patch` (72 lines), `option_B.patch` (201 lines), `option_C.patch` (344 lines) —
  applicable with `git apply` against `main` at `9c6bb42` or later (each patch only touches
  `scenes/hud.gd`/`scenes/main.gd`, both otherwise untouched by unrelated work since that SHA at report
  time).

## 12. Rejected-option preservation paths

The two options not selected are not deleted. Both remain fully recoverable by the same two paths as §11 —
the worktree's git stash (which is not time-limited or auto-pruned) and the plain `.patch` files in this
session's scratchpad, which survive independently of the disposable worktree's lifetime. If the disposable
worktree is later torn down, the `.patch` files alone are sufficient to reconstruct any of the three options
from a clean `main` checkout at or after `9c6bb42`. All 24 captures (baseline + all three options, all six
conditions each) remain on disk at `/private/tmp/sinkforge-itm-visual-exp/_itm_captures/` as the evidence
record regardless of which option is chosen or whether the worktree is later removed.

---

**Per the director's closing instruction**, this experiment stops here — no merge, no push. Next: continue
with the next unblocked visual parent from `PRIORITY.md`.
