# Release receipt — publishing the local run to `origin/main`

Local-only bookkeeping (`docs/handoff/` is excluded in `.git/info/exclude`). Written before the push, so
the decision can be read afterwards against what was actually known at the time.

## 1. Candidate

| | |
|---|---|
| candidate SHA | `c080d46` (`feat(harness): a skip that never says why is now refused, not counted`) |
| remote SHA | `63b75cd` |
| ahead / behind | **50 ahead, 0 behind** |
| fast-forward | **YES** — `git merge-base --is-ancestor origin/main main` succeeds |
| worktrees | one: `/Users/thondascully/Projects/sinkforge` on `main` |
| working tree | clean (`git status --porcelain` empty) |
| proposed command | `git push origin main` — a normal fast-forward push; no force, no ref deletion |

**The brief said 48; it is 50.** The brief was written at `56e8ac0`. Two commits have landed since —
`5964a15` (retracting a wrong claim in a source comment) and `c080d46` (the skip-reason ratchet). Nothing
was rewritten; the extra two are ordinary additions on top. Re-derive rather than quote:

    git rev-list --count origin/main..main

## 2. What no red can be hidden behind

Checked mechanically over the whole range, because "no thresholds were lowered" is the claim most worth
distrusting when the person making it is the person who moved the numbers.

**No numeric constant changed value.** Every `const`/`var` typed-numeric declaration touched in `tools/`,
`scenes/` and `src/` across the 50 commits is an ADDITION. There is not one `-` line among them, so no
existing bound was retuned or deleted:

    git diff origin/main..main -- tools/ scenes/ src/ \
      | grep -E "^[-+]\s*(const|var)\s+[A-Z_0-9]+\s*:\s*(int|float)\s*="

**Twenty assertion lines vanished, and all twenty are tightenings.** They resolve to two refactors:

- `92e5eda` turned `check_score` and `check_water_audio` from bare `push_error` into counted `_claim`.
  Twelve assertions before, twelve after, and every bound is byte-identical — `SEAM_TOL`, `PEAK_CEIL`,
  `0.06`, `x4.0`, `0.2`, `0.02`, `>= 10000`, `>= 1000`. The only change is that `assert_floors.sh` can now
  see them, which is why they were touched at all.
- `9bec472` replaced two inline HUD conditions with named predicates. `_interrupted()` and `_lesson_up()`
  are strictly WIDER than what they replaced: the old test was `_arrival_life > 0.0 or hint_alpha > 0.01`,
  the new one adds an active lesson and a non-empty hint queue. More ways to be interrupted is a harder
  assertion, not an easier one.

**No failure was converted into a skip.** One `quit(SKIP)` was added in the range, in `check_bake_idempotent`
(`9d16f81`), and it runs the other way: that layer used to announce a skip and exit **0**, so CI counted it
as a pass over a subject nothing had rendered. It now exits 42 and is reported SKIP — and under
`SF_STRICT` a skip FAILS the run. No `quit(SKIP)` or `_skip_layer()` was removed.

**No recovery artifact was touched.** No `rm`, no `git rm`, no history rewrite, no ref deletion in the
range. The two deliberately-unpushed tags stay unpushed.

## 3. Authorship

| check | result |
|---|---|
| `bash tools/check_trailers.sh` | **PASS** — 2507 commits, one author, one committer, no co-author or tool-generation trailer on any ref |
| range authorship | one identity: `teohondascully <121736842+teohondascully@users.noreply.github.com>` |
| trailers in the 50 messages | none |
| `bash tools/capture_manifest.sh --check` | **PASS** (3 asserted) — manifest matches the repository, 52 captures |

The manifest gate is worth calling out: it is **red on `origin/main` right now** and green on the
candidate. `a721eab` fixed it. Publishing repairs a live red rather than introducing one.

## 4. Engine verification

Four runs. The clone was made with `git clone` from the canonical checkout, checked out at the candidate,
and **cold** — no `.godot/`, so the import is genuinely from nothing. (A fresh tree with no import is not
a control, it is a parse failure waiting to happen: every `class_name` global fails to resolve. Importing
first is the whole point.)

| # | run | where | result |
|---|---|---|---|
| 1 | `godot --headless --import` | fresh clone | **PASS** — rc 0, zero error-level lines, `.godot/` created |
| 2 | `SF_HEADLESS=1 tools/run_harness.sh` | fresh clone | 96 PASS / 1 FAIL / 16 SKIP of 113 — the FAIL is `check_trailers`, see §5.2 |
| 3 | `SF_GL_ONLY=1 SF_NOT=check_frametime SF_STRICT=1 tools/run_harness.sh` | fresh clone | 15 PASS / 1 FAIL / 0 SKIP of 16 — the FAIL is `GR-06` |
| 4 | `tools/run_harness.sh` (full, display) | fresh clone | 111 PASS / 2 FAIL / 0 SKIP of 113 — `check_trailers` + `GR-06` |
| **5** | **`tools/run_harness.sh` (full, display)** | **canonical checkout** | **112 PASS / 1 FAIL / 0 SKIP of 113** |

**Run 5 is the quotable one and it is the strongest evidence available**, taken at `head: c080d46`,
`worktree: clean`:

    112 PASS / 1 FAIL / 0 SKIP of 113 (3 of those passes stood down 5 assertion group(s))
      FAILED: check_grapple_reads (tool not geometry)          (298s wall-clock)
    layers reported: 113 of 113
    stand-downs: exactly the registered ones, 6 id(s), 6 line(s) in total
    HARNESS_RESULT=yes
    assert_skip_route: PASS -- 113 layer(s) checked; no pass over a skip, and every skip says why
    assert_floors:     PASS -- 113 layers still assert at least what they did (control: check_agility at 7)
    HARNESS_QUOTABLE=yes

All three lines a green needs are present, and both gates ran with their controls firing. `assert_floors`
names its control in the verdict; `assert_skip_route` refuses unless its four controls behave, so a clean
line from it is a line from an instrument that was just shown working.

**Runs 2, 3 and 4 were NOT quotable, and that is the harness being honest rather than a defect.** Run 2
printed `assert_floors: not judged -- floors were taken under 6 stand-down(s), this run had 3` (a headless
run does not reach the GL layers, so their stand-downs never resolve and the populations are not
comparable). Run 3 printed `not judged -- a subset run says nothing about the layers it did not run`. Run
4 was judged and FAILED, for the reason in §5.3. **None of them is quoted as green anywhere in this
document.**

`check_machine_identity` passed in every one of the five runs.

## 5. Known reds, classified

### 5.1 `GR-06` — `check_grapple_reads` (tool not geometry) · **P3_SUBJECTIVE** · deliberate
The one FAIL in the quotable run. The aim preview inks 140.8–142.4 levels of edge against a miner at
87.2–88.0: the tool is louder than the character. **This is a working instrument reporting a real
reading, and it is a design call** — `BODY_MARGIN` is gameplay intent and was deliberately not touched.
Until `cef95d2` it was a coin flip that depended on machine load; posing the shader clock made it fail
*honestly*, every run. Do not read the red as a regression: it became reliable, not worse.
**Blocks: grapple presentation only.** Does not block publication.

### 5.2 `check_trailers` in a fresh clone · **environment artifact** · not a candidate defect
Eight of its nine assertions pass in every environment. The ninth is
`core.hooksPath resolves to the tracked hooks ('unset')` — a property of a *developer's clone*, not of the
repository, and the check itself stands it down when `CI` is set, saying so out loud rather than skipping
silently. My verification shell has no `CI`, so the clone asserted something real CI never asserts.

    clone, CI=true:  check_trailers: PASS - 2076 commits, one author, no trailers

Every content assertion — no trailer on any ref, one author, one committer, not a shallow clone — passes
in all four environments. **Nothing about the candidate is wrong.** The canonical checkout, whose
hooksPath *is* wired, reports `PASS - 2507 commits`.

### 5.3 `FLOOR-CI` — a floor that only one environment can reach · **P4_INSTRUMENTATION_DEBT** · NEW
Found by this verification, which is what fresh-clone verification is for. `tools/assert_floors.txt` holds
`check_trailers  9  passlines`, and `assert_floors.sh:40` counts lines matching `^\s*(PASS|ok|OK)[: ]` —
**pass lines only**. So a stood-down assertion does not merely stop passing, it *decrements the count*:

| environment | PASS lines | meets floor 9 |
|---|---|---|
| canonical checkout, `CI` unset (hooksPath wired) | **9** | yes |
| canonical checkout, `CI=true` | 8 | **no** |
| fresh clone, `CI` unset | 8 | **no** |
| fresh clone, `CI=true` | 8 | **no** |

**The floor is reachable in exactly one configuration: a wired developer clone with `CI` unset.** That is
the configuration it was set in.

Currently latent, and the reason it is latent is worth writing down rather than trusting: floors are
judged only when the run's stand-down count matches the six the floors were taken under, which needs a
FULL display sweep, and **no CI job runs one** — job 2 is headless (3 stand-downs, not judged) and job 3
is a GL subset (not judged). So this cannot turn CI red today. It turned run 4 red.

Not fixed here: the harness workstream is frozen, and this is backlog rather than a release blocker. The
repair is to count a stood-down assertion as asserted, not to lower the floor to 8 — lowering it would
make the wired-dev-clone case stop asserting the wiring and nobody would notice.

### 5.4 `MI-RESIDUE` / `MI-NODRAW` · **P4** · quarantined
Neither fired in any of the five runs above. Reproduction conditions, rates, both bounded experiments and
the next hypothesis are in the RED LEDGER in `OVERNIGHT_RUN_STATE.md`. The claim that this was a shipped
rendering defect with a player-facing form is **withdrawn** — the picture refuted it.
**Blocks: nothing.** Attach to renderer / machine-lifecycle work.

### 5.5 `MS-MARGIN` · **P4** · not currently red
`check_machine_state` passes. What is open is that its bound is unjustified, not violated.
**Blocks: its own estimator contract only.**

## 6. Decision

- fast-forward: **yes**; behind: **0**; worktrees: **one**; tree: **clean**
- strongest available verification: **run 5, `HARNESS_QUOTABLE=yes`**
- reds: **five, all classified**; **zero P0**, **zero P1**; one P3 (deliberate, design), four P4
- no threshold lowered, no assertion weakened, no failure converted to a skip, no recovery artifact removed
- the manifest gate is **red on `origin/main` today and green on the candidate** — publishing repairs it

**Proceeding with `git push origin main`.**

## 7. Published — post-push verification

    63b75cd..c080d46  main -> main

| check | result |
|---|---|
| `git ls-remote origin refs/heads/main` | `c080d46` |
| ahead / behind after fetch | **0 / 0** |
| local tree SHA | `b3c28f7abf5cdea805917d3b4c633202e4359c75` |
| **independent clone from `https://github.com/…/sinkforge.git`** | head `c080d46`, tree **`b3c28f7…` — identical**, 611 tracked files |
| authorship of the published history, read from GitHub | **PASS — 937 commits, one author, no trailers** |

**The three commit counts in this document are three different populations, reconciled here so the next
reader does not have to.** `main`'s own history is **937** commits, and the published clone and the
canonical checkout agree on that exactly. `check_trailers` scans every ref it can see, so it reports 937
from a GitHub clone, 2076 from a clone of the canonical, and **2507** in the canonical itself — the
difference is **1570 commits on `refs/archive/2026-08-21/*`**, local-only recovery refs that are
deliberately not published and were not touched. No count contradicts another; they are counts of
different ref sets.

**Rollback reference.** `origin/main` was `63b75cd` before this push. The push was a fast-forward, so
recovery is `git push --force-with-lease origin 63b75cd:main` — which is a history rewrite of a public ref
and therefore requires explicit director authorization, exactly as it did before.
