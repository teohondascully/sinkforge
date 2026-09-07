# Tests

Status: current layout, 2026-09-07.

Most Godot suites are flat `tests/test_*.gd` files. `tests/body/` contains scenes, support code,
recorded inputs, saves, and local captures. The `unit/`, `property/`, `scenario/`, and `golden/`
README-only directories are historical scaffolding, not the current test taxonomy.

Use the commands in [CONTRIBUTING.md](../CONTRIBUTING.md).
The [CI workflow](../.github/workflows/harness.yml) is the source of suite membership;
`tools/list_ci_suites.py` selects the per-commit tests job, excluding scheduled fuzz work.
Do not infer coverage from a directory count or a passing subset.

Representative suites:
- `test_items.gd`: item behavior and conservation.
- `test_water_flow.gd`: fluid behavior and conservation.
- `test_save_game.gd`: persistence.
- `test_shaft_replay_determinism.gd`: seeded replay and golden comparisons.
- `test_tutorial_playthrough.gd`: scripted opening through the interface.

The [backlog](../docs/BACKLOG.md) tracks future organization by component.
Moves must preserve suite discovery, fixture references, and UIDs.
[Evidence policy](../docs/EVIDENCE.md) distinguishes required fixtures from local run artifacts.
