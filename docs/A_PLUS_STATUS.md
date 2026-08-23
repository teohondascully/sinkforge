# Engineering programme — status

A bounded quality programme run over this repository before further feature work. Six areas, fixed order,
no new gameplay until it exits. This file is the current disposition; an area is CLOSED only where the
evidence is named, and a partial area is stated as partial rather than rounded up.

| Area | State | Evidence |
|---|---|---|
| 1. Reliability and safety | **Closed** | save isolation, durable save transactions, explicit migration and version semantics, and honest PASS / FAIL / SKIP behaviour throughout. Audited and found substantially already met. |
| 2. Architecture | **Partial, open** | `hud.gd`'s boundaries are mapped and `world_renderer.gd` is measured, but nothing has been extracted yet. See below. |
| 3. Harness quality | **Closed** | seven sub-areas, each closed with evidence, including two where the first diagnosis was wrong and the record carries the correction rather than the conclusion. |
| 4. Performance and maintainability | **Open, in progress** | a formal pass found seven full-grid loops, one of which ran every frame. The bazaar cache is now verified by direct measurement. The frame-SLO contract is still open. |
| 5. Documentation and contributor readiness | **Done** | architecture docs reconciled with executable behaviour, contributor and release workflow written, repository map present, and layer-count drift is now gated by the registry so a stated total cannot rot. |
| 6. Public presentation | **Complete** | the README explains the engineering system and the test-surface ratio accurately, history and media are retained deliberately with clone guidance, and the repository is legible to a reviewer in their first ten minutes. |

## Area 2 — the seam measurement, and why the obvious candidate was rejected

`world_renderer.gd` is 4601 lines. Four candidate boundaries were measured rather than eyeballed, on three
axes: what the candidate would still need from its parent, how wide an interface the parent needs back,
and how much mutable state crosses the line.

| candidate | lines | outbound calls | inbound calls | vars read | vars written on BOTH sides |
|---|---|---|---|---|---|
| lighting / veil | 955 | 10 | 5 | 68 | 2 |
| machines | 642 | 1 | 4 | 10 | 0 |
| water | 307 | 1 | 3 | 4 | 0 |
| terrain bake | 498 | 2 | 9 | 12 | 1 |

**The largest and most contiguous block is the worst candidate.** Lighting and veil occupy nearly a
thousand unbroken lines, which is exactly what makes them look extractable. They read 68 of the file's
mutable variables and write two dirty-flags that the parent also writes. Moving them would relocate 955
lines and leave the coupling where it was: a smaller file and the same design. Rejected.

`machines` is the first extraction. One outbound call, and that call is a pure geometry helper; four entry
points; no variable written on both sides.

**The method note is the transferable part.** Counting calls alone would have ranked lighting second-best,
because ten outbound calls is not obviously fatal. Only the shared-state axis exposed it. A seam analysis
that counts calls and not state measures the shape of the code rather than the cost of moving it.

## Area 4 — the bazaar cache, verified rather than assumed

`_rescan_bazaars` is the only genuine full-grid walk left in the tree: 16384 origins, consulted every frame
through the minimap draw and the bazaar view, and invalidated by nine event-driven sites including each
drill tick. A dig therefore invalidates the cache and the next frame pays a rescan, which is the shape the
original stutter had.

The source proved its own repair with a frame-level ceiling. That is the right evidence for "is the stutter
gone" and the wrong evidence for "what does one rescan cost", because a ceiling bounds the rescan without
measuring it. Measured directly, headless, 40 samples, invalidating before each:

    rescan   min 2.69   p25 2.72   median 2.74   mean 2.75   p95 2.82   max 2.86   ms
    cached   median 0.000                                              ratio ~27000x

The cached row is a control travelling inside the same run. If the two came back alike the timer would be
measuring call overhead and neither number would mean anything; they separate by four orders of magnitude.
The spread is 0.17 ms across 40 samples, so this is a stable cost rather than a sampled one.

No defect: the cache is correct and the repair holds at roughly six times. A dig costs a third of a 120fps
frame rather than two whole ones.

## Exit condition

All six areas closed, the full suite green on `main`, and every remaining stand-down carrying a written
reason. No new gameplay work begins until then.
