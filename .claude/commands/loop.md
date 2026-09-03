Drive the queue in `docs/WORKING.md` under "## Overnight queue" to exhaustion.

**THE RULE THIS COMMAND EXISTS TO ENFORCE: a parked decision pauses a LANE, never the RUN.**

Two runs stalled on this. The first hit one ruling (P020) and halted with 8 commits. The second finished
a unit, reported to the director, and treated the report as a terminus — same failure, different costume.
**Reporting is not stopping.** After you report, take the next item.

## Every iteration

1. Read `CLAUDE.md` and `docs/WORKING.md`. Verify repo state matches what `docs/WORKING.md` claims.
   State in one line which lane and item you are on. (Every iteration, not once — this is what makes the
   loop survive a compaction mid-run.)
2. Read the queue. Take the first unchecked **DECISION-FREE** item, from any lane.
3. Do it. Port-and-refactor per `docs/archive/MASTER_PLAN_AUG30.md` §0 (archived 2026-09-03; the rule now lives in `docs/A_PRIME_REFACTOR_PLAN.md` §1) — never rewrite what legacy solved. Name
   the legacy source you lifted from.
4. Run the gates for what you touched (`tools/select_suites.py` picks the suites; the full sweep before
   push). A red you cannot clear in one attempt: revert that item, log it, **take the next item** — do
   not stop.
5. Commit, ledger entry per judgment call, merge to main through a passing PR.
6. Check the item off. Go to 1.

## When you hit something that needs a ruling

Do **not** stop. In order:

1. Write it to `docs/NEEDS_DIRECTOR.md` with the measurement behind it and a recommendation.
2. Ask whether it is a **ROOT blocker** — does it gate the whole lane, or only this item? P022 gated
   *every* sprite, because each one hit the same clearance wall. That is a root blocker.
   - Only this item → mark it, take the next item **in the same lane**.
   - Root blocker → mark the **whole lane** BLOCKED-ON-DIRECTOR and move to a different lane entirely.
3. Keep going. Rulings **accumulate into a batch**; they do not each halt the run.
4. The director is usually awake. When a batch has formed, surface all of it **at once** so it can be
   ruled in a single pass — never one ruling at a time.

## Lane order

Decision-free lanes first, because they carry the run: **C** sprites, **F** HUD/UI, **G** audio,
**A** camera/framing, **D** harness. Decision-heavy last: **B** world-gen constants, the economy.

Even a decision-heavy lane has decision-free parts — world-gen's atmosphere rendering is view-side and
runs while its calibration sits parked. A blocked sub-item does not block its lane's other work.

## STOP THE RUN — and this list is the whole of it

- **A determinism two-process replay divergence.** The one corrupting failure. Pause everything, make it
  the sole priority.
- **Decision-free work genuinely exhausted across ALL lanes** — not one lane, all of them. Then surface
  every parked ruling in one batch and report.
- **The run's time budget.**

Nothing else stops the run. Not a parked ruling. Not a gate-7 block. Not a resolver touch. Not a taste
call. Not finishing a unit. Not having something to report.

## Not stop conditions, but still rules

- An EXPENSIVE decision (threshold move, resolver touch, resolution split, heightfield contract) is
  **parked, not decided in-loop** — and parking it is a two-line action, after which you continue.
- Never bypass a gate. Park the PR and take the next item.
- A feel/look item is **BUILT-PARKED with a capture**, never "done". Then continue.

Run `/wrap` when the run actually stops, per the three conditions above.
