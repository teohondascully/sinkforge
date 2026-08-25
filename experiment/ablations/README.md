# experiment/ablations

## Purpose

Change one `data/` value, re-run the corpus, diff every metric. This is
how a balance change gets evaluated before it ships — not "does this feel
better" in isolation, but "what did changing this one number move, across
everything the harness measures."

## Dependencies

`harness` (drives the corpus via `harness/driver`, reads results via
`harness/aggregate`). Reads `data/` to know what it's varying. Not `sim`
directly (see `experiment/README.md`).

## Consumers

`experiment/claims_runner` (an ablation result can inform a claim's
verdict), whoever is proposing a balance change.

## Public API

None yet. This directory is a skeleton — no code has been written.

## Gotchas

None yet.
