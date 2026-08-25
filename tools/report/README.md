Empty. Turns run artifacts (`telemetry.jsonl`, `result.json` — see `docs/ARCHITECTURE.md` §6, driver
outputs) into human-readable reports. Nothing to build here until `harness/driver` produces real
artifacts to report on (`docs/ONBOARDING.md` stage 7).

Exempt from `docs/QUALITY.md` gate 15 (every harness layer names a claim) per `docs/adr/0001` — report
and visualization tooling serves the whole corpus and defends no single claim. That exemption must be
stated explicitly per file (`# claim: EXEMPT (ADR-0001)`), not assumed silently.
