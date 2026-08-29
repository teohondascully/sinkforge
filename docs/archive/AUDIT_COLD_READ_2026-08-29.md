> **EXTERNAL AUDIT, 2026-08-29.** Read-only, cold-read: a fresh model with no project history, every
> number measured from the tree rather than quoted from prior docs. Pinned at commit `d54a676` (docs at
> `d4d1b62`); the tree kept moving during the audit (`8f6d540`, `b71d6e9` landed from a second session in
> the same checkout). Saved here verbatim, as received, for provenance — this is the source document
> behind `docs/DECISIONS_LEDGER.md` D0142–D0145 (the audit-response Phase 1 work: the duplication-gate
> fix, `tools/gate_status.py`, and the armed LOC-ratio gate). Two documents, pasted together as received:
> Part A is the audit itself ("Sinkforge Cold Read"); Part B is a separate, longer-horizon remediation
> plan ("Sinkforge Unbandaged") that responds to Part A's findings. Nothing in Part B has been built as of
> this file's creation except where D0142–D0145 explicitly say so — Part B states its own status plainly:
> "Everything on this page is a recommendation; nothing was changed in the repository."

---

# Part A — Sinkforge Cold Read

*Independent read-only audit · two briefs, one tree*

A game (one movement controller, one terrain generator) and an event-sourced development substrate built
to keep declared state honest. Read cold, from the tree, with every number measured rather than quoted.
Part I answers the deep-analysis brief; Part II is the staff-engineer impression audit. Judgment is kept
separable from measurement throughout: **measured** means a number the auditor produced; **judged** means
their read of it.

**Pin.** Code and gates at `d54a676` (2026-08-29 02:09 −07:00). Docs at `d4d1b62` (+58 lines WORKING.md).
Tree kept moving: `8f6d540` (02:54) and `b71d6e9` (03:07) landed from a second session in this same
checkout. CI on pinned HEAD: **failure**.

## Contents

**I · Deep read** — Headline · Measured map · Quality findings · Drift and rot · Scaffolding judgment ·
Game reality · Not assessed · Where the brief is wrong
**II · Staff-engineer read** — The bar · Eight categories · The two questions · Honest verdict
**Appendix** — Method and sources

## 1 · Headline

Is the project healthy? The code that exists is careful and, when I probed it directly, deterministic —
but the project as a system is not healthy, because its declared state runs ahead of its real state in
exactly the two places it says it fears most: the brief committed at HEAD reports every gate passing
while CI on that same commit is red, and the health metric the whole rebuild was organised around
(instrument LOC vs game LOC) is enforced by a script that has never once been able to fail. Is the
scaffolding sound? Half of it: the habit of writing things down, and correcting them in specifics, is
real and verified; the enforcement half is thinner than its documentation — 11 of 29 numbered gates have
no code, the four most-cited gates pass with an empty subject, and the gates' own 50 mutation tests run
nowhere. Is it proportionate to the game? No: 6.26 instrument lines per game line by the project's own
definition, 62% of ledger entries about process rather than game or sim, and the instrument has never
measured a design claim (four claims, zero proven, zero recorded human sessions). Would I trust its
green? Only the Godot test job, and only for what it actually runs; anything labelled "gate N" needs the
script read before the label is believed. What bites next? The fuzz sweep the project has spent seventeen
ledger entries interpreting is measuring a chamber that a thousand random walkers have progressively
demolished — its counts are a property of seed order, not of the collision resolver, and the next bound
that moves will be misattributed to `sim/body` again.

| CI at pinned HEAD | Ratio, gate definition | Gates with code | Claims proven | Real sim determinism | Playable today |
|---|---|---|---|---|---|
| **Red** — blocking duplication gate; BRIEF says all PASS | **6.26 : 1** — project quotes ~5.7; trajectory 2.9 → 6.3 in four days | **18 / 29** — of those, 4 pass on an empty subject | **0 / 4** — nothing has been measured by the instrument yet | **Holds** — probed directly; the harness tests a stub | **Walk, jump, dig** — two debug scenes; no items, machines, water, rig |

## 2 · The measured map

**measured** Method: `git ls-tree -r d54a676` for population, `git show` piped to `wc -l` for lines (so the
dirty working tree and a stray probe file another auditor dropped into the scratch snapshot are
excluded). "Code" means `.gd`/`.py`/`.sh`, the same set the project's own ratio script counts. `.uid`,
`.import`, and images are excluded everywhere.

| Area | Files | Lines | What it actually is |
|---|---|---|---|
| `core/` | 4 | 300 | Fixed-point, SplitMix64 RNG, generational IDs, bit ops. Real, tested. |
| `sim/` | 11 | 1,337 | 4 of 14 module directories have code: body (5 files), world (2), terrain_gen (3), invariants (1). The other 10 are a MODULE.md each. |
| `data/` | 2 + 10 yaml | 262 + 297 | Generated material/strata records plus their YAML source. Not counted by the ratio script on either side. |
| `interface/ view/ shell/ harness/ experiment/ scenarios/` | 0 | 0 | README/MODULE.md only. L2–L4 of the architecture do not exist. |
| `tests/` | 43 | 4,542 | 22 suites (~3,000 lines) + fixtures, two debug scenes, a control-plane slice, property checks. |
| `tools/` | 34 | 5,699 | layer_lint 1,190 + 112 test · quality_check 990 + 404 · economy_check 566 + 500 · anvil 467 + 420 · schema_validator 122 · data_codegen 193 · top-level scripts 735. |
| `.githooks/` + CI yaml | 3 | 161 + 309 | Not counted by the ratio script; instrument in substance. |
| Live docs (`.md`, non-archive) | — | 17,352 | Ledger 5,392 · A_PLUS_STATUS 1,841 · WORKING 1,102 · VISUAL_TRIAGE 703 · DECISIONS 574 · CONTENT_CATALOG_PLAN 562 · ARCHITECTURE 523 · EXPERIENCE_EVALUATION 395 · GDD 343. |
| `legacy/` | 359 (187 .gd) | 74,436 | The pre-pivot codebase, frozen, 7.3 MB. Excluded from every gate. |
| `docs/archive/` | 2,994 | — | 216 MB; 2,742 are per-layer harness stdout logs (7.9 MB); 88 PNGs are 207 MB of it. |
| `history/` | 168 png | — | 229 MB. Three documents say "capped at 12". |
| `.anvil/log/` | 13 events | 232 | 11 FINDING, 2 DECISION, all hand-appended by sessions; one reference in the whole log. |

### The ratio, recomputed

**measured** By the gate's own definition (`tools/layer_lint/check_loc_ratio.py:52-55`:
harness+experiment+tools+tests over core+sim+interface+view+shell, `.gd`/`.py`/`.sh`): 10,241 / 1,637 =
6.26 at `d54a676`. The "~5.7" in the brief is a stale reading — 5.569 appears in a BRIEF from 2026-08-28.
The trajectory across BRIEF/WORKING history is monotone: 2.896 → 3.564 → 4.347 → 4.507 → 4.652 → 5.362 →
5.440 → 5.569 → 5.430 → 6.26.

**judged** I agree with the number and disagree with the definition on three counts. It omits the hooks
and CI workflow (470 lines of instrument), it omits `data/` (559 lines of game content), and it omits the
17,000 lines of process prose that are the project's actual instrument — the ledger and working-state
documents are what the substrate is. Two honest alternates: counting hooks+CI as instrument and `data/` as
game gives 4.88; adding the ledger, WORKING, BRIEF, QUALITY, CLAIMS, CONTEXT and the slash commands (≈8,200
lines) to the instrument side gives ≈8.6. None of the three definitions is close to the 1.5 target
WORKING.md set on 2026-08-25.

### Layer split and boundaries

**measured** `core/` and `sim/` contain no Node classes, no engine services, no file IO, no delta, no
`randi`/`Time`/`OS`, no static mutable state, and no hash-map iteration on a state path (all 26 loops
enumerated). The lint enforces that and it holds. Three boundary facts the docs do not state: (1) `sim/`
depends on `data/` through the `class_name` globals `MaterialsRecords` (`sim/world/materials.gd:15`) and
`StrataRecords` (`sim/terrain_gen/strata_data.gd`) while `layer_lint.py:41` allows `sim → {core}` only — a
live layer violation the lint cannot see because it checks `res://` paths and found zero of them; (2)
`sim/world` has no `world.gd`, so by the lint's own "one interface file named after the module" rule every
use of `TileGrid` from `sim/body` is a sibling reach-in; (3) "engine-free" is a claim about Node classes,
not the runtime — every file is GDScript keyed on `Vector2i`, `Dictionary`, `StringName`, and its
determinism inherits Godot's int64 and IEEE-double semantics.

### The event log

**measured** Thirteen events at HEAD; two more appended untracked by the other session during the audit.
Every reference resolves (one exists). The schema the code enforces (`tools/anvil/schema.py`) diverges
from the schema the design describes in sixteen places — and the design document,
`incoming/ANVIL_ARCHITECTURE.md`, is gitignored (`.gitignore` ≈ line 212), so the log's authority is
absent from every clone. The one reader, `check_integrity.py`, runs in no CI step, hook, or command; its
own docstring (line 10) says "enforced in CI". Fed 43 malformed events in scratch, it accepted 28 that
should fail (a supersedes-the-future, a cycle, a timestamp that disagrees with its filename, a commit hash
of forty zeros, a CONTENT_LINK to `/etc/hosts`) and crashed on 3. Over the same window the ledger gained
77 entries and the log gained 2 DECISION events. It is a substrate that sources nothing yet.

### Git history shape

**measured** 1,169 commits on main at the pin; 144 since the pre-pivot tag (2026-08-25), one author, no
merges. Of those 144, 64 (44%) touch only docs. Excluding one declared 167,880-line archive dump, lines
added since the pivot split game 13% / instrument 40% / docs 41%, and 72% of the non-archive doc lines
went to the ledger, WORKING and BRIEF. A seeded random sample of ten commits: 7 match their message
exactly, 3 partially (undeclared BRIEF/WORKING regeneration alongside; one "propose ADR" whose file says
accepted), 0 mismatch. The commit-msg ledger rule has had zero bypasses since it landed; the seven
core/sim commits without a ledger entry all predate it. The QUALITY.md story that `body.gd` sat at exactly
400 lines for three commits is exactly true.

## 3 · Quality findings

Verdict key: **verified** holds as claimed · **degraded** works but narrower than claimed · **broken**
does not do what it says · **vacuous** passes with no subject.

### Gate integrity

| Gate | Claim | Reality | Verdict |
|---|---|---|---|
| CI as a whole | BRIEF at `d54a676`: "All … gates PASS" | Run 33244834049 on that SHA failed on "Duplication … BLOCKING". So did the next two pushes. The BRIEF's enumerated list and `.claude/commands/wrap.md` step 7 both omit `duplication.py`, `check_base_namespace.sh` and `quality_check/*`; the session ran what the checklist named and reported honestly on a subset. Pushes go straight to main, so a red blocks nothing. | broken |
| 7 · LOC ratio | QUALITY.md: "Instrument LOC ≤ game LOC … Enforced in CI." CONTEXT.md: same. | `check_loc_ratio.py:60-64`: advisory (exit 0) while game LOC < 2,000; game LOC was 0 at the script's birth and at its 2,000-floor rewrite, and has peaked at 1,637. Right now it prints "Velocity check would FAIL but is not gating". The CI step is named "Instrument LOC must not exceed game LOC". | vacuous |
| 8 · Determinism | "`replay_determinism_test` green"; CI step "QUALITY gate 8" | `tests/test_replay_determinism.gd:21` replays a `TrivialStub` of particles; its docstring says the stub "is NOT sim/ and never will be". Deleting `sim/` leaves it green. A direct probe of the real Body+TileGrid+dig over 3,000 ticks, two processes, with a seed+1 control, was byte-identical — the property holds; the gate does not test it. | vacuous |
| 15/16 · Claim references | "The single most important process gate" | Population: 0 scenarios, 0 harness files, 0 proven claims. Citing a real claim ID today fails (none has `first_failed_at`). It has never had a subject and cannot currently admit one. | vacuous |
| 1 · Layer lint | "Dependency rules hold. Zero violations." | 15 files, 0 `res://` references checked; all cross-file coupling is `class_name`, which the docstring admits it cannot see. Live invisible violations: sim → data (above). A probe `core/probe.gd` returning `TileGrid.new()` passes. | vacuous |
| Duplication (blocking) | "0 clusters is this project's verified-clean state" | 2 clusters at HEAD (`tests/diag_resolve_floor.gd:26,33` copy `_spawn_body`/`_random_input` from the fuzz probe). Population is `.gd`+`.py`; `check_trailers.sh:31-38` and `test_run_gd_test.sh:32-39` are byte-identical and invisible. Copies under 4 lines or 15 tokens, or differing in one literal, pass. | broken |
| 28 · Masked-crash wrapper | `run_gd_test.sh` fails on any mid-suite runtime error | Reproduced: a suite that calls `Array.remove_at(99)` prints an engine `ERROR:`, continues, prints ALL PASS, wrapper exits 0. The wrapper matches only `SCRIPT ERROR:`, and its own negative control forbids matching `ERROR:` because `push_error` is passing behaviour. The sibling of D0115, unfixed. | degraded |
| 3 · File size | "No file over 400 lines" | `check_size_limits.py` scans `.gd` only. Four files in its own `tools/` are 404, 420, 438 and 500 lines — the same "gate exempts its own directory" class QUALITY.md §2 cites as the live example for gate 7. | degraded |
| 4 · Function size / complexity | "≤ 50 lines. Cyclomatic ≤ 10." | Length enforced; `resolve_floor` sits at exactly 50/50 at HEAD (the `body.gd`-at-400 pattern, one scale down) and the uncommitted D0139 change takes it to 60. Complexity is not enforced; `horizontal_resolve.gd` has `_try_climb` 13 and `_resolve_cell` 11. | degraded |
| 2 · No engine imports | Derived from `ClassDB`, "no silent gaps" | Node classes are covered. `randi_range()`, `ClassDB.instantiate("Node2D")`, `Engine.get_main_loop()`, `OS.get_environment()`, `ConfigFile.load()`, `extends SceneTree`, and an `[autoload]` into `sim/` all pass. | degraded |
| Commit-msg hook | No co-author or tool trailer; ledger entry per core/sim commit | Pattern is `co-authored-by` / `*-session:` / `generated with [`; "Assisted-by:", "Reviewed-by:", "Generated by" pass. The ledger rule checks the file was touched, not that an entry was appended — `8e04c97` satisfied it by renaming a symbol inside old entry D0125. | degraded |
| Gate mutation tests | "Every gate script is mutation-tested before being trusted" | Five `tools/**/test_*.py` files, 50 functions, genuinely two-sided, all passing today — and referenced by nothing: not CI, not hooks, not `/wrap`. Only `test_run_gd_test.sh` is wired. | degraded |
| 5, 6, 9, 10, 12, 14, 17, 18, 19, 20, 21 | QUALITY.md: "Every gate is CI-enforced" | No enforcing code exists for any of these eleven (no autoload check, no MODULE.md freshness, no conservation, no softlock, no save migration, no coverage, no claim-regression, no perf, no ADR-required, no API-doc). `harness.yml:178` names a conservation suite that does not exist. | unenforced |
| Trailers / identity | One author, no trailers, hooks installed | 2,748 commits across all refs scanned; identity check is set-based and refused a mismatched email on first try. Could not be fooled. | verified |
| Godot test job | 22 suites under a checksummed, pinned engine | Runs every `tests/test_*.gd` present; import step first; wrapper self-test first. Set-equal with the tree. Green on the pinned SHA. | verified |

### Duplication, complexity, coupling

**measured** Duplication: two exact clusters at HEAD (above). Beyond the gate's sight: `tests/body/play_scene.gd`
and `reveal_scene.gd` share nine function names (`_draw`, `_ready`, `_physics_process`, `_read_play_input`,
`_record_tick`, `_update_camera`, `_flush_recording`, `_finish_and_quit`, `_notification`) with 50–90%
shared lines — a near-duplicate an exact-match tokenizer cannot see. The legacy class is stated concretely
for the first time: at `0d5a9d1^`, `func _check` was declared in 52 of 75 `tools/*.gd` with five distinct
six-line bodies. In the live tree no function name is declared in three or more files except
engine-mandated ones. That class is gone. Complexity: production GDScript, 94 functions, median 1.5, max
13 (`_try_climb`); Python max 33 (`tools/anvil/schema.py:173 validate_event`), which no ledger entry
names. Coupling: with stubs excluded, four sim modules, fan-in/out 1–3, no outlier; with stubs included,
10 of 14 modules are 0/0 — the module map is a plan, not a graph.

### Test power

**measured** 151 GDScript test functions across 22 suites; an auditor classified 135 behavioural, 2
tautological, 9 implementation-asserting, 5 vacuous, and every suite except `test_replay_determinism` goes
red if its subject is deleted. That is a good result and I checked its worst examples myself. The ones
that matter: two of the eight movement-acceptance metrics (`edge_catch_events`, `depenetration_events`)
count flags the subject sets about itself (`horizontal_resolve.gd:80`, `:62`) — delete the line and the
metric is a perfect zero forever; the chamber was fitted to the controller (D0038 items 5 and 7) even
though the thresholds are spec'd; `test_cave_geometry.gd:142` re-calls the guard with the answer the test
supplies, and only the subprocess count at `:166` would catch the wiring being cut; the fuzz allowlist
bounds are last-observed counts with zero margin. Null results: no `!= null` on containers, no
`_check(true)`, every Python check asserts both directions. The 44/44 and 41/41 "OBSERVED" figures in the
READMEs are hand-run claims.

### Determinism

**measured** The real sim is replay-deterministic on this machine — probed directly, not inferred. The
harness does not test it. Every potential source, with coverage: terrain generation is float on its state
path (`value_noise.gd:58-82`, `shaft_generator.gd:111-123`; `lerpf` is the one construct that could
FMA-contract differently on arm64 vs x86-64 — unverified, one platform available); body kinematics are
plain unwrapped 64-bit ints (`body.gd:223`, zero `Fx.add` calls in the file) while ADR-0003 and
`core/MODULE.md` specify i32 wrap; `SplitRng.next_range` uses a float multiply (`split_rng.gd:50-60`)
under a MODULE.md that says "pure fixed-point integer math"; `_px_to_cell` uses `floor(float(px)/…)`,
proven equal to a shift on all 2,097,158 values probed. The replay test covers SplitMix64, the ID pool and
`Fx.add` only; `test_shaft_generator.gd:174` covers generation; `test_reveal_replay_driver.gd` replays
~900 real ticks but compares only `(dig_event, dug_material)`. Null: no `randi`, `Time`, `OS`, static var,
container `hash()`, or hash-map iteration on any state path in `core/` or `sim/`.

### Invariant bounds

| Bound | Value | Diagnosed? | Reading |
|---|---|---|---|
| `embedded` | ≤ 1 | Yes | seed 605, tick 844, one-tick corner graze — named and reproducible. |
| `grounded_no_floor` | ≤ 59 | No — status "under active diagnosis" | Raised 32→59 on a justification D0135 records as false (7 of 91 occurrences match the named mechanism). `tests/test_body_fuzz.gd:49` still carries the falsified justification. Two fix attempts since (D0138 a proven no-op; D0139 flips the mechanism to `grid_floor_backstop` with the count unchanged). |
| `bounds` | 805,397 (ungated) | Attributed, not diagnosed | See below. This is the undiagnosed one. |
| `floor_selection` | ungated | — | Reported only. |
| `overflow, discontinuity, deadlock` | 0 | Yes | Hard zero; D0122's `discontinuity` class has a per-commit regression fixture. |

**The bound nobody has read as a coverage number. measured** `fixture_body_fuzz_probe.gd:16-18` builds one
`TileGrid` outside the seed loop, with a comment written 2026-08-26 (`2ea7c70`) saying rebuilding per seed
"would only waste time, not add coverage". Dig landed two days later (`3181c30`) and mutates that grid.
The 1,000 seeds are therefore not 1,000 trials; they are one 1.5-million-tick trajectory over a chamber
that each successive random walker digs further apart. In a 40-seed sample from scratch, `bounds`
violations per ten-seed bucket rose monotonically — 132, 230, 256, 312 — and the full sweep's 805,397 is
54% of all ticks. D0123 (ledger:4550) noticed the shared grid as a reproduction detail (a fresh grid
reproduced nothing; replaying 498 seeds did); D0126 codified the accumulation into the regression fixture;
no entry treats it as a validity question. Every full-sweep number — 59, 805k, the seed lists in D0127 —
is conditioned on seed order and cumulative demolition, and the fast per-commit fuzz runs on a nearly
intact chamber, so its zeros are partly intactness. The 17-entry investigation from D0122 to D0139 has
been interpreting a statistic whose population is undefined.

## 4 · Drift and rot

**measured** An exhaustive claim-by-claim pass over 93 documents (every checkable count, path, status, and
section reference re-derived with a command) scored 670 claims at 345 TRUE / 229 STALE / 96 FALSE — the
core normative docs at 202 / 74 / 49, the twelve legacy-describing docs at 143 / 155 / 47 — with 38
contradiction pairs (two documents, or two places in one document, asserting incompatible things), 377
unresolved references and 395 that resolve only under `legacy/` or `docs/archive/`. The pattern inside
those numbers is the finding: every number the tree enforces mechanically (the 400-line `.gd` cap, the §9
movement constants, the fuzz seed counts) checked TRUE; every hand-typed count in prose has rotted. The
rows below are the ones the auditor verified themselves; the full table is in the appendix sources.

| Where | Says | Tree |
|---|---|---|
| `docs/BRIEF.md` @ `d54a676`, "Gates" | "All … gates PASS" | CI red on the same SHA (blocking duplication). Three consecutive briefs, including the one written after the pin, enumerate gate lists that omit the failing gate. |
| `CONTEXT.md:3` | "kept under 250 lines deliberately" | 275 lines. |
| `CONTEXT.md` "Surviving compaction" | WORKING.md "Under 150 lines" | 1,102 lines at the pin; 1,160 an hour later. It is a log with twelve CLOSED sections. |
| `CLAUDE.md`, `CONTEXT.md`, `docs/README.md` | `history/` "capped at 12" | 168 images. `history/README.md` admits it; the three normative pointers do not. |
| `CONTEXT.md`, `QUALITY.md` gate 7 | "Instrument LOC may not exceed game LOC. Enforced in CI." | Advisory; never armed. `WORKING.md:838` admits it. |
| `QUALITY.md` §1 | "Every gate is CI-enforced" | 11 of 29 have no code; 4 pass vacuously. |
| `WORKING.md` "standing reporting obligation" | Every BRIEF reports absolute ratio, velocity, unpushed count | Last BRIEF carrying the ratio: `3436250` (2026-08-28). Ten regenerations since omit it. |
| `.anvil/README.md` | "Two real events now" | 13 at the pin, 15 an hour later. |
| `tools/README.md` | `quality_check` "Not wired into CI" | Wired since `c56ff1f`; duplication is the blocking gate. |
| `tests/README.md` | A conservation-of-matter property test; unit/ property/ scenario/ golden/ suites | None exist; the four directories hold a README each. |
| `CONTEXT.md` "5-file rule", MODULE.md "60 lines maximum" | MODULE.md ≤ 60 lines | core 98, terrain_gen 84, body 82, world 70. |
| `project.godot:23` | "A 2D side-view roguelite … before the shaft floods … the rig that outlives every run" | The design retired on 2026-08-27. Shipped metadata, unchecked by `check_project_settings.py`. |
| `docs/GDD.md` §5 table vs §7 | Table: verbs come from artifacts, rig from material. §7: "Material buys verbs, through rig demands." | One document, two currency models. |
| `docs/GDD.md` §13 vs `docs/adr/0002` | Feeder "costs fuel" vs internal lifts free | Both normative; neither cites the other. |
| `data/materials/ore_iron.yaml`, GDD §10, `shaft_generator.gd:153-165` | Iron is Stonereach / hand-scraped in hour 1 / placed only below 140 m in deepstone | Three answers. And hardness has no consumer in `sim/`: `_handle_dig` excavates anything, so "hands stop working" is unimplemented. |
| `docs/README.md` normative table | Lists the normative set; "if not listed, not normative" | Ten `docs/*.md` are neither listed nor archived — A_PLUS_STATUS, ENGINEERING ("34,000 lines of `tools/*.gd`"), HARNESS_LAYERS, CAPTURE_MANIFEST, BITS, SANDBOX, LODE, VISUAL_TRIAGE, CONTENT_CATALOG_PLAN, BRANCHING — all describing `legacy/`. DECISIONS.md is listed as normative and describes FactorySim. |
| `CONTRIBUTING.md` | Self-declared stale; documents `run_harness.sh`, 119 layers, `godot --path .` runs the game | All legacy; `project.godot` has no `main_scene`, so that command runs nothing. |
| `docs/BRIEF.md` (post-pin) | `resolve_floor` 49 → 59 lines | `check_size_limits.py` itself prints 60; `function_length.py` prints 50 at HEAD. Off by one against the tool's own output, in a project whose standing rule is to verify numbers against tool output. |
| `QUALITY.md` §6 | "No forgotten worktrees"; root contains only six named files | Five prunable worktrees in `/private/tmp`, four holding commits reachable from no ref; three stashes; 57 `refs/archive/*`; root also has `CLAUDE.md`, `CONTRIBUTING.md`, `.editorconfig`. |
| Code and WORKING.md | "D0139" | No such ledger entry at the pin (ends D0138); the number was assigned in prose and a code comment before the entry existed. D0140 later reserved it. |

**Contradiction pairs the exhaustive pass added**

- Five documents (`CLAUDE.md:21`, `CONTEXT.md:171`, `docs/README.md:24`, `wrap.md:22`, `history/README.md:4`)
  require `BRIEF.md` to carry a "What was learned" section, and `wrap.md` points at "the template in
  `docs/BRIEF.md` itself"; the BRIEF has neither the section nor a template.
- "No automated checks on documents" is stated four times (`docs/README.md:50`, `QUALITY.md:141,191`,
  `ONBOARDING.md:202`) while two document gates run in CI: gate 23 checks WORKING.md's date, and the
  claim-reference gate parses `claims/*.md` and enforces a 40-claim cap.
- "Every stage ships at least one playable fixture in `scenarios/`" (`CONTEXT.md:207`,
  `ARCHITECTURE.md:240`, `QUALITY.md:179`); four stages have closed with `scenarios/`, `TASTE_QUEUE.md` and
  `tests/body/recordings/` all empty.
- `ONBOARDING.md:74` instructs using `.git/info/exclude` for local files — the exact pattern gate 27
  (D0062/D0063) exists to fail.
- `ARCHITECTURE.md:371,390,412`, ADR-0005 and `sim/invariants/MODULE.md:31` still cite
  `body.gd::_resolve_floor()`; the function moved to `vertical_resolve.gd::resolve_floor` at D0060. The
  ADR-gated collider shape (`ARCHITECTURE.md:442` "capsule or rounded AABB") was changed in code to a flat
  AABB with a ledger note and no ADR.
- Test-suite count is "13 suites, 96 functions" (`README.md:53`), "17 suites", "18 suite invocations", and
  "13 suites" in WORKING.md; the tree has 22 suites and 145–151 functions depending on how you count.
  Claims are "three" in `README.md:60`; there are four. Gates are "ten" in two places; CI runs 13 blocking
  + 3 advisory.
- All four "Last revised" headers (ARCHITECTURE 08-25, CLAIMS 08-25, QUALITY 08-26, GDD 08-27) are older
  than content in their own bodies.
- The only document that declares itself generated, `docs/CAPTURE_MANIFEST.md`, has a generator that
  exists only under `legacy/` and matches zero files; `BRIEF.md` is called "regenerated" and has no
  generator. The "no bare numbers in generated prose" discipline protects no document in the current tree.
- Three different "read first" lists (CLAUDE.md seven docs, ONBOARDING.md six "under 1,600 lines" —
  measured 1,643, `docs/README.md` fourteen entries); the required read before touching anything is 2,803
  lines, and the full normative set is ≈9,700.

### The ledger itself

**measured** 140 headers, 138 numbers, D0004 duplicated, one compound header. Only about 30 of 140
entries carry all four required lines; 134 have a reverse-cost line; roughly half never name an
alternative. 32 headers are dated 2026-08-26 for commits made on 2026-08-25 (a clock error D0031
discloses without marking the entries). Append-only holds in substance: across 87 commits, one in-place
edit (`8e04c97`, a symbol rename inside D0125) and one insertion that re-parented D0064's closing
paragraph under D0068. Spot-check of 22 "done" claims against the introducing commits: 21 exact, 1 off by
two. A `spot_audit.py` sample (`560ee78`) found every named decision covered and four silent judgment
calls uncovered, three of which later became ledgered problems — the sampler works.

**judged** The corrections are honest — D0127's "all 91 share one mechanism" becomes D0133's measured
84/91 the other way and D0135's "the justification was false", with the numbers that changed. What the
ledger does not do is link back far enough: D0133/D0135/D0137 stop at D0127/D0128, but the unhedged claim
originated in D0059–D0061, which no correction names; D0055 repositions D0039's constant, D0058 removes
D0055's clamp, D0128 raises D0061's bound — none cite their target. And the falsified justification still
stands, uncorrected, in the code comment at `test_body_fuzz.gd:28-52`. By subject: game-design 9 entries
(6%), sim code 44 (31%), instrument tooling 51 (36%), process and docs 36 (26%).

### Archive hygiene

**measured** Nothing in the live code path opens, imports, or executes anything under `docs/archive/` or
`legacy/`; ~150 citations, all provenance. Two documentary dependencies do exist:
`docs/EXPERIENCE_EVALUATION.md:8`, listed as normative, defines itself via
`docs/archive/DIRECTOR_BRIEF.md` §4; and the anvil schema's authority is the gitignored `incoming/`
document. Load-bearing text hiding outside the tree: the economy D1–D6 and the tier-3 heat gate exist only
in a chat transcript summarised in `WORKING.md:219-241` and `claims/C003:180` — the definition of done for
the entire build sequence points at an untracked draft.

## 5 · Scaffolding judgment

*judged throughout this section.*

**What is genuinely strong**

- The corrections have numbers in them. D0133 → D0135 → D0138 is the best thing in the repository: a
  bound raised on a stated mechanism, telemetry built to check the mechanism, the mechanism found to
  account for 7 of 91 cases, the raise's justification recorded as false rather than "refined", and then
  a director-prescribed fix proven a mathematical no-op by mutation test before the expensive sweep ran.
  I verified each step against the code. Most teams never write the second entry.
- `core/` is careful in the way that matters. SplitMix64 with an empirically verified logical shift, a
  `split()` keyed off the root seed so child streams are order-independent, generational IDs packed into
  one int, a fixed-point `length_sq` whose i64 headroom is derived rather than asserted, a div zero-guard
  that documents the hang it prevents. Small, complete, honest about its two rounding conventions.
- The CI job earns its green. A checksummed, pinned engine; the import step that a fresh clone needs; the
  wrapper's self-test running before any suite is allowed to trust it; one step per suite so a failure
  names itself. Every `tests/test_*.gd` present is run — set-equal, not count-equal.
- Refusal to fit fixtures is written down. D0056's constant-by-constant audit of what was tuned against
  the controller, and QUALITY.md §2's rule distinguishing "measured with margin" from "placed at the
  threshold", are the kind of thing only a team that has been burned writes.
- The GDD's dead-ends list (§9) is a real design artifact — mechanisms named, reasons given, the
  roguelite reversal recorded in place rather than erased.
- Commit messages match diffs. Ten random commits, zero mismatches; the ledger hook has zero bypasses
  since it landed.

**The core weakness: it verifies mechanisms and never verifies populations**

Every instrument in this repository is built to answer "did the check fire on the case I constructed" —
and, to its credit, it usually does. None is built to answer "what fraction of the subject did this run
actually visit". That single asymmetry produces every finding above that is not a typo:

- The fuzz sweep counts violations over a state distribution nobody has measured, so a coverage artifact
  (chamber decay) reads as a controller property.
- The LOC gate is mutation-tested against its own file and has never had a population above its floor.
- The claim gate is mutation-tested and has a population of zero.
- The wrap checklist enumerates gates by hand, so the population it reports on is whatever someone last
  remembered — a subset of CI, and the subset was green.
- The layer lint scans a syntactic form (`res://`) that the codebase does not use, and reports zero
  violations over zero references.

The project's memory calls this class "an instrument that cannot register its subject" and has caught it
eight or nine times at the unit level. It has not yet turned the same question on its sweeps, its
checklists, or its own gate scripts' populations.

**The next failure that hasn't been found yet**

The fuzz numbers are about the chamber, not the body. Not "the bound is wrong" — the population the bound
is measured over is undefined. Concretely: when D0139 or its successor finally moves `grounded_no_floor`
below 59, it will be read as a fix to `resolve_floor`; if a later dig change (hardness gating, a dig-rate
limit, R4's tool tiers) moves it again, that will be read as a regression in `sim/body`. Neither reading is
entailed. The instrument that would settle it — a per-seed histogram of where the body was and how much of
the chamber remained — does not exist, and nothing in the current ledger thread is heading toward it. Same
class, one level up: the fast per-commit fuzz's zero for `grounded_no_floor` is partly a statement that
seeds 0–99 have not yet dug the chamber apart.

The structural reason it will stay hidden: the reporting layer is hand-enumerated. Anything added to CI
after `wrap.md` was written is invisible to the brief until someone edits the checklist; anything the fuzz
reports but does not gate is invisible to everyone. The `ERROR:` sibling of the D0115 masked crash
(reproduced above) is the same shape at the runner level.

**Proportion**

The instrument is not measuring almost nothing; it is measuring one thing — a 1,300-line movement
controller against a hand-built chamber — and it measures that well. Nothing it was designed for has
happened: no scenario has been run, no claim has a value, no human session has been recorded, no agent has
entered through the door (`interface/` has zero lines). The economy checker (1,066 lines) has never seen
real data and passed twelve of fourteen dead economies fed to it, including the drafted real D1, which is a
cold-start deadlock by the project's own hardness numbers. The anvil (887 lines) has one reader and
accepted 28 of 43 malformed events. The control-plane slice (180 lines) has one consumer, its own test.
These are not sophistication masking little; they are apparatus built ahead of the thing they measure, and
the ledger — 62% about process — records the build honestly. The belief that the instrument is the
portfolio piece is defensible only if the instrument's own engineering exceeds the game's. Today the gates'
documentation exceeds the gates.

**Complexity that doesn't earn its keep**

- Comment-to-code ratio in `sim/body`. `resolve_floor` is 50 lines, of which 22 are a comment block citing
  ledger numbers; `vertical_resolve.gd` is 194 lines, roughly 60% prose. The code reads as an index into
  the ledger. The stated reason (the 400-line gate should not be met by trimming WHY) is right; the effect
  is a 50-line function that hits its own cap from comments.
- ADR-0001 exempts report tooling from a claim gate for a directory (`harness/aggregate`) with no code;
  ADR-0002 scopes R1's cost model for a transport module with no code. Two of five ADRs govern nothing yet.
- `docs/EXPERIENCE_EVALUATION.md` (395 lines, normative) specifies six evaluation layers and a
  calibrated-actor protocol above a game with no items.
- `tools/check_fork_completion.py` (204 lines with its test) mechanises `git diff --name-only | grep`.
- The event log. Seven event types, a typed-reference table, a 66-line validator with cyclomatic
  complexity 33 — for thirteen hand-written notes that the ledger already holds in prose.
- Ten `sim/*/MODULE.md` stubs kept so that gate 6 ("MODULE.md in every module directory") has directories
  to pass on.

**What I would cut**

Twenty percent of non-game code is about 2,100 lines. This removes more than that without losing a check
that has ever fired on a real defect:

| Cut | Lines | Why it is safe |
|---|---|---|
| `tools/economy_check/` | 1,066 | Unwired, no real data, cannot load the real material files (crashes on `mass_per_unit`), passes dead economies. Rewrite when `data/economy/` exists, against it. |
| `tools/anvil/` + `.anvil/` | 887 | One reader, unwired, accepts garbage, sources 2 decisions vs 77 ledger entries. Fold the FINDING events back into the ledger they duplicate; reintroduce a typed log when something reads it. |
| `tools/check_fork_completion.py` + test | 204 | A one-line git command in `wrap.md` does the same job. |
| `tools/quality_check/coupling.py` + `dashboard.py` | 337 | Coupling reports four modules with no outliers; the dashboard has no consumer. |
| Ten legacy-describing docs | ≈5,800 | A_PLUS_STATUS, DECISIONS, ENGINEERING, HARNESS_LAYERS, CAPTURE_MANIFEST, BITS, SANDBOX, LODE, VISUAL_TRIAGE, CONTENT_CATALOG_PLAN → `docs/archive/` with dated headers, per the project's own rule. |
| `docs/WORKING.md` CLOSED sections | ≈900 | The document says it resets when a stage closes. Twelve closed sections are a log; the ledger and `git log -p -- docs/BRIEF.md` already hold the narrative. |

Keep: `layer_lint/` (fix its scope rather than cut it), `quality_check/duplication.py`, `run_gd_test.sh`
and its self-test, the hooks, `data_codegen`, `schema_validator`, every Godot suite.

## 6 · The game, read honestly

**What exists. measured** Two Godot scenes under `tests/body/`, launched by command lines that appear only
in their own docstrings. `play_scene.tscn -- --play`: a 16×40 px yellow rectangle in a hand-authored
chamber of brown 4 px cells — walk, jump with variable height, coyote time and buffer, auto step-up,
mantle, corner correction. `reveal_scene.tscn -- --play`: the same body in a generated 48-column shaft
(topsoil → hardrock → deepstone bands, caves, copper/coal/iron veins, one empty ruin chamber) with a dig
key that clears one column beside the body and cyan "glimmer" pockets to find. That is the whole playable
surface. No items fall, nothing burns, nothing hauls, no water rises, no rig wants anything, no rope, no
save. `godot --path .` runs nothing (no `main_scene`). The three most recent history images are exactly
this: a brown field with cyan blobs and a yellow rectangle.

**measured** Designed versus built, by the GDD's own sections: §1 premise — the shaft exists, the rig does
not; R1 — no transport, no fuel consumer; R2 — no recipes, no demands, no `data/economy/`; R3 — no fluid
code, "section" defined nowhere; R4 — no tool tiers, and hardness has no consumer; §10 "the hole is a
conveyor belt", the single most important thing — no items, no forge, no claim; §12 Reveal — built as
glimmer + dig, unmeasured; Flow and Pressure — unbuilt. Of ONBOARDING's twelve stages, four have landed.

**Design coherence. judged** The premise chain (CONTEXT → GDD §§1, 3, 7, 9 → README) tells one story and
the reversal is recorded in place — that part is coherent. Below it, the documents disagree with each
other and the data: the currency model in GDD §5's table contradicts §7; feeder cost in §13 contradicts
ADR-0002; iron's location has three answers; coal generates as the shallowest deposit, the exact corollary
R1 warns trivialises fuel logistics; and the drafted D1 (30 iron ingot → drill) requires a material that,
by the project's own hardness and placement numbers, cannot be reached without the drill it unlocks.
Fossils of the roguelite survive where nobody looked: `project.godot`'s description, six MODULE.md files
(world "termination conditions", economy "converts hauled items to value", commands "out-of-run", fluid
"flood-clock"), and the run-cadence paragraph in GDD §5. None is load-bearing on code, because there is no
code for them to bear on.

**The economy checker's real robustness. measured** In scratch, with the checker's own schema: a six-step
ladder of "more clay" with a haul-mass bump per step — the grind-shallow-forever exploit GDD §11 says the
demand chain kills — passes clean. So do a self-unlocking cycle, a demand mixing one new material with one
impossible one, a breach that needs an item no recipe can make, a closed two-recipe loop that feeds no
demand, quantities of zero and minus five, a duplicate material key silently overwritten, an empty chain, a
chain with no R2 bulk requirement, and the drafted real D1. The repository's real `data/materials/*.yaml`
crash it with `KeyError: 'mass_per_unit'`. Three controls (already-accessible, empty, unreachable-only) are
caught. The two prior rule fixes were both about whether a demand's grant matters; nothing asks whether a
demand can be satisfied. It measures the shape of the graph, not its feasibility.

## 7 · What I could not assess

- Cross-platform float determinism of terrain generation (`lerpf` under FMA on arm64 vs x86-64) — one
  platform available.
- Feel. The only human-input path is a window not opened on the director's machine; there are zero
  recorded sessions to replay.
- The full 1000×1500 fuzz sweep — 40×1500 was run in scratch (60,000 ticks) to test the accumulation
  hypothesis, not the full 1.5 M.
- The nightly fuzz job's history — `gh run list` shows push runs only; whether the schedule has ever fired
  was not checked.
- Whether Godot guarantees int64 wraparound (vs. C++ undefined behaviour) for the unwrapped kinematics.
- The ten legacy-describing documents were only sampled (their 117/119/32 verdicts come from the delegated
  pass); A_PLUS_STATUS.md and VISUAL_TRIAGE.md were not read end to end, because nothing in the live tree
  depends on them.

## 8 · Where the brief is wrong or leading

- It asks whether the bounds are diagnosed; the sharper question is whether the population is defined. A
  diagnosed bound over an unmeasured state distribution is still a number without a subject. The brief
  inherited the project's framing that the fuzz counts describe the controller.
- It asks whether gates "check their whole stated scope" and misses that the stated scope is itself a
  hand-typed list. The failure that actually bit was not a gate scanning half its subject; it was a
  checklist (`wrap.md` step 7) that names a subset of CI. The brief never asks who enumerates the
  population of gates.
- It treats the ratio as the health metric. The ratio is a symptom. The health metric is "has the
  instrument ever produced a design verdict" — and the answer is no, which no ratio would reveal.
- It assumes one session. Two sessions committed to the same checkout during this audit (five commits, one
  hour), the working tree carried three sessions' worth of uncommitted work, and the BRIEF and WORKING at
  the same commit disagreed about whether the tree was clean. The brief's pinned-hash discipline is right
  and insufficient when the tree moves under the auditor.
- It doesn't ask what the game looks like. Three screenshots answered more about proportion than any count
  did.
- It doesn't ask whether the gates' own tests run. They don't. "Mutation-tested before trusted" is true at
  authorship and unenforced afterward.
- It says "the project believes the instrument IS the portfolio piece." The tree says the ledger is the
  portfolio piece; the instrument is its illustration. That is a different bet, and a better one — see
  Part II.

# Part II — The staff-engineer read

Same tree, same measurements, a different question: after weeks in this, am I impressed — and what exactly
would it take.

**My bar, stated first.** I am not moved by the count of anything — gates, tests, entries, lines. I am
moved by restraint (what was deliberately not built, and whether I can see it), honesty under failure (what
the system does when it is wrong, and whether I can find those moments without excavating), seams (whether
I could change it without fear), legible state (whether I can know what is true today from one place),
proportion (effort where it matters), and taste (the small decisions that went the harder-right way). Green
CI is the floor. A 5,000-line ledger is evidence of discipline, not of quality, until I read what it
corrected.

## Eight categories

**3.1 Restraint — adequate.** Restraint is legible in the design: GDD §9 names eleven dead mechanisms with
reasons, "do not build automated checks on documents" is a rule, rope is explicitly not started, Semantic
actions and the LANGUAGE envelope are explicitly deferred with reasons in `tests/control_plane/`. Restraint
is absent in the tooling: four instruments were built ahead of any subject — the economy checker, the
event log, the control-plane slice, and a 395-line evaluation protocol — and each is defended in the ledger
as "the smallest thing that could test X" while X does not exist. Up one level: park the three unwired
instruments with one ledger entry each saying "not until the subject exists", and let that entry be the
visible restraint.

**3.2 Honesty under failure — impressive in substance, solid in legibility.** Verified real: the
masked-crash harness (D0115/D0116) found by accident and fixed with a self-test; the bound-raise
justification recorded as false (D0135) with the 7-of-91 number; the director's own prescribed fix proven
a no-op by mutation before the sweep (D0138); an external audit's corrections appended, originals untouched
(D0133). None is performative — each names the specific claim, the specific evidence, and what did not
change. Two things keep it from impressive-in-legibility: I had to excavate it from a 5,392-line file, and
the corrections stop one hop short (the falsified claim originated in D0059–D0061, which nothing names;
the code comment at `test_body_fuzz.gd:49` still asserts it). And a small tell: D0135 says the
falsification came "not from a subsequent audit"; D0133 says the external audit is what prompted building
the instrument that falsified it. Up one level: a one-page "when we were confidently wrong" index generated
from the ledger's own resolves/corrects links, and a rule that a correction must name the origin entry,
not just the latest restatement.

**3.3 Seams — solid for what exists; unknown for what doesn't.**

| Change | Touches | Blast radius |
|---|---|---|
| Add a machine type | Nothing existing. `sim/machines`, behaviors, items, `data/machines/` are all empty; the "one data file, zero classes" contract is a paragraph in ARCHITECTURE §8. | Unmeasurable — there is no seam yet, only a promise. |
| Add a new instrument (a gate) | The script, its mutation test, a CI step, a QUALITY.md gate number, the `wrap.md` enumeration, `tools/README.md`, a ledger entry. | Seven hand-synchronised places. The `wrap.md` list already drifted from CI; this seam is where the current red came from. |
| Swap the renderer | `tests/body/play_scene.gd` and `reveal_scene.gd` (≈400 lines, near-duplicates) read `Body` and `TileGrid` directly. `view/` is empty. | Small — but the "fog filter applies identically to renderer and agent" property (ARCH §5) is unverifiable because no filter exists. |
| Add a second agent model | `ObservationBuilder`/`CanonicalAction` exist in `tests/control_plane/` with one consumer (their test). `ScriptedTraverse` reads privileged chamber constants directly. | Moderate: the seam is drawn but nothing goes through it; and the CONSTRAINED envelope hands out undug rock inside its radius, so "discoverability" is not yet measured by it. |
| Change a core data format (e.g. Fx fractional bits, or TileGrid sparse → chunked) | `TileGrid`'s API is narrow (`is_solid`/`get_material`/`set_material`/`excavate`/`in_bounds`) — storage is contained. `Fx` is not: `Fx.SCALE` appears 89 times in `tests/` and 30 in `sim/` as raw `col * CELL * Fx.SCALE` arithmetic; `Body._px_to_cell` is called from 21 files; body privates (`_left_x…`) 41 times from tests. | Large for Fx, small for the grid. The seam is by convention, and the convention is leaky. |

Up one level: one public position-to-cell conversion (D0141 already names this) and a Fx helper for
cell↔px so tests stop hand-multiplying; then the first machine, so the data-driven seam is a fact.

**3.4 Legible state — concerning.** The single source of current truth is supposed to be WORKING.md +
BRIEF.md. At the pin, WORKING is 1,102 lines and BRIEF says the tree is clean and the gates are green; the
tree is dirty and CI is red. A stranger must read ≈2,800 lines before touching anything, and ten documents
in `docs/` describe a codebase that lives in `legacy/` with no status header saying so. Two "standing
obligations" (ratio line, unpushed count) lapsed without anyone noticing, which is the exact failure the
obligations were written to prevent. The ledger is the honest record and it is unreadable as state. Up one
level: a status page that is a tool output, not prose — see question A.

**3.5 Proportion — concerning.** Read both halves: the game is a good movement controller with a debug
renderer; the instrument is a good CI job, a good fuzzer, three unwired checkers, and seventeen thousand
lines of process. The instrumentation has caught real defects — the out-of-bounds launch, the dig
staircase, the masked crash, the no-op fix — every one of them in the movement controller. It has never
caught, or measured, anything about the design, which is what it was built to do. That is not sophistication
in search of a problem; it is apparatus built in the order the plan dictated (movement first) and then
elaborated while the plan stalled at stage 4 of 12. Up one level: one recorded human session and one
measured claim.

**3.6 Taste in the small — solid, with real high points.** Present: `Heightfield.surface_y_at_x` refusing
to interpolate a real height against `NO_FLOOR` ("a gap has to read as a gap"); `grid_floor_backstop`
deferring when a real floor is further down; `SplitRng.split()` keyed off the root seed;
`TileGrid.state_signature` including dig extent because it is real state; the fuzz oracle using the body's
own per-tick flags as ground truth for legitimate displacement; `Fx.div`'s zero-guard documenting the hang;
the wrapper's positive and negative controls; `release` instead of `free` because `free` collides with
`Object`. Absent: a 50-line function that is 22 lines of comment; commit subjects averaging 77 characters;
"D0139" cited in code before the entry exists; the brief's 59 where the tool prints 60; `project.godot`
still calling the game a roguelite; a MODULE.md cap of 60 that four modules exceed. The pattern is that
taste is present where the engineering is hard and absent where the discipline is clerical.

**3.7 Reproducibility and onboarding — concerning.** Clone-to-green is fully reproducible — by the CI
file. For a human: eleven real steps, four documented, all four inside a CONTRIBUTING.md that opens by
saying it describes the wrong codebase. Not written anywhere at the root: Python version, `pip install
pyyaml`, the fifteen gate commands, `godot --headless --import`, how to run one suite, how to launch
either scene. `godot --path .` runs nothing. A senior engineer would be productive in a day if they read
`harness.yml` first and ignored CONTRIBUTING; the docs do not tell them to. Up one level: a real
CONTRIBUTING with the eleven steps and one `make check`.

**3.8 Correctness and rigor — the floor holds, with named holes.** Determinism: holds (probed), untested
by the gate that claims it. Tests: would go red on deletion in 21 of 22 suites; two acceptance metrics are
self-reported. Gates: four of the most-cited pass with no subject; eleven have no code; the gate tests run
nowhere. History: honest. This is a passing floor for the 1,600 lines that exist, and the holes are all in
the layer that describes the floor.

## The two questions

**A · The single change that would most raise a staff engineer's impression.** Make declared state a tool
output. Replace the hand-enumerated gate sections of BRIEF.md, `wrap.md` step 7, and QUALITY.md's "every
gate is CI-enforced" with one script that runs exactly what CI runs and emits the verdict table, and paste
that output — verbatim, with the commit hash and the CI run conclusion from `gh run view` — into the
brief. Not a doc-checker (the project rightly forbids those); a status that cannot be typed. Every
headline finding on this page — the red-vs-green brief, the never-armed ratio gate, the lapsed
obligations, the unwired gate tests, the gates with no script — would have been visible in the first such
output, because a table with a row per gate has no way to omit the failing one. The drift audit's own
totals make the case numerically: across 670 checked claims, the numbers a script enforces were all true
and the numbers a person typed were the stale ones.

Runner-up, and the one that would make me want to know who built it: one recorded human session against
the reveal site and one measured value in `claims/C004`. The instrument has never produced a verdict. The
first one, even a null, changes what the repository is.

**B · The tell.** Open QUALITY.md, read gate 7 — "Instrument LOC ≤ game LOC … Enforced in CI. When the
ratio inverts, the next unit of work is game" — then run `python3 tools/layer_lint/check_loc_ratio.py`. It
prints "ADVISORY … Velocity check would FAIL but is not gating this run," and the history shows it has
never once been able to fail. This is the project's own stated health metric, the lesson it says it
learned from the previous codebase's death, and the number it quotes in its own briefs — and the
enforcement is a comment. A senior reader who finds this stops believing the word "enforced" everywhere
else in the repository, and the next thing they check (the brief's "all gates PASS" over a red CI)
confirms it. I looked for a tell in the code and did not find one there; `core/` and `sim/body` survive a
hostile read. The tell is entirely in the gap between what the documents say is enforced and what the
scripts do.

## The honest verdict

Impressed? Impressed by the corrections and by `core/`; unconvinced by the machine around them. The
ledger's willingness to write "the justification was false" with the number attached is rarer than good
code and I would show it to my own team. The gates, the brief, and the quality document describe a
stricter repository than the one in the tree, and I found that out in an hour with `gh run list` and one
Python script.

Would I want this person on my team, and at what level? Yes — as a strong senior engineer: rigorous at the
unit, honest in the record, careful with the hard parts. Not yet staff. Staff is the judgment to not build
the economy checker until there is an economy, to notice that a checklist is a population, and to treat
"enforced" as a word that has to be true every commit. The codebase would need to show that restraint —
three instruments parked, one status output, one measured claim — to move the level.

The ratio, ruled on. 6.26 by the project's definition, not 5.7. Neither "defensible bet" nor "avoidance"
fits cleanly. The ordering (movement first, hostile chamber, fuzz) was correct and the controller is good
because of it. What happened after stage 4 — a checker for absent data, a log nothing reads, a control
plane with one consumer, and a seventeen-entry investigation of a fuzz statistic over an undefined
population — is elaboration while the plan stalled, and the ledger's own subject split (62% process) says
so. It is a bet whose payoff has never been tested once. Call it: an honest bet, not yet placed.

**The crux.** The belief that the development substrate is the portfolio-grade artifact and the game its
vehicle is one I would share if the substrate's own claims held. A substrate whose purpose is to keep
declared state honest cannot ship a brief that says green over a red build, a health gate that has never
been armed, and gate tests that run nowhere — those are precisely the failures it exists to make
impossible. So: not yet. What is portfolio-grade today is narrower and better than the pitch — a ledger
that records being wrong in specifics, a fuzzer that found four real bugs, a CI job that earns its green.
Pitch that, make the status a tool output, measure one claim, and the belief becomes true.

## Appendix · Method and sources

**Pin.** Code and gates at `d54a676`, snapshot via `git archive` into scratch; docs cross-checked at
`d4d1b62`; the tree reached `b71d6e9` before publication (another session, same checkout, working tree
dirty with three sets of uncommitted work — including a live extraction of the duplicated fuzz helpers
that will clear the CI red).

**Measured by me.** Every count in §2; every gate run and exit code; the CI run conclusions and failing
steps via `gh run view`; the 40-seed fuzz sample; the economy fixture runs; the `ERROR:` wrapper
reproduction; the ledger falsification chain read in full; the two newest screenshots.

**Delegated, then spot-verified.** Eight read-only auditors (test power, gate mutation, determinism, docs
drift, ledger, git history, economy/design, anvil/archive). Each claim quoted from them that mattered was
re-checked against the tree before it appeared here; their full reports, with member lists rather than bare
counts, are in the session scratch directory under `reports/`.

**Not done.** No file in the repository was edited; no git state was mutated; no commit; the full nightly
sweep was not run; no window was opened.

---

# Part B — Sinkforge Unbandaged

*Sequenced plan · responds to the cold read at `d54a676`*

Two halves, deliberately unequal. The first is the audit response: six steps (0a, 0b, 1–4) that make
declared state un-typeable, none optional, none a demo. The second is what the first earns — the
deterministic bisect, the provenance board, the heatmap — and it is fenced behind a gate with three
checkable conditions. If anything in half two is being built while a condition in the gate is false, the
plan is being misread. Line counts marked *est.* are estimates; everything marked **measured** came from
tool output during the audit.

**Revision 2.** Phase 0 split into 0a (mechanical, reversible) and 0b (archive and prune, judgment); the
additions are held to the same subject-exists gate the demos get, and two moved to Parked; four projection
scripts folded into one `tools/render/`; the VERDICT and `status.json` contracts written out so they can
be pasted into an engineer prompt without paraphrase.

**Four principles**

- **Collapse, don't add.** Each half-one phase must remove a hand-maintained list, a document section, or
  a script, and adds no service. Non-game lines go down through phase 3.
- **Machines write status.** No verdict, count, or ratio is typed by a person. Prose points at generated
  tables that carry a `--check` gate — the ADR-0004 pattern already trusted.
- **One primitive.** An Episode is `(site, seed, input log)`. Fixtures, claims, fuzz violations, saves,
  bisect and replay all consume the same record.
- **Subject before instrument.** Half two is a set of projections over data. The data has to be real
  first. The gate says exactly what "real" means.

## The mechanism being changed

Today, status originates in three unlinked places and reaches the reader through prose. The audit's
headline findings — a green brief over a red build, a health gate that was never armed, lapsed "standing
obligations", a fuzz count over an undefined population — are one defect: a person enumerated something a
script should have. The fix is a script that reads the one list CI reads, and projections generated from
its output. The project built `--check` freshness for `data/*/generated.gd` and never applied it to the
thing that was rotting: its own status.

**Today:** `harness.yml` (gate list A) → CI run conclusion, nobody reads it; `wrap.md` step 7 (gate list
B) → session runs a subset; `BRIEF.md` → "all PASS", typed, no link; fuzz sweep → counts, no population;
ledger prose → 17 entries, D0122–D0138.

**After phases 1–2:** `harness.yml` (the one list) → `gh run view` HEAD conclusion + fuzz sweep (counts +
population) → `status.py` (PASS/FAIL/SKIP/PARTIAL/VOID) → `status.json` → BRIEF table (generated,
`--check`) + `board.html` (half two) + anvil events (MEASUREMENT, machine-written).

Left: the three places status is born today reach the reader only through hand-typed prose, and the two
gate lists have no edge between them — which is exactly how a green brief shipped over a red build, three
briefs running. Right: one list, one script, one JSON; everything a person used to type is a projection
with a freshness gate. The board is drawn because it is a consumer of the same JSON, not because it comes
early — it is half two.

## The one primitive

This is vocabulary, not a build. ADR-0006 already found it: because the sim is byte-deterministic and
inputs are logged, a complete description of any moment in the game is `(site, seed, input log)` plus a
tick. Call it an **Episode**. Today five different things approximate it with five shapes — the fuzz
violation line, the `--play` recording (in two column dialects), the reveal replay driver's parse, the
future scenario YAML, the future save. Naming it costs nothing now and makes half two mostly free later.

Six things the repository already wants, all consuming one record: a playable fixture (a `--play`
recording) IS an Episode; claim C004 (`dig_rate_lift`) MEASURES one; a fuzz violation (seed 605, tick 844)
+ tick is one; a bisect (first diverging commit) REPLAYS ACROSS episodes; a save/checkpoint (ADR-0006
prefix) IS A PREFIX OF one; a replay scene (`--at-tick`, invariant shown) OPENS one. The recording header
names its fields (fixing the two five-column dialects D0140 found), and every producer and consumer goes
through one parser. Only the left three exist or are in half one; the right three are half two.

## Half one · not optional, not a demo

### The foundation: make declared state un-typeable

Six steps in dependency order. Each removes a place where a person can type a falsehood and adds no
service. 0a is settings and hooks; 0b is the one step that moves things people made, and is verified
differently. Phases 0b–3 shrink the tree. Phase 4 is one hour of the director's time and is the only phase
that produces a number anyone outside the project would care about. This half is the audit response; the
thing that impresses a staff reader is that it was done first.

#### 0a. Arm what exists — *est. half a day · +≈120 lines · all reversible*

**Goal.** Make a red build block something and close the four gate holes the audit reproduced. Every item
is a setting, a hook line, or a test — one report, one kind of verification: does the thing now fire.

**Files**

- GitHub settings — branch protection on `main`: required checks `authorship`, `structural gates`,
  `godot test suites`. Note it in CONTRIBUTING.md. **measured** pushes go straight to main today; the last
  three were red. The single cheapest, highest-value change on the page.
- `.github/workflows/harness.yml` — one step: `for t in tools/test_*.py tools/*/test_*.py; do python3 "$t"
  || exit 1; done`. **measured** five test files, 50 mutation tests, run nowhere today.
- `tools/run_gd_test.sh` — fail on an engine error the wrapper currently passes: any `^\s+at:` line whose
  function is not `push_error`/`push_warning`. Add `tests/fixture_harness_core_error_probe.gd`
  (`Array.remove_at(99)`) as the positive control in `tools/test_run_gd_test.sh`. **measured** reproduced:
  ALL PASS, exit 0.
- `.githooks/commit-msg` + `tools/check_trailers.sh` — ledger rule requires a new header:
  `git diff --cached -U0 -- docs/DECISIONS_LEDGER.md | grep -qE '^\+## D0[0-9]{3}'`; trailer pattern gains
  `assisted-by:|reviewed-by:|generated by`.
- `tools/layer_lint/check_size_limits.py` — add `tools/**/*.py` to the population. **measured** four files
  then exceed 400: split `anvil/test_check_integrity.py` (420) and `quality_check/test_quality_check.py`
  (404) here; `economy_check/test_check_tier_rule.py` (500) and `check_tier_rule.py` (438) go on a named
  exemption list with the comment `# removed in 0b`, so 0a lands green and 0b deletes the exemption with
  the files.
- `tools/check_trailers.sh:31-38` ↔ `tools/test_run_gd_test.sh:32-39` — extract the byte-identical
  `check()` into `tools/sh_check.sh`, sourced by both.
- `tests/test_body_fuzz.gd:28-52` — replace the falsified D0059f justification with D0135's status
  ("measured; mechanism under diagnosis; population: see phase 3").
- `project.godot:23` — description no longer says roguelite.

**Removes.** The "direct push to red main" path; two duplicate shell helpers; a green over a core error; a
falsified comment still teaching the next reader. **Adds a service?** No.

**Done when.** A deliberately red branch is refused by the rule; the core-error probe fails the wrapper;
the five Python test files appear as a CI step; `gh run view` on HEAD is green.

#### 0b. Archive and prune — *est. half a day · −≈5,700 lines · judgment, tag-first*

**Goal.** Put the tree in the state the docs describe. Separate from 0a because every item here moves or
removes something a person made, which is a different risk class and wants a different check: not "does
it fire" but "did anything load-bearing move".

**Files**

- `docs/` → `docs/archive/` with dated headers: A_PLUS_STATUS, DECISIONS, ENGINEERING, HARNESS_LAYERS,
  CAPTURE_MANIFEST, BITS, SANDBOX, LODE, VISUAL_TRIAGE, CONTENT_CATALOG_PLAN. **measured** 4,622 lines.
  Remove DECISIONS.md from the normative table. Before the move: grep every inbound link from the
  surviving docs and the commands, and list them in the ledger entry.
- `tools/economy_check/` — **measured** 1,066 lines checking a `data/economy/` that has zero files.
  Delete, with the ledger entry stating the re-creation trigger: the week `data/economy/` gains its first
  file, written against that file. Remove 0a's exemption in the same commit.
- Git hygiene, your ruling, nothing deleted without a tag — **measured** four of the five prunable
  worktrees hold commits reachable from no ref: `git tag rescue/<name> <sha>` first, then
  `git worktree prune`; turn the three `option-{A,B,C}-diff` stashes into branches. The ruling names which;
  the session executes only the named ones.

**Removes.** Ten unclassified documents; an instrument with no subject; five stale worktrees and three
stashes that no doc records. **Adds a service?** No.

**Done when.** An independent re-read (Codex, or the cold-read skill later) confirms no surviving doc or
command links into `docs/archive/` by its old path; `git worktree list` matches what WORKING.md says; every
rescued commit has a tag.

#### 1. One status oracle — *est. two days · +≈300 lines*

**Goal.** Exactly one list of gates, one way to run them, one machine-readable answer to "what is true
right now" — and a gate with no subject says so instead of passing.

**Files**

- `tools/verdict.py` (new, ≈40 lines) — `emit(verdict, assertions, population, note)` prints a final
  `VERDICT: PASS assertions=12 population=15` line. Five verdicts: PASS · FAIL · SKIP · PARTIAL · VOID —
  the legacy harness's best convention, which the new gates dropped. `population == 0` ⇒ VOID unless the
  gate declares `expect_empty` with a reason. **measured** this alone turns `layer_lint` (0 references),
  `check_claim_references` (0 layers, 0 proven claims) and `check_loc_ratio` (below its own floor) from
  green into visible VOID with no logic change.
- Every gate script's `main()` — replace the final print with `verdict.emit(...)`. Mechanical, one per
  script. The line grammar and exit codes are the contract below.
- `tools/status.py` (new, ≈200 lines) — parses the gates job's `name:`/`run:` pairs out of `harness.yml`
  (so the workflow file IS the list); runs each, captures the VERDICT line; adds `gh run view --json
  conclusion` for HEAD, the absolute ratio, unpushed count, dirty files, worktrees, stashes, and the map of
  QUALITY.md gate numbers to step names with the unmapped ones printed as UNENFORCED. Emits `status.json`;
  `--brief` renders a markdown table; `--full` also runs the Godot suites through the wrapper.
- `.github/workflows/harness.yml` — final step in `gates`: `python3 tools/status.py --json > status.json`
  + `actions/upload-artifact`.
- `.claude/commands/wrap.md` — step 7 becomes: run `python3 tools/status.py --brief`, paste verbatim. The
  enumeration is deleted.
- `docs/QUALITY.md` — each gate line gains the CI step name it maps to, or "unenforced (status.py
  reports)". **measured** eleven rows say unenforced today; decide each: build, or strike.

**Removes.** The second gate list (`wrap.md`); the sentence "Every gate is CI-enforced"; the ability to
write "all PASS" by hand; three vacuous greens. **Adds a service?** No — one script, run by CI and by the
wrap.

**Done when.** Deleting a step from `harness.yml` changes `status.py`'s table with no other edit; emptying
`scenarios/` shows VOID, not PASS, for gate 16; the unpushed count and ratio appear whether or not anyone
remembered them.

**The contract, for pasting into an engineer prompt.** Written out so the spec travels without paraphrase.
Two things are fixed here: the last line every gate prints, and the shape `status.py` emits. Everything
else about their internals is the engineer's.

```
# tools/verdict.py — the last line every gate prints, and the exit code it returns
VERDICT: <PASS|FAIL|SKIP|PARTIAL|VOID> assertions=<int> population=<int> [note="<why>"]

PASS     population > 0 and every assertion held                       exit 0
FAIL     any assertion failed                                         exit 1
SKIP     the gate declared it should not run here, with a reason      exit 0   (note required)
PARTIAL  ran, but coverage or population moved past a stated tolerance exit 0   (note required; status shows it)
VOID     population == 0 and no expect_empty(reason) was declared      exit 2   (blocks CI until a reason is written)

expect_empty("reason") turns a would-be VOID into SKIP with that note. The reason is the point:
"scenarios/ is empty until stage 5" is a sentence someone had to write, and it prints every run.

# status.json — what tools/status.py emits; --brief renders it, render/ consumes it
{ "head": "<sha>", "generated_at": "<iso8601>",
  "ci":     { "run_id": <int|null>, "conclusion": "success|failure|none" },
  "gates":  [ { "step": "<harness.yml step name>", "quality_id": <int|null>,
                "cmd": "<run: line>", "verdict": "PASS", "assertions": 12, "population": 15, "note": "" } ],
  "unenforced": [ { "quality_id": 7, "title": "<QUALITY.md line>" } ],
  "ratio":  { "absolute": <float>, "game_loc": <int>, "instrument_loc": <int>, "advisory": <bool> },
  "tree":   { "dirty": ["<path>"], "unpushed": <int>, "worktrees": ["<path>"], "stashes": <int> },
  "metrics": { "working_md_lines": <int>, "raw_cell_px_sites_outside_core": <int> } }

# invariants a verifier can attack
- gates[] is derived from harness.yml's gates job and nothing else; a step removed there disappears here with no other edit
- every QUALITY.md gate number appears exactly once, in gates[] or in unenforced[]
- a gate whose VERDICT line is missing is recorded as FAIL with note="no VERDICT line", never omitted
- status.py exits 1 if any gate is FAIL or VOID; --brief prints the table either way
```

#### 2. Projections, not prose — *est. two days · +≈200 / −≈1,000 lines*

**Goal.** Every status-like section of a human document is generated from `status.json` and guarded by a
freshness gate — the exact mechanism ADR-0004 uses for `data/*/generated.gd`. Prose stays human; numbers
stop being typed.

**Files**

- `tools/render/` (new, ≈200 lines across `brief.py`, `claims.py`; later `board.py`, `heatmap.py`) — one
  projection tool, one CLI, one `--check`: `python3 -m tools.render brief|claims|board|heatmap [--check]`.
  `render brief` rewrites the region between `<!-- status:begin -->` / `<!-- status:end -->` in
  `docs/BRIEF.md` from `status.json`; `--check` fails if stale. Wired as a CI step. This is not the
  document-checking QUALITY.md bans; it is codegen with the gate already trusted. Folding the four
  renderers into one tool is deliberate: they are the same function — `status.json` in, a document out —
  and four scripts would be four places to drift.
- `docs/BRIEF.md` — the Gates, ratio, and unpushed-count sections become the generated region; the "What
  was learned" section that five documents say exists gets written, once, as a template.
- `docs/WORKING.md` — reset to the ≤150 lines it promises: **measured** 1,239 lines today, seventeen
  CLOSED sections; they move to `docs/archive/working/2026-08-2x.md`. `status.py` prints the line count as
  a metric, visible, not gating.
- `render claims` — renders `claims/*.md` frontmatter into `docs/CLAIMS_BOARD.md` (status, kind, last
  measured, first failed, value, threshold); `--check`. Reuses `check_claim_references.parse_frontmatter`.
  It will show four rows of "never" — a table of never is the honest state until phase 4, and this is a
  markdown table, not the board.
- `tools/anvil/append.py --from-status status.json` — emits one MEASUREMENT event per CI run. The schema
  has had that type since day one and no instance has ever been written. Machines write the log; people
  stop. If you would rather delete the anvil, delete it here — but this is the version where it finally
  sources something.

**Removes.** Hand-typed gate verdicts, ratio lines, unpushed counts; WORKING.md as a log; hand-appended
anvil events; the "regenerated" BRIEF that had no generator. **Adds a service?** No — one generator with
`--check`, same shape as the one you have.

**Done when.** Editing a verdict by hand in BRIEF fails CI; `git log -p -- docs/BRIEF.md` shows only prose
changing between rounds; WORKING.md is under 150 lines on three consecutive wraps.

#### 3. Print the population — *est. two days · +≈200 lines*

**Goal.** No sweep reports a count without the distribution it was measured over. This is the audit's
"next hidden failure" turned into a printed number before it bites — and it is the precondition for the
bisect meaning anything.

**Files**

- `tests/fixture_body_fuzz_probe.gd` — per-seed `FUZZ_COVERAGE seed=N excavated_cells=K x_min= x_max=
  y_min= y_max= grounded_ticks=`; a `--fresh-grid` flag that rebuilds the chamber per seed. **measured**
  `bounds` violations rise 132→230→256→312 per ten-seed bucket on the shared grid; the two modes are two
  different subjects.
- `tests/test_body_fuzz.gd`, `test_body_fuzz_fast.gd` — every bound becomes two bounds, intact chamber and
  decayed chamber, each with a population line; a run whose coverage envelope moves more than a stated
  tolerance reports PARTIAL, not PASS. Ledger entry stating what 59 is a count of.
- `tests/test_body_acceptance.gd` — replace the two self-reported metrics (`edge_catch_events`,
  `depenetration_events` count flags the subject sets about itself at `horizontal_resolve.gd:80`/`:62`)
  with oracles derived from grid geometry: an edge catch is "blocked with a walkable step available",
  computed from the chamber, not from the body's own flag.

**Removes.** The fuzz allowlist as a bare number; two acceptance metrics that cannot fail; the argument
about whether 59 is "the D0059f mechanism". **Adds a service?** No — extra print lines and a flag on a
fixture that exists.

**Done when.** The nightly sweep prints two tables; `grounded_no_floor` on a fresh grid is a number you
have seen; the coverage lines exist so that half two's heatmap is a rendering, not a new measurement.

#### 4. One measured claim — *est. one hour of the director's time · +≈60 lines*

**Goal.** The instrument produces a verdict. Everything in half two is a projection over this and phase 3;
without it, half two is a status board over zero measurements.

**Files**

- `tests/body/debug_scene_common.gd` — the recording header names its columns
  (`# fields: tick,move_dir,jump_pressed,jump_held,mantle_hold,dig_pressed`); `RevealReplayDriver.parse_log`
  validates names, not `fields.size() == 5`. Fixes the two dialects D0140 found before the first real
  recording is made in the wrong one.
- `tests/body/recordings/play_<ts>.log` — one session on `reveal_test_dense`, then one on sparse.
  Committed.
- `claims/C004-reveal-raises-dig-persistence.md` — a History row with the measured `dig_rate_lift`, the
  commit, and an honest note on which came first per CLAIMS §10b. If it is born passing, say so; the rule
  for that case exists.
- Anvil `CLAIM_AUTHORED`/`MEASUREMENT` events written by the driver, not by hand.

**Removes.** "Never measured" as the corpus's only value. **Adds a service?** No.

**Done when.** The claims board shows one number with a commit next to it.

#### Half one as a fold-in table

| Item | Removes | Depends on | Phase here |
|---|---|---|---|
| Branch protection requiring harness green | Direct push to red main | — | 0a |
| CI runs `tools/**/test_*.py` | 50 mutation tests that run nowhere | — | 0a |
| `run_gd_test.sh` fails on engine `ERROR:` | A green over a core error | — | 0a |
| commit-msg requires a new ledger header | A touched ledger passing as a written one | — | 0a |
| Size gate covers `tools/*.py` | Four files over the limit the gate can't see | — | 0a |
| Archive ten legacy docs | 4,622 lines of prose describing a deleted game | Inbound-link grep; independent re-read | 0b |
| Delete `tools/economy_check/` | 1,066 lines checking zero files | 0a's exemption | 0b |
| Tag, then prune worktrees; stashes to branches | Five worktrees and three stashes no doc records | Your ruling naming which | 0b |
| `verdict.py`: five verdicts, population, VOID on empty | Three vacuous greens | — | 1 |
| `status.py` reading `harness.yml` as the list | The second gate list; hand-typed "all PASS" | `verdict.py` | 1 |
| QUALITY.md gate → CI step map, UNENFORCED printed | "Every gate is CI-enforced" | `status.py` | 1 |
| `render brief` with `--check` | Typed verdicts, ratios, counts in BRIEF | `status.py` | 2 |
| WORKING.md reset; CLOSED sections archived | ≈1,000 lines of log in a "current state" file | — | 2 |
| `render claims` (markdown) | Hand-summarised claim status | — | 2 |
| Anvil MEASUREMENT written from `status.json` | Hand-appended events; a log with no writer | `status.py` | 2 |
| Fuzz per-seed coverage + `--fresh-grid`; two bounds with populations | A count over an undefined population | — | 3 |
| Geometry oracles for edge-catch / depenetration | Two metrics that cannot fail | — | 3 |
| Named recording header; one recorded session; C004 History row | "Never measured" | Your hour at the keyboard | 4 |

## The gate between the halves

Nothing below starts until all three are true. Each is a command, not a judgment. If a half-two item is in
progress while one of these is false, the plan is being read as a menu, and the audit already showed where
that leads: an economy checker for no economy, a replay-determinism test for a stub, a fuzz bound over a
chamber nobody had described.

1. **The foundation is honest.** `main` is protected; `status.py` on HEAD reports no FAIL, and every VOID
   carries a declared reason. — `python3 tools/status.py --brief` — zero FAIL rows; zero VOID rows without
   a note
2. **The fuzz numbers have a population.** Both sweeps print coverage; every bound names intact or decayed
   chamber. — `grep -c FUZZ_COVERAGE` on a sweep log equals the seed count; `test_body_fuzz.gd` asserts
   against two labelled bounds
3. **One human session and one measured claim exist.** — `git log --oneline -- tests/body/recordings/` is
   non-empty; `claims/C004` has a History row with a commit and a value

Why the line is this hard: the bisect below is a time machine over per-tick state. If condition 2 is false
it navigates a lie with perfect precision. If condition 3 is false the board is a page of "never" with
tooltips.

## Half two · earned, not scheduled

### What the foundation pays for

These are projections over data that half one made real. They are the demo — and the reason they impress
is that the substrate underneath is byte-deterministic sim + logged input + a per-tick hash, which is the
project's thesis paying out, not a decoration on it. Built before the gate, the same code is a liability.

#### 5. Determinism made real, then bisect — *est. three days · +≈400 lines · after the gate*

**Goal.** Gate 8 tests the sim, cross-platform determinism is checked on every push for free, and a fuzz
violation becomes a two-minute command instead of a seventeen-entry investigation. Order inside the phase
matters: determinism first, bisect only once the hashes agree.

**Files**

- `sim/body/body.gd` — `state_signature()` over the twelve state fields (the auditor's probe used exactly
  this; ≈10 lines).
- `tests/test_replay_determinism_sim.gd` (new) — real ShaftGenerator + TileGrid + Body with jumps,
  mantles, digs; 20,000 ticks; hash every 100; run in two processes via `OS.execute`; a seed+1 control
  that must diverge at checkpoint 0. Replaces the stub as gate 8's subject; the stub stays as the mechanism
  test it always was.
- `tests/golden/state_hashes/<episode>.txt` — committed hashes from macOS; CI on Linux compares. The one
  open determinism question (`lerpf` under FMA on arm64 vs x86-64) gets answered on every push,
  permanently. `tests/golden/` finally holds a golden.
- `tools/bisect.py` (new, ≈150 lines) — `--episode <log> --tick N --good <sha> --bad <sha>`:
  `git worktree add` per probe commit, headless replay to the tick, compare the hash, binary search, print
  the first diverging commit and the diverging field. Git bisect over commits and ticks at once. Almost
  nobody has this, and it is only ≈150 lines because everything it needs already exists.
- `tests/body/replay_reveal_scene.gd` — `--at-tick N --highlight grounded_no_floor`: opens the episode
  paused at the tick with the failing invariant's cells outlined. The visual half of the demo.

**Consumes.** Episodes (phase 4's header fix), populations (phase 3), status VERDICT lines (phase 1).

**Retires.** The stub as gate 8; "determinism proven only against core plus a stub" in C003; hand-traced
tick dumps in the ledger.

**Done when.** `bisect.py` localises seed 605 / tick 844 to a commit without a human reading a trace; the
Linux and macOS hash files match.

#### 6. The board, the heatmap, the nightly cold read — *est. three days · +≈360 lines · after the gate*

**Goal.** One static page that is the projection of everything above — the thing you open in an interview
instead of explaining the ledger — plus the two pictures that make the method visible.

**Files**

- `render board` (`tools/render/board.py`, ≈250) → `docs/board.html`, published as a CI artifact (or
  Pages). Sections: the gate table with verdict, assertion count, population per row; the claims with a
  sparkline per value over commits (read from the anvil MEASUREMENT events — the log finally has a
  reader); the fuzz heatmap; the ratio trajectory; worktrees and sessions. Every number carries a tooltip
  with the command, commit, and timestamp that produced it. No server, no JavaScript beyond tooltips, no
  live anything — a pure function from `status.json` history to one file, per your own deferred-console
  rule.
- `render heatmap` (`tools/render/heatmap.py`, ≈60) — phase 3's `FUZZ_COVERAGE` lines → a PNG of where 1.5
  M ticks were spent and where violations cluster; committed to `history/` as the first image of the
  method story. The moment to do the cull: **measured** 168 images against a cap of 12.
- `.github/workflows/harness.yml` — the existing `fuzz_nightly` job grows into the nightly cold read:
  `status.py --full`, fresh-grid and shared-grid sweeps, the real-sim replay, the cross-platform hash
  compare, board upload. `.claude/commands/cold-read.md` reads that artifact instead of re-deriving it. The
  auditor stops being a person you hire and becomes a job that runs at 06:17.

**Consumes.** `status.json` history (phase 1–2), MEASUREMENT events (phase 2), coverage lines (phase 3),
C004's row (phase 4), hashes (phase 5).

**Retires.** **measured** the 2,882-line mandatory read as the way to learn what is true; the audit just
performed as a bespoke event.

**Done when.** A stranger can answer "what is red, what is void, what has been measured" from one page in
under a minute, and hover any number to see how to reproduce it.

## Synergistic additions

Each chosen because it exploits a property the project already paid for — determinism, logged input, the
claim format, the fuzz infrastructure — rather than adding a new kind of thing. Every card answers the
same question the demos are held to: does the subject exist in the tree now? If yes and it removes a list
or a leak, it is foundation-side. If yes but it is a page over real data, it is earned and waits for the
gate. If the subject does not exist yet, it is parked with a named trigger — the same ledger treatment the
economy checker should have had.

New files this plan creates, in total: `tools/verdict.py`, `tools/status.py`, `tools/render/`,
`tools/bisect.py`, `tests/body/scene_driver.gd`, `tools/session.sh`, a `justfile`. Seven, against
1,066 + 204 + 337 + ≈350 lines removed.

### Foundation-side: subject exists, removes something

- **One scene driver.** `tests/body/scene_driver.gd` with `--chamber hostile | --site reveal_test_dense`,
  `--play | --agent | --replay <episode>`, `--screenshot-tick`, `--at-tick`. Replaces `play_scene.gd`,
  `reveal_scene.gd`, and `replay_reveal_scene.gd`. **measured** the first two share nine function names
  the exact-match duplication gate cannot see. One recorder, one parser, one renderer — and the dialect
  bug becomes impossible rather than fixed. *Subject: three scenes in the tree. Trigger: phase 4 (one
  writer for the recording). Size ≈ −350 net. Adds a service? No.*
- **Mutation matrix in CI.** Each gate ships a `mutants/` directory of fixtures it must FAIL on. CI runs
  every gate on the clean tree (expect PASS) and on each mutant (expect FAIL) as a matrix; `status.json`
  gains a field per gate: observed failing this run. "A check that has never been observed failing is not
  a check" stops being a sentence in QUALITY.md and becomes a row per gate, every push. Bounded: the five
  existing `test_*.py` files are the seed, and a new mutant is written only when its gate is next touched
  — never as a sweep across all gates, which would be an instrument-writing spree with the audit's own
  signature. *Subject: the gates, and 50 existing mutation tests. Trigger: phase 1 (needs VERDICT lines).
  Size ≈ +120, fixtures as touched. Adds a service? No — a CI matrix.*
- **Session worktrees, mechanised.** `tools/session.sh start <name>` creates a worktree and branch;
  `status.py` lists live sessions and which produced HEAD; `/wrap` refuses to report unless the branch is
  merged with CI green. **measured** two sessions committed into this checkout during the audit and the
  working tree carried three sets of uncommitted work. Your peer-session rule already says this; the
  script makes forgetting impossible. *Subject: two sessions in one checkout, measured. Trigger: phase
  0a–1. Size ≈ +60. Adds a service? No.*
- **One command to run anything.** A `justfile` (or Makefile): `just check` (status), `just test`,
  `just fuzz-fast`, `just play`, `just reveal`, `just replay <log>`, `just board`. CONTRIBUTING.md rewritten
  to the real steps, which then collapse to three. **measured** today four of eleven onboarding steps are
  documented, in a file whose first line says it describes the wrong codebase. *Subject: eleven
  undocumented steps. Trigger: phase 1. Size ≈ +40. Adds a service? No — removes tribal knowledge.*
- **Cell/pixel helpers and a leak report.** `Fx.cell_to_px(col)`, `Fx.px_to_cell(px)` — the public
  conversion D0141 already asks for. The leak count of raw `* CELL * Fx.SCALE` arithmetic outside `core/`
  is not a new script: it is one metric line in `status.json` (`raw_cell_px_sites_outside_core`), so it
  trends on the board without adding a tool. **measured** 89 sites in `tests/`, 30 in `sim/`, 21 files
  calling `Body._px_to_cell`. The seam exists by convention; this makes it exist by API. *Subject: 119 raw
  sites, measured. Trigger: any time; cheap. Size ≈ +30, then a slow migration. Adds a service? No.*

### Earned: after the gate

- **Claims runner skeleton.** `experiment/claims_runner/run.py`: read `claims/*.md` frontmatter → resolve
  its Episode(s) → invoke the replay driver → compute the named metric → append a History row and a
  MEASUREMENT event. C004 becomes `run.py C004`. L4 gets its first real file, and it is a projection over
  things that exist. Written only after phase 4 has been done by hand once, so the skeleton fits a
  measurement that happened rather than one that was imagined. *Subject: one measured claim (gate
  condition 3). Size ≈ +120. Consumes claim frontmatter; the replay driver.*
- **Corrections index.** `render corrections` → `docs/CORRECTIONS.md` (generated, a fifth renderer in the
  same tool): parse `resolves`/`corrects`/`supersedes D0NNN` in the ledger and render what was claimed,
  what falsified it, and with which evidence — with a rule that a correction must link the origin entry.
  **measured** today's corrections stop at D0127/D0128 while the claim originated in D0059–D0061. The
  "when we were confidently wrong" page a staff reader asked for. The ledger is real data, so this could
  go earlier — it sits here because it is a page, not a fix. *Subject: 140 ledger entries, real. Trigger:
  phase 2 or later, as `render corrections`. Size ≈ +90. Consumes the ledger's link convention.*

### Parked: subject not in the tree yet

Each carries the trigger that un-parks it. Building one before its trigger is the economy-checker mistake
with a new name.

- **Envelope conformance, fuzzed.** The CONSTRAINED envelope hands out the material of undug rock inside
  its radius, so it cannot measure the discoverability it exists for. Once visibility is defined — say,
  cells the body has excavated or stood adjacent to — the fuzz probe drives random walks and asserts every
  tick that `ObservationBuilder` never returns a cell outside that set. The builder is code; the
  definition is not: it is the dropped Codex finding awaiting your ruling (BRIEF, "Blocked"). A property
  test against an unruled definition would test the wrong thing with confidence. *Subject: builder yes;
  definition no. Trigger: your ruling on what CONSTRAINED means. Size ≈ +90 when it comes.*
- **Float-on-state-path lint.** An advisory report listing every `float(`, `lerpf`, `/ float` in `sim/`
  with a named whitelist. Today that list is terrain generation's cave carving and
  `SplitRng.next_range`, while `core/MODULE.md` says "pure fixed-point integer math". But phase 5's
  cross-platform hash compare is the real test of that sentence: if Linux and macOS hashes match, the
  floats did not matter; if they differ, this lint tells you where to look. So it waits for the stronger
  instrument to speak first. *Subject: float sites yes; a divergence no. Trigger: a phase-5 hash mismatch.
  Size ≈ +80 when it comes.*
- **Episode as the save format.** Stage 6's open question ("what does starting a session even mean") has
  an answer the instrument already needs: a checkpoint is an Episode prefix plus the tick to resume at,
  re-derived by replay. Saves, fixtures, and forks become the same file, and save/load determinism is
  tested by the same hash the bisect uses. Versioning is the input-log schema, one place. There is no save
  today and no session to start; this is a note for the ADR, not a build. *Subject: none yet. Trigger:
  stage 6. Size design, then ≈ +150.*
- **Perf probe that knows when to shut up.** ARCH §10's sim-tick budget as a benchmark Episode, reported
  through the VERDICT line with VOID on a contended host — a calibration loop that measures its own jitter
  first, the rule QUALITY.md gate 19 states and nothing implements. Advisory until the numbers are stable
  across ten nightly runs, then a bound with a stated population. Today one body ticks one grid; there is
  nothing to budget. *Subject: none yet. Trigger: the first tick that has 2,000 machines in it. Size ≈
  +120 when it comes.*

## What this retires

| Gone | Lines | Replaced by |
|---|---|---|
| Ten legacy-describing docs in `docs/` | 4,622 | `docs/archive/` with dated headers (phase 0) |
| WORKING.md's seventeen CLOSED sections | ≈1,000 | `docs/archive/working/`; later the board (phase 2) |
| `tools/economy_check/` | 1,066 | Nothing, until `data/economy/` exists (0b); then a checker written against real files, with a feasibility check, not a shape check |
| `tools/check_fork_completion.py` + test | 204 | One line in `wrap.md`; sessions on branches make it moot |
| `coupling.py`, `dashboard.py` | 337 | The board (phase 6); coupling returns when there are more than four modules |
| Three near-duplicate scenes | ≈350 net | One scene driver |
| `wrap.md` step 7's enumeration; hand-typed BRIEF verdicts; hand-appended anvil events | — | `status.py`, `render brief`, machine-written MEASUREMENT events |

*est.* Net through phase 3: roughly −5,600 lines of docs and −1,600 of tooling against +850 of tooling.
The ratio the gate measures barely moves — fine; the ratio was the symptom. What moves is the number of
places a person can type a falsehood: from about a dozen to zero. Half two then adds ≈ +760 lines, all of
it consuming data that exists.

## Guardrails for the plan itself

- Each half-one phase removes something, or it does not merge. Written into its ledger entry as a line:
  "removes: …".
- Additions face the same question as demos: does the subject exist in the tree now? The answer is a file
  path in the ledger entry, or the item goes to Parked with its trigger.
- 0b is verified differently from 0a. 0a is "does it fire" (mutation-test it); 0b is "did anything
  load-bearing move" (an independent re-read). One report per phase, never both kinds in one.
- The gate is three commands, not a feeling. A half-two branch opened while any condition is false gets
  closed, and the ledger records which condition.
- No new gate without a mutant and a population. The VERDICT line is the contract; a gate that cannot
  state its population goes in as VOID until it can.
- Estimates are estimates. When one is off by 2×, that is a ledger finding, not a reason to stretch the
  phase.
- Stop conditions carry over from `/loop`: any EXPENSIVE decision (the save format, the envelope
  definition, changing what `grounded_no_floor` counts) is a hard stop for the director's ruling, not a
  session's call.
- Reversibility: every phase is additive scripts plus archive moves; the only hard-to-reverse item is the
  branch rule, and it is a settings toggle.

## Do not build

- A doc-drift checker. The ban is right. Generate the parts that rot; leave the prose to people.
- A live dashboard, a server, a database, a queue. The board is a file produced by a function; the log is
  JSON in git. "Markdown and git only" survives this plan intact.
- A second event schema. The anvil's seven types are enough once machines write MEASUREMENT; if a type
  has no writer after phase 6, delete the type.
- More skills that restate lessons. Two skills that call scripts — `/wrap` running `status.py`,
  `/cold-read` reading the nightly artifact — and nothing that asks a session to remember a population.
- Any instrument for a system with no lines of code — transport, fluid, economy, machines. The checker
  gets written the week the data file does, against the data file.
- The bisect, the board, or the heatmap before the gate. Same code, opposite meaning.

Everything on this page is a recommendation; nothing was changed in the repository. The audit it responds
to is the cold-read page from the same session.
