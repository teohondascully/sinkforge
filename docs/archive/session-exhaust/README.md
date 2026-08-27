# Session exhaust

Raw session and coordination output from the pre-pivot multi-session process: `tracelog/` (session
transcripts, blind-eval logs, an overnight queue dump, `sweeps/`) and `handoff/` (lane briefs, overnight
run states, cutover patches, audit responses, release receipts).

**Archived, not deleted, because it was assessed at directory level rather than read.** Untracked and
excluded via `.git/info/exclude` since before the 2026-08-25 pivot. Closing that exclusion hole (ANVIL
step 1, 2026-08-27) required a real disposition, and this one is deliberately the cheap, honest one:
every synthesis that came out of this raw material and matters going forward is already tracked
elsewhere (`docs/archive/COMPAT_AUDIT_2026-08-25.md`, `docs/archive/PIVOT_PLAN_2026-08-25.md`,
`docs/archive/MATERIAL_SPINE.md`, and the rest of `docs/archive/`), but nobody had read all ~3,000 files
here individually, and deleting untracked content is not a decision that can be undone.

**Two files were read specifically before this archive landed**, because they were flagged as plausibly
holding reasoning not present anywhere in the tracked syntheses:

- `handoff/CONVERGENCE_LEDGER.md` — git/worktree hygiene record, 2026-08-23. Documents a deliberate,
  reasoned decision to keep `tools/director_bus.sh` and `tools/test_director_bus.sh` **untracked** even
  though they are real, working, authored code — session-coordination tooling kept out of a public
  portfolio repository on purpose. This directly informed a decision made the same day this README was
  written: `legacy/tools/director_bus.sh` and `legacy/tools/test_director_bus.sh` stay untracked, against
  the plan's initial default of "complete the `legacy/` freeze." See `.gitignore`'s own note near those
  two paths.
- `handoff/FREIGHT_WINCH_ECONOMIC_ENVELOPE.md`, `handoff/FREIGHT_WINCH_GRAYBOX_PLAN.md`,
  `handoff/Q1_FREIGHT_WINCH_PAIN_OPTIONS.md` — real engineering design for the pre-pivot long-distance
  haul machine, not superseded by anything tracked. `docs/GDD.md` §9 already names this mechanism ("a
  throttled per-trip capacity plus a fixed transit duration linking two arbitrary cells") as the closest
  existing analog to R1's shaft-to-surface haul. The route-scoped transit model (a route owns in-flight
  cargo state and bypasses the normal per-tick flow step entirely, rather than the machine owning it), the
  dangling-reference/cargo-preservation policy (fail closed at the route level, never destroy cargo, cross-
  check against the rebuilt machine set after load), and the conservation-by-construction discipline
  throughout are not duplicated in any tracked document and are worth reading directly if R1's haul
  mechanism is ever built against this precedent.

Everything else here was classified by filename, date, and size, not read file-by-file — stated plainly
per the same discipline this project applies to any coverage claim. `CAPTURE_MANIFEST.md`-adjacent binary
or generated content, if any turns up here later, was not specifically checked for.

If this later proves genuinely worthless, deleting tracked files is a normal commit with a normal diff.
Deleting it while untracked would have been an event, not a decision — this move is what makes it the
former.
