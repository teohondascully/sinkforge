# Evidence and artifact retention

Status: current documentation policy, 2026-09-07. This pass authorizes no evidence deletion.

| Class | Examples | Treatment |
| --- | --- | --- |
| Required regression input | Recorded commands, compatibility saves, small deterministic fixtures | Track with tests; preserve provenance and expected outcome |
| Curated historical evidence | Milestone images, decisive failure receipts, published reports | Preserve at stable paths or migrate with a verified manifest |
| Routine run output | Repeated captures, temporary logs, local sessions | Keep outside ordinary source browsing; use existing ignored output locations |

A local directory's disk size is not its tracked Git size.
Deleting a tracked file from HEAD does not remove it from Git history.
Unique screenshots cannot necessarily be regenerated from a current build.
Do not apply lossy compression to pixels used as measurement evidence.

Before any future artifact migration, inventory tracked and untracked content separately,
identify consumers, preserve a retrievable archive with hashes, and update report links.
Retention must preserve the build, seed, input sequence, settings, platform, and relevant receipts.
A deterministic checkpoint recipe can replace a large convenience snapshot only when regeneration
and reload fidelity have been tested; compatibility-test snapshots have a different purpose.

The ledger and historical captures remain in place. The cleanup snapshot under
`docs/archive/cleanup-2026-09-07/` preserves the operational documents replaced by this pass.
