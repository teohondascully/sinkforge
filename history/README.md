# history

Curated images, capped at 12. An image earns its place by illustrating a finding, not by marking a
date. When a thirteenth is worth keeping, one comes out, and the swap is a line in `docs/BRIEF.md`'s
"What was learned" section (`docs/DECISIONS_LEDGER.md` if the swap is itself a judgment call worth
logging, e.g. changing the selection criterion).

Candidates worth watching for as they become available: the debug renderer showing the heightfield
resolving a rubble slope, the hostile chamber, a collision/stall heatmap, the claim board once claims
have measured values. The debug-renderer shots matter specifically because "this is what it looked like
while we were only measuring" is the strongest visual for the method story, and it stops being
capturable the moment there is real art.

**Added 2026-08-28, docs/GDD.md §12's reveal-layer test (`claims/C004`):** `153-the-glimmer-in-the-wall.png`
(the reveal mechanism working — a freshly-dug column next to several `glimmer` pockets, distinct from
both plain rock and dug space) and `154-reveal-density-sparse.png`/`154-reveal-density-dense.png` (the
density contrast between the two test sites). Fulfils this list's own "the first generated shaft"
candidate — real `ShaftGenerator` output, not a hand-authored fixture. Captured via
`tests/body/reveal_scene.gd`'s agent mode, not literal `--play` (no human at a keyboard was available to
this session); the renderer code (`_draw()`) is identical regardless of input source, so the pixels are
representative of what `--play` mode would show, but this is a real gap from the director's explicit
"from --play, not agent mode" ask, stated plainly rather than glossed over.

**154's pair was replaced same-round, not kept alongside its first draft (D0121).** The original capture
followed the body at zoom 6.0, which shows only ~28% of the topsoil band's own vertical extent in one
frame — a small, noisy local sample, not a view of the aggregate ~4x count difference
`test_shaft_generator.gd` actually measures (dense=312/sparse=78 glimmer cells, same seed). The director
caught this directly ("the three frames look nearly identical... confirm the density range actually
produces a visible difference"). Fixed by a capture-mode change (`reveal_scene.gd`'s new `--wide-view`),
not a parameter change — the real density difference was already strong; only the crop was narrow. The
two images at this path are the corrected wide-view pair; the original narrow-crop pair was overwritten,
not kept as a fourth/fifth image, since it was this session's own same-round first draft, not a
pre-existing curated asset.

**Policy set 2026-08-25; STILL not applied as of 2026-08-28.** This directory holds 168 images (165
pre-pivot plus this round's 3), still a diary, not the capped-12 argument this policy describes. Culling
is a real, judgment-heavy curation decision (which of 165 pre-pivot images, if any, still illustrate a
finding that survives the pivot) and a potentially destructive one at this scale, so it remains
deliberately undone. `docs/DECISIONS.md`'s locked "never destroy a curated file" rule exists because 84
screenshots were once permanently lost during a refactor — this policy does not override that; excluding
a file from the 12 and removing it from disk remain different operations. **This round's 3 additions
were made without a swap-one-out under the stated cap, since the cap isn't actually being enforced yet**
— flagged here rather than either silently violating the policy's letter or unilaterally executing the
165-image cull, which is not this session's call to make. Flagged for the director rather than decided
here.
