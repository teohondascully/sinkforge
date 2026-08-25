Lints, validators, and report generators — the tooling that enforces `docs/QUALITY.md`'s gates and
turns run artifacts into readable output. Not game code, not the harness that runs scenarios
(`harness/`) — this is static analysis over the repository and post-hoc reporting over what the
harness already produced.

- `layer_lint/` — the structural gates: layer dependency direction, no-engine-imports, file/function
  size limits, the instrument-to-game LOC ratio, claim-reference checking. See `docs/QUALITY.md`
  gates 1-7, 15-16.
- `schema_validator/` — validates `data/` against per-kind schemas. `docs/QUALITY.md` gate 13.
- `report/` — turns run artifacts (`telemetry.jsonl`, `result.json`) into human-readable output.
  Empty until `harness/driver` produces something to report on.
- `scratch/` — gitignored. Scratch work lives here and only here. If a script here turns out to be
  worth keeping, it becomes a real tool with a claim ID and moves out.

`tools/check_trailers.sh` (commit-authorship enforcement) also lives at this top level rather than
under a subdirectory — it's general git hygiene with no sim/game coupling, ported forward unchanged
from the pre-pivot `tools/` rather than archived with the rest of it.

Counts toward the instrument side of the LOC ratio (`docs/QUALITY.md` gate 7), except `scratch/`.
