Narrow, fast tests, one behavior at a time. Mirrors `core/` and `sim/`'s module structure — a test
file per module, testing that module's public interface only (no cross-module reach-in).

**Unused as of 2026-08-29 (queue #3 Part M2): no test file lives in this directory.** The real suite is flat under `tests/`; see `tests/README.md`.
