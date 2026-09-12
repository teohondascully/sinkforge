# harness/driver

## Purpose

Headless boot, tick loop, budget enforcement. Loads a `harness/scenario`
fixture, boots the sim through `interface` with no GPU and no window, runs
it under a bot from `harness/bots` filtered through a `harness/envelope`,
and enforces the scenario's budget (tick/time limit).

## Must-not

- Require a GPU or a window. Must run headless, in CI, at 100x realtime or
  better for a short (few-thousand-tick) scenario. This is a hard performance constraint:
  if the fast loop can't finish in under 60 seconds total across its
  scenarios, something here is too slow, not the CI budget too tight.

## Dependencies

`interface`, `sim`, `core`, `harness/scenario`, `harness/envelope`,
`harness/bots`.

## Consumers

`experiment/claims_runner`, `experiment/sweeps`, `experiment/ablations`,
`experiment/calibration` — everything in `experiment/` ultimately runs
scenarios through this driver. CI (the fast loop, directly).

## Outputs

Per run: `result.json`, `telemetry.jsonl`, `state_hashes.txt`, `input.log`,
`report.md`, `heatmap.png`.

## Public API

`ScenarioDriver.run(record: Dictionary) -> Dictionary` — consumes a `ScenarioRecords` entry
(generated from `scenarios/*.yaml`), boots the named site/start/seed through `WorldSeeder`, hands
the run to the bot `record.agent` names, and returns `{ok, reason, ticks_used, goal_event, legs_ok,
conservation_error, envelope}`. The envelope field names what was ACTUALLY used -- a record asking
for `constrained` runs oracle today and the report says so.

## Gotchas

None yet.
