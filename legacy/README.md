# legacy/

The pre-pivot codebase: a persistent-world factory game, before Sinkforge became a
run-based roguelite and measurement instrument. Tagged in full at `pre-pivot`
(`git checkout pre-pivot` to see the repository exactly as it stood before this
directory existed).

**Read-only.** Nothing in here is on the build path, in the Godot import scan
(`legacy/.gdignore`), or subject to any lint or gate in `docs/QUALITY.md` — those
rules were never this code's contract and applying them retroactively would just be
noise. `git log` for anything under here should show a flat line from the day it
moved, not new work.

**Why it's kept, not deleted.** Two independent audits found roughly 72% of the
prior codebase's subsystems structurally compatible with the new architecture, with
zero dependency cycles across the whole `.gd` graph (`docs/archive/COMPAT_AUDIT_2026-08-25.md`).
Most of what's in here is worth porting, not rewriting from a blank file. Deleting it
to start clean would throw that away and would read, correctly, as a panic rewrite.

**How porting works.** Files leave here one at a time, each in a commit that names
the original path here and states what changed and why — never moved unchanged
just because it worked; it has to fit the new layer boundaries, size limits, and
naming conventions, or it stays. See `docs/ONBOARDING.md`'s stage-by-stage sequence
and `docs/archive/COMPAT_AUDIT_2026-08-25.md` for the per-subsystem compatibility
scores driving what ports early versus what needs real redesign.

## Layout

Preserves the pre-pivot structure exactly:

```
legacy/src/       core simulation and data-definition code
legacy/scenes/     Godot scenes and their attached scripts
legacy/tools/      the prior harness: 108 registered check layers, capture tooling,
                   repo-hygiene scripts (a few of which — e.g. commit-trailer
                   checking — are general enough to have ported forward unchanged;
                   see the new tools/ for those)
legacy/tests/      the prior test suite
legacy/assets/     sprite sources and other binary content
```
