# Sinkforge — full onboarding handoff for an agent that knows nothing

**Written 2026-09-11 by the Claude Code session that has been the primary implementer.**
**Pinned: `main` = `db3572128c992445012487eba933f199f4110662`.** An unmerged branch,
`trees-footing-and-crowns` = `916bac867ccff6952c3cf7171b045d4636017988`, is in flight behind draft PR #52
(see §12). Every number in this document was measured against one of those two trees on the date above,
by running the command named beside it. If you find a number here that disagrees with the tree, the tree
wins and this document has drifted — say so, loudly, because that is exactly the failure class this
project is built around.

---

## 0. What this document is, and the one rule for reading it

You are being onboarded cold onto a repository with **1,745 commits, 600 ledger entries, 37 declared
quality gates, 157 test suites and about 72,000 lines of GDScript** across game and instrument. Nobody
expects you to hold that. This document exists so you can get to *useful and not dangerous* fast.

**The one rule: this document is a map, not a source of truth.** Every claim in it is re-checkable, and
§4 tells you exactly what to read to check it. The project's central discipline — the thing it has spent
six hundred ledger entries learning — is that **a stated fact and a measured fact are different objects,
and the gap between them is where every real defect in this project has lived.** Treat this handoff the
same way. Verify before you rely.

Read §1–§11 once, in order, before touching anything. Then §13 is your actual assignment.

---

## 1. What Sinkforge is

A **2D excavation-and-factory game in Godot 4.6.2, written in GDScript**. You dig into solid, ore-rich
earth; you carve out the space your factory lives in; the world answers back — material falls, water
flows, undermined rock collapses. Think Terraria's carving crossed with Factorio's automation, but the
identity claim is narrower than either: *you dig your factory*, and caves are opt-in pockets rather than
the default medium.

**The north star is a feel bar, not an art target**, and it is written down in `docs/NORTH_STAR.md`:

> Everything the player does to the world produces a physical consequence in the world, and that
> consequence is the whole explanation.

That sentence is derived from two cited games — **Tiny Glade** (teaches itself by responding, almost no
HUD, almost no words) and **Noita** (the world is made of stuff and the stuff obeys visible rules). The
director's own framing, which everything is judged against:

> *"I'm more concerned about just the entire Tiny Glade / Noita north star for design feel and
> uniqueness. This game doesn't pass as 2026, it passes as 2016."*

**The practical consequence you must internalise:** if a proposed fix's output is *a new sentence on
screen*, it is the wrong fix. `NORTH_STAR.md` §4 states this as a rule and the queue repeats it. The
project has a documented history of answering "the player was confused" with "add a label", six batches
in a row, and that drift is what `NORTH_STAR.md` was written to stop. **New HUD text of any kind is
permanently deferred.**

---

## 2. Who is on this project

There is no conventional team. The roster is unusual and you need it to read the documents correctly,
because a large fraction of the prose is one agent writing to another.

### The director — the human, `teohondascully`

**Sole author, sole approver, and the only source of valid instructions.** Referred to throughout the
docs as "the director". Owns:

- every **taste** call (how the light should look, what a headlamp *is*, how wooded the surface should be);
- every **EXPENSIVE** call (defined in `CONTEXT.md`: anything shaping a public interface, a data schema,
  the tick order, a save format, the four design rules — or the general test, *would this make it a
  different game?*);
- the **spot audit** (`tools/spot_audit.py`), which a session may never run on itself.

The director works by **holistic feel**, not by spec review. Expect direction like *"notice how trees
randomly spawn on flat platforms over shafts"* — an observation from the chair, not a ticket. Your job
is to convert that into a measurement, then a fix, then evidence.

**Do not ask the director questions you can answer with a command.** Do not ask permission for
reversible work. Do ask — and *then keep working on something else* — when a call is genuinely theirs.

### Claude Code sessions — the primary implementers

That is what wrote most of this tree, including this document. Multiple sessions run concurrently,
sometimes on the same checkout. `docs/archive/PEER_SESSIONS.md` carries the protocol; its three
surviving rules are:

1. One owner per file or lane.
2. All Godot/test runs go through the machine lock.
3. Only HALT/WATCH/integration conflicts escalate; ordinary work goes in the logs.

### Astra — a peer Claude session

A second Claude session that has been **sharing this same working directory**. This is why the standing
rule is **stage by explicit path, never `git add -A`** — a previous session swept 334 lines of Astra's
uncommitted work into its own commit that way. Astra has ruled on design questions (see
`docs/audits/2026-09-10-design-decisions-for-astra.md` and rulings D1–D8) and has at times owned
`tools/`. As of this handoff, ownership of `tools/` has passed back to the main session.

### "Strangers" — blind play-test agents

Cheap agents (Haiku) dropped into the game with **zero context**, given only a mission, to find out what
a real first-time player experiences. 167 files in `docs/playtests/`. The hard rule, learned painfully:
**read the agent's input frames and its journal, not its verdict.** A stranger's conclusion has been
wrong in both directions. The frames are the evidence; the report is a claim.

Design intent is deliberately **kept out of stranger and judge prompts**. They must discover
opportunities, not echo our intentions.

### "Judges" — blind vision agents

Vision models shown frames and asked what they see. The load-bearing rule, from the ledger: **never ask
a judge which of two images it prefers** — a comparative verdict tracks screen *position*. Ask what it
sees.

### External auditors — and now you

Codex, a "droid" session, and others have been given pinned-hash briefs before
(`docs/audits/2026-09-06-update-for-codex.md` is a template). **`CONTEXT.md` requires that every
external audit names an explicit commit hash**, because local commits routinely run ahead of
`origin/main` and an auditor on a stale clone produces findings indistinguishable from a live
contradiction. That is why §0 pins two hashes. **Every report you produce must state the hash it was
produced against.**

---

## 3. The reading order — exactly what to ingest, and why

`CLAUDE.md` (auto-loaded, 60 lines) names the canonical order. Follow it. Then widen.

### Tier 1 — mandatory, ~1,700 lines, read every word

| File | Lines | What it is |
|---|---|---|
| `CLAUDE.md` | 60 | The pointer file. Deliberately contains almost nothing; its job is to survive context compaction and send you elsewhere. |
| `CONTEXT.md` | 132 | **The operating protocol.** Context discipline, the 5-file rule, review bandwidth, reversibility, the playable-fixture contract. If you read one file, this one. |
| `docs/ARCHITECTURE.md` | 561 | Layers, dependency rules, determinism, the world scale, movement, performance budgets. §3 is the layer rule the linter enforces. |
| `docs/QUALITY.md` | 296 | **The 37 gates.** Note its own opening warning: the list is the *declared* contract, not the current status. |
| `docs/GDD.md` | 343 | Intended design and ruled constraints. The four design rules (R1–R4) live here. |
| `docs/NORTH_STAR.md` | 186 | What it is supposed to *feel* like. Normative for feel. |
| `docs/CLAIMS.md` | 199 | The claim system — the unit of work in this repo. |

### Tier 2 — read before you touch anything

| File | Lines | What it is |
|---|---|---|
| `docs/WORKING.md` | 969 | Current state and the active queue. **Read this every time you resume.** |
| `docs/CORRECTIONS.md` | 989 | **Every claim this project made that turned out to be false, and why it was durable.** This is the highest-value file in the repository for a new agent. Read it cover to cover. |
| `docs/NEEDS_DIRECTOR.md` | 1,582 | 37 open/ruled questions (P001–P046) that only the director can answer. Check here before asking anything. |
| `docs/BRIEF.md` | 494 | The last session's digest, findings-first. |
| `docs/TASTE_QUEUE.md` | 345 | Feel/visual judgment calls, deliberately kept apart from correctness. |
| `.claude/commands/*.md` | — | `handoff.md`, `wrap.md`, `audit.md`, `loop.md`. The four procedures a session runs. |
| `claims/C003-cold-start-reaches-d1.md` | — | Named explicitly by `CLAUDE.md`. Read one claim end-to-end to understand the format. |

### Tier 3 — skim the structure, read on demand

- `docs/DECISIONS_LEDGER.md` — **23,057 lines, 600 entries, append-only.** Do **not** read linearly.
  It is a *lookup table addressed by D-number*. Code comments cite `D0397` and you `grep -n "^## D0397"`.
  Entry numbers are **addresses and are never reused or edited**.
- `docs/adr/` — 10 ADRs for decisions `QUALITY.md` gate 20 requires one for.
- `docs/audits/` — 10 external-audit briefs and closeouts, including the templates used for Codex/droid.
- `docs/archive/` — 41 superseded documents. **Superseded, not deleted, on purpose.** A known trap
  (`[[superseded-draft-above-its-amendment]]`): a doc here can read as current.
- `docs/playtests/` — 167 stranger runs and journals.
- `docs/milestones/`, `history/` (286 images) — visual provenance.
- `legacy/` — **529 files, 86,230 lines of GDScript.** See §6.

### Tier 4 — the code, in this order

`core/` (754 lines) → `interface/` (1,469) → `sim/` (9,797) → `view/` (17,926) → `shell/` (2,398).
Read each module's `MODULE.md` first; there are 18 of them and they are capped at 100 lines by gate 3.
**Read the `MODULE.md` for dependencies and the implementation only for the module you are editing** —
that is the 5-file rule, and it is an architectural constraint, not a style preference.

---

## 4. The repository map, measured

Run `find <dir> -name "*.gd" | wc -l` and `wc -l` yourself to confirm any of this.

```
core/        19 files    9 .gd      754 lines   pure math, no engine types, no game concepts
data/        83 files    8 .gd    1,262 lines   YAML records + generated .gd; a MODELLED LAYER (ADR 0008)
sim/        147 files   65 .gd    9,797 lines   the simulation. 16 modules, each with a MODULE.md
interface/   21 files   10 .gd    1,469 lines   L2 — the ONLY route from view to sim state
view/       210 files   97 .gd   17,926 lines   painters, HUD, camera, audio. Largest surface in the repo
shell/       26 files   12 .gd    2,398 lines   app IO, flags, saves, the main scene
tests/   19,435 files  186 .gd   35,667 lines   157 test_*.gd suites + recordings + fixtures
tools/      218 files   45 .gd    2,861 lines   the harness: gates, runners, probes, capture
legacy/     529 files  209 .gd   86,230 lines   the pre-pivot codebase, kept as a SOURCE, not a dependency
claims/       4 files                           C001–C004
history/    286 files                           curated images (policy cap 12, actual 286 — see §11)
```

**Game code ≈ 33,600 lines. Instrument ≈ 38,500 lines.** The instrument is larger than the game. Gate 7
watches the *velocity* of that ratio, not its absolute value, and `QUALITY.md` explains at length why
the absolute ratio is reported but never gated. Read that argument before you propose "delete tests".

---

## 5. The architecture, and the contracts a machine enforces

### The layers and the one rule

From `docs/ARCHITECTURE.md` §3, enforced by `tools/layer_lint/layer_lint.py` at **top-level directory
granularity**:

```
ALLOWED = {
  core:      {}                     # depends on nothing
  data:      {}                     # depends on nothing
  sim:       {core, data}
  interface: {sim, core}
  view:      {interface, core, data}
  shell:     {everything}
}
```

**`view` may NOT reach `sim`.** It goes through `interface/`, which hands it an `Interface.Observation`.
This is the single most load-bearing boundary in the tree and the one most often bumped into: if you
find yourself wanting a sim fact in a painter, the answer is an `Observation` field, not an import.

`data` being readable from `view` was a ruled decision (P013, D0243) with a written argument — read
`ARCHITECTURE.md` §3's subsection before assuming it is a leak.

### The size gates, and the state they are in

- **400 lines hard, 300 warn** per `.gd` file. **50 lines hard** per function. Complexity ≤ 10.
- `data/<kind>/generated.gd` is exempt from the *file* cap only (D0574), by an exactly-three-part path
  predicate. Nothing else is exempt.

**Measure this yourself and look at what it means:**

```
412  data/starts/generated.gd     (exempt, codegen)
400  sim/body/grapple.gd          <- at the cap
400  sim/body/body.gd             <- at the cap
400  shell/main.gd                <- at the cap
400  interface/observation.gd     <- at the cap
399  view/world_view.gd
398  sim/world/tile_grid.gd
398  sim/mining/mining.gd
397  view/visuals/veil_painter.gd
397  view/hud/hints.gd
396  interface/interface.gd
395  view/visuals/bake_window.gd
```

**Six hand-written files sit at exactly 400/400 and a dozen more are within five lines.** This is a
codebase pressed flat against its own ceiling. Adding one line to `observation.gd` is currently a
refactor, and the ledger records features deferred for exactly that reason (P034). **This is the single
clearest structural finding available to you on day one, and §13 asks you to do something about it.**

### Determinism, and why it dominates everything

The sim is **headless, fixed-tick (60 Hz physics), integer/fixed-point** (`core/fixed_point.gd`,
ADR 0003), seeded through `core/split_rng.gd`. Determinism is **gate 8**, and the way it is checked is
worth understanding because it shapes what you are allowed to change:

`tests/test_shaft_replay_determinism.gd` generates a real world, drives a real `Body` through ~20,000
ticks of seeded input **in two separate OS processes**, and compares 200 checkpoint hashes against a
committed golden array in `tests/fixture_shaft_golden.gd`.

Three discriminators must be read off every run, never assumed:

1. **two-process agreement** (first mismatch at −1 means bit-identical) — a failure *here* is the one
   condition in this project that stops all work;
2. **the seed+1 control still diverges at checkpoint 0** — proves the seed drives real varying state;
3. **the golden comparison itself.**

**Any change to world generation moves the golden from checkpoint 0**, and the re-pin must be harvested
from **CI's own pinned Linux build** via a draft PR — never from a developer machine, because macOS and
Linux have measurably diverged in the generator's float paths before (D0167/D0168). The route is
recorded and has been used repeatedly. **Budget a full CI cycle for any world-gen change.** This is why
world-gen changes get batched.

### Scale constants you will need constantly

`1 m = 16 world px = 4 terrain cells`. Play zoom 2.0 → 8 screen px per cell. `SURFACE_ROW = 80`.
`ARCHITECTURE.md` §9 "The world scale (normative)" is the authority.

---

## 6. `legacy/` — the most misunderstood directory here

86,230 lines of the **pre-pivot codebase**, kept in-tree at tag `pre-pivot`. It is **not** a dependency,
**not** dead weight to delete, and **not** something to port wholesale.

It is a **source you copy from**. The standing rule, written into `docs/A_PRIME_REFACTOR_PLAN.md` §1 and
repeated in dozens of ledger entries: **never re-derive what legacy already solved — paste it, then
adapt, and name the legacy file and line you lifted from.** Nearly every painter and generator in this
tree carries a header comment like *"legacy `world_renderer.gd:1596 _cell_tone`"*.

Two hard-won corollaries:

- **Port the architecture, not just the leaves.** Copying a function without its surrounding structure
  has repeatedly reproduced a bug legacy had already fixed elsewhere.
- **A legacy constant often encodes world size as a fraction.** A keepout or spacing of `N` in legacy is
  frequently `N / GRID_ROWS`, and transplanting the literal silently rescales it. Legacy's logic cell is
  **32 px and one metre**; this world's cell is **4 px and a quarter metre**. Frequencies, wavelengths
  and rates must be converted or the authored feature comes out at a quarter of its size.

---

## 7. The document system — what each file is *for*

This project is **event-sourced in Markdown and git**, deliberately. `CONTEXT.md` ends with: *"Markdown
and git only. If this starts to look like a subsystem, say so instead of building it."*

Five documents carry the process, and `CONTEXT.md` explicitly warns that **if a sixth starts to seem
necessary, that is a signal something else should retire.**

| Document | Shape | Rule |
|---|---|---|
| `docs/DECISIONS_LEDGER.md` | **Append-only**, D-numbered | Every judgment call not dictated by a normative doc. Four things: decided / alternative / why / reverse cost. Written **when made**, not at session end. Numbers are addresses — never edited, never reused. Enforced by `.githooks/commit-msg` for any `core/` or `sim/` change; override only with a `No-Ledger-Entry:` trailer. |
| `docs/WORKING.md` | Current state, not a log | Current stage, in flight, open questions. `CONTEXT.md` says **under 150 lines**; it is **969**. See §11. Gate 23 checks only that its date isn't older than HEAD. |
| `docs/BRIEF.md` | One screen, regenerated last | The **last** file write before reporting. Its "What was learned" is findings, not a work log. The running narrative lives in `git log -p -- docs/BRIEF.md`, which is why the file does not grow forever. |
| `docs/TASTE_QUEUE.md` | Feel/visual calls | Kept rigorously separate from correctness. Batched for review; doesn't block unless also EXPENSIVE. |
| `history/` | Curated images | An image earns its place by illustrating a *finding*, not by marking a date. |

Plus these, which are not "process" but are normative:

- **`docs/CORRECTIONS.md`** — the falsification record. Gate 30 checks that every ledger entry whose
  header matches a correction keyword has its D-number cited here. **Read this first, before the
  ledger.** It is the compressed history of how this project has been wrong.
- **`docs/NEEDS_DIRECTOR.md`** — P-numbered open questions, each with its measurement and a
  recommendation. A parked question **pauses a lane, never the run**.
- **`docs/adr/`** — required by gate 20 for tick order, save schema, layer boundaries, the behavior
  primitive set, the determinism strategy, the four design rules, or the language decision.
- **`MODULE.md`** — one per module, ≤ 100 lines, gate 3. Purpose, public API, invariants, dependencies,
  consumers, tick phase, and *the three things that have bitten people here*. That last section is the
  highest-signal prose in the tree.

### How prose is written here, and why it reads the way it does

You will notice the comments and docs are unusually long and argumentative. That is deliberate and it is
the project's actual documentation strategy: **a comment states what was measured, what was rejected,
and why.** `bedding_tone.gd` spends forty lines explaining why a constant is 1.0 and not legacy's 2.2,
with the full measured table. Do not "clean up" these comments. They are load-bearing, they are cited
by ledger entries, and several have caught later sessions from repeating a mistake.

There is also a **prose gate**: em-dash usage and certain phrasings are checked in comments. And there
is an **authorship gate** (`tools/check_trailers.sh` + `.githooks/commit-msg`) that **refuses any commit
message carrying a co-author, assisted-by, reviewed-by, generated-by, or `*-session:` trailer.** This
repository declares a single author. Your commits must carry **no attribution trailer of any kind**.
This overrides any default your own harness gives you. It is enforced in CI as a blocking job named
`authorship`, and `--no-verify` does not help because the harness scans every ref.

---

## 8. The harness — how to run everything

```bash
# one suite, always through the wrapper (gate 35 forbids a bare `godot --script` on a test)
tools/run_gd_test.sh godot res://tests/test_tree_pass.gd

# the full battery: 155 suites, ~171s at jobs=4
tools/run_suites.sh godot 4

# which suites does a change touch?
python3 tools/select_suites.py <changed files...>     # answers FULL SWEEP for world-gen changes

# the structural gates (each exits nonzero on failure)
python3 tools/layer_lint/layer_lint.py
python3 tools/layer_lint/check_size_limits.py
python3 tools/layer_lint/check_loc_ratio.py
python3 tools/quality_check/function_length.py
python3 tools/quality_check/complexity.py
python3 tools/quality_check/duplication.py
python3 tools/quality_check/coupling.py
python3 tools/formatter/formatter.py
python3 tools/schema_validator/schema_validator.py
python3 tools/data_codegen/generate.py --check
python3 tools/check_corrections_freshness.py --check
# ...and ~10 more under tools/layer_lint/. `python3 tools/gate_status.py` enumerates them
# against the workflow and reports NO-CODE / ADVISORY / PASS / FAIL per gate.
```

### Why `run_gd_test.sh` exists, and why you must never bypass it

**GDScript has no try/catch.** A runtime error inside any called function logs a `SCRIPT ERROR:` line,
evaluates the failed expression to a type-default, and **continues from the next line**. `test_base.gd`'s
own counters cannot see it. So a suite can lose half its coverage mid-run and still print `ALL PASS` and
exit 0.

`run_gd_test.sh` wraps every invocation and fails on `SCRIPT ERROR:`, on a bare engine `ERROR:` whose
`at:` line names something other than `push_error`/`push_warning`, and on a missing `ALL PASS` line. It
also runs **positive and negative controls on its own detector every single run**, because a pattern
that silently stopped matching would report a clean run forever in exactly the words a clean run uses.

`test_base.gd` additionally refuses a **vacuous** green: a suite that asserted nothing prints VACUOUS and
exits 1.

### CI

One workflow, `.github/workflows/harness.yml`, five jobs:

| Job | What it is |
|---|---|
| `authorship` | trailer + identity gates. Blocking. |
| `structural gates` | layer boundaries, size limits, LOC ratio, schema, claims, and ~15 more |
| `godot test suites` | determinism, conservation, movement acceptance — the battery |
| `headed boot` | proves the documented `--play` invocation actually opens a window (under `xvfb`) |
| `fuzz nightly` | the full 1000×1500 sweep, scheduled, with an allowlisted residual (D0060) |

**Read the CI *jobs*, not the suite lines.** Three pushes have been green in every suite line while the
`authorship` job was red.

---

## 9. How a session actually works, turn to turn

Four procedures live in `.claude/commands/`. They are written for Claude Code's slash-command mechanism,
but **the procedures are tool-agnostic and you should follow them**.

- **`/handoff`** — run after any context loss. Re-read `CLAUDE.md` and `docs/WORKING.md` *in full*, then
  **verify the repo's actual state against what `WORKING.md` claims** — do the commits it names exist,
  do the files it says landed exist, do the gates it says are green pass *right now*. Then state in one
  paragraph what you are about to do. **If that paragraph doesn't match `WORKING.md`, stop and say so.**
- **`/wrap`** — the end-of-session checklist. Reconcile any subagent's claimed changes *mechanically*
  before anything else; show real diffs, never prose summaries of doc edits; update `WORKING.md`; append
  ledger entries; write `BRIEF.md`'s "What was learned"; regenerate `BRIEF.md` **last**; run
  `gate_status.py`; report.
- **`/audit`** — director-only. A session may never sample its own audit.
- **`/loop`** — drives a director-authored queue to exhaustion. Its governing rule is worth quoting
  because it is the most-violated one: **"a parked decision pauses a LANE, never the RUN."** Two prior
  runs stalled by treating a ruling — or a *report* — as a terminus. **Reporting is not stopping.**

### The tools this session has had

For calibration, since yours will differ: a shell (`Bash`, including background processes and
`Monitor`-style watches), file read/write/edit, a persistent file-based memory directory, subagent
spawning (used sparingly and only when asked), web fetch/search, and artifact publishing. **No IDE, no
debugger, no interactive process.** Everything is CLI and file IO.

Two environment facts that matter regardless of harness:

- **The harness is not concurrency-safe.** A machine lock is mandatory; running the full battery beside
  five other Godot processes saturates the machine and every worker hits its watchdog.
- **A headed Godot run takes the director's screen.** Captures must be announced. And as of this
  handoff, a headed capture launched from a background shell can block indefinitely in AppKit's
  `_DPSNextEvent` — **zero ticks run**, while looking like a slow run. `sample <pid> 3` diagnoses it in
  five seconds. `--headless` is *not* the fallback: D0190 records that the headless renderer writes
  blank frames and reports success.

---

## 10. The epistemics — **this is the section that matters most**

This project's dominant failure mode is not bad code. It is **an instrument that cannot register its
subject**, and it always arrives as a **quiet green**. `docs/CORRECTIONS.md` is 989 lines of this. If you
absorb nothing else from this handoff, absorb this section.

### The house rules, each paid for

**1. Mutation-test every new guard.** Reaching a check is not the check firing. Break the thing the guard
watches and confirm *that specific guard* goes red — and that it is the only one that does. A guard that
fires on nothing is a comment.

**2. A green mutation is the finding.** In the most recent session, six mutations were run on a new
feature; four fired loudly and one passed the entire 32-assertion suite. That one — *every tree wearing
the same crown* — was the exact defect the test had been written to catch. The test had been measuring
trunk height, then the neighbouring tree. **Two loud mutations make the third look covered.**

**3. Every early return is a pass.** Ask of every error path and every fixture that failed to pose its
subject: *does that path return the passing value?* It usually does.

**4. Invariance claims pass by construction when the subject is gone.** "Same", "stable", "idempotent",
"unchanged" — all trivially true of nothing.

**5. Delete the subject and re-run before theorising about spread.** A control that travels inside the
measurement beats one run beside it.

**6. Measuring a function is not measuring a picture.** In one night, **four separate claims about how
the game LOOKS, all made without rendering a frame, were all wrong** — and *each was green under a
complete, honest suite*. The grass painter drew nothing for every call (a native assert failed silently
and the API returned void). The starfield had never once been drawn (sub-pixel radii, and placed in a
47 px band behind the trees) while `visible_stars()` faithfully returned 42 positions. The remedy now
in force: **split the data a painter hands the engine into an assertable pure function, and open every
painter test with a control proving the fixture registers its subject at all.**

**7. Name the frame.** A number describes the conditions that produced it until those conditions are
stated. Window focus, occlusion, machine load and parallelism have all inverted results here.

**8. Read the count, not the rate.** A rate normalised by the thing you are changing pays a candidate
for being large. And a rate computed from an elapsed time over a loop that never advanced is not slow —
it is zero.

**9. Two instruments are not a cover.** Reconcile the *population*: every exit path counts, and the
counters must sum. "Equal counts, different sets" is a real, recorded incident — two runners both
reported 107, and the sets differed by four each way.

**10. Scrutiny asymmetry.** A number is most dangerous while it is *changing*. Corrections feel verified
because they were effortful. In this project a correction has itself been wrong more than once — an
orphan count went 7 → 6 → 9, and the "6" was the confident middle step.

**11. A completion claim is not evidence.** A subagent reported `completed` with a detailed summary
while its diff touched neither target file. `/wrap` step 1 exists solely to make that check mechanical.
The mirror also holds: six workers reported *failed* while having produced complete reports. **Check the
artifact.**

**12. `git checkout --` restores from HEAD, not from your uncommitted work.** This has destroyed
in-progress work twice in one session, once deleting the very function under test so the suite failed
with an `AttributeError` that reads exactly like a fired guard. **Copy to a scratch path before
mutating, and print a witness that the subject still exists after every restore.**

### Language- and engine-specific traps

- **`Array`, `Dictionary` and `Callable` compare `!= null` as TRUE in GDScript.** A null guard on one is
  a guard that cannot be false.
- **`--check-only` prints `Parse Error` and exits 0.** Grep the output; never trust `$?`.
- **Naming a function `_set`, `load` or similar fails at *parse* time** with an engine-signature clash.
- **`.sort()` over `StringName`s is pointer order** — creation order, not alphabetical.
- **`draw_multiline_colors` asserts `colors.size() * 2 == points.size()` in native code** — a mismatch
  draws nothing, logs nothing your suite sees, and exits 0.
- **A `_test_*` containing `await`, called without `await`, reports ALL PASS with the count taken
  *before* it ran.**
- **`git grep -E` silently drops `\b` and `\s`** — a control that cannot fail.
- **`| grep -q` plus `pipefail` returns 141 *because* it matched**, on early matches only.
- **The repo defines luma both ways across 27 sites.** It has flipped a result's sign.

---

## 11. Drift you can find on day one

These are real, current, and I am handing them to you deliberately rather than fixing them, because how
you handle them tells us something. **Verify each before acting** — some may have a documented reason I
have not found.

1. **`docs/WORKING.md` is 969 lines.** `CONTEXT.md` specifies "Under 150 lines" and describes it as
   "current state, not a log". Gate 23 only checks its *date*. Either the rule is dead or the file is.
2. **`docs/` holds 28 top-level `.md` files.** `CONTEXT.md` says five documents carry the process and
   that a sixth is a signal something should retire. Which of the 28 are live, which are zombies?
3. **`history/` holds 286 images against a stated policy cap of 12**, set 2026-08-25 and never applied.
   `history/README.md` says the cull is the director's own call — so this is a *documented* deviation,
   which is different from drift. Tell the two apart.
4. **Six hand-written files at exactly 400/400** (§5). Features have already been deferred because of it.
5. **157 `tests/test_*.gd` on disk against 156 `res://tests/test_` references in the workflow.** Gate 31
   exists precisely to catch a suite that runs nowhere. Reconcile the two *sets* — not the counts.
   (Counts differing by one may be a `test_base.gd`-style exemption; find out, don't assume.)
6. **Gate 14 declares ≥ 85% line coverage and has no enforcing code** — GDScript has no coverage
   instrumentation. Gate 33 reports a weaker name-reference proxy, ratcheted at 61.8%, reported-only.
   `QUALITY.md` is honest about this. Is the right answer to build the missing instrument, or to delete
   the declaration?

---

## 12. Current state — brief, and deliberately not your focus

`main` = `db357212`, tree clean, local battery 155/155 suites plus gates, all CI jobs green.

One branch is in flight: `trees-footing-and-crowns` (`916bac86`, draft PR #52). It fixes a defect the
director reported from the chair (trees were being planted on one-cell crusts over sinkhole mouths,
because the footing was tested at one column and one cell while the trunk is two columns wide) and
replaces the single canopy ellipse every tree in the world shared with six lobed crowns. Battery 154/155
— the single red is the determinism golden, which any world-gen change moves by design, and the PR
exists only to harvest the re-pinned hashes from CI's Linux build.

Open for the director: **P044** (dead-flat layer contacts), **P045** (whether P044 should ride the
re-pin the trees are already paying for), **P046** (tree density after the fix), **P042** (two-thirds of
crafting content is unreachable), **item 51** (the lamp's colour).

**Do not make this queue your focus.** §13 is the assignment.

---

## 13. Your assignment

A **full-repository revamp**: optimisation, clean-up, modularisation, and a hard look at whether the
quality regime is aimed at the right things. The director's framing is that this is a **stretch test** —
we want to see what a completely fresh agent finds when it reads everything without our assumptions.

### Phase 1 — Ingest and reconcile (do not write code)

Read Tiers 1 and 2 in §3 completely. Then, for each of the 37 gates in `QUALITY.md`, answer from the
tree rather than from the prose: **does enforcing code exist, does CI run it, and can it fail?**
`tools/gate_status.py` gives you the first two. The third is yours — pick the gates that matter and
mutate something to see them fire. The project's own history says several gates have been declared with
no code, and at least one ran somewhere nobody looked.

**Deliverable: a reconciliation table.** Gate number, declared claim, enforcing file, CI step, and your
verdict — ENFORCED / ADVISORY / NO-CODE / CANNOT-FAIL.

### Phase 2 — Structural survey

- **The 400-line ceiling.** Six files at the cap. Propose decompositions that respect the layer rule and
  the 5-file rule. For each, name the *concept* the extracted file owns — this project forbids `utils`,
  `helpers`, `common`, `manager`, and "one concept per file, filename equals concept" is a stated rule.
- **`view/` is 17,926 lines, over half the game code**, and has the loosest structure (no `MODULE.md`
  under `view/`, unlike `sim/`'s 16). Is that a real asymmetry or a gap?
- **Coupling and duplication.** `tools/quality_check/duplication.py` and `coupling.py` already exist and
  pass. Do they pass because the tree is clean, or because they cannot register their subject? Mutate
  them.
- **The `interface/` bottleneck.** `observation.gd` at 400/400 is the single channel from sim to view.
  Is the right answer to split it, or is the channel itself the wrong shape?

### Phase 3 — Performance

A five-pass performance programme ran and was closed; `docs/PERF_PLAN.md` and
`docs/audits/2026-09-08-performance-programme.md` carry it. Known live facts: a 417 ms frame was traced
to chunk repaint inside `_draw` while the frame meter's own `draw=` field read 0.8 ms; the minimap now
repaints only changed cells; presentation interpolation exists behind `--interpolate`, off by default.
**`tools/perf_fixture.py` refuses to report on an unsuitable host — a contended machine yields VOID, not
PASS.** Respect that; do not "fix" it into reporting.

### Phase 4 — The meta-question, which is the real ask

The director's words: *"a fresh way of thinking about our problem solving approaches to understand where
we are misunderstanding ideas in every aspect of this development and harness process."*

Concretely, argue a position on each of these, with evidence from the tree:

1. **Is the instrument/game ratio (38,500 : 33,600) a problem or a feature?** `QUALITY.md` was written
   after a prior codebase where instrumentation grew 90% in five days while the game grew 9%. Has this
   one repeated that, or genuinely avoided it?
2. **Is the ledger working?** 600 entries, 23,057 lines, append-only, addressed by number. It is cited
   constantly from code comments. But is it *read*, or only *written*? What would the cheaper thing be
   that captured the same value?
3. **Is the correction record the actual product?** `CORRECTIONS.md` may be the most transferable
   artifact in this repository. Does its structure generalise, and is anything preventing the same
   mistakes recurring in a form it doesn't match?
4. **Is prose-heavy code the right call?** Comments here routinely run 40 lines with measured tables.
   Argue for or against, from the evidence of whether they have actually prevented repeats.
5. **Where is the harness measuring the wrong thing entirely?** This is the highest-value output you
   could produce. The project's own answer, four times in one night, was "everything about how it looks".
   Find the next one.

### How to deliver

- **Everything against a pinned hash**, stated in every report.
- **Nothing reversible needs permission; nothing EXPENSIVE proceeds without the director.**
  `CONTEXT.md` defines both. When unsure, it is EXPENSIVE.
- **A ledger entry for every judgment call**, in the same commit for anything touching `core/` or `sim/`.
- **Stage by explicit path. Never `git add -A`** — another session shares this checkout.
- **No attribution trailer on any commit.** CI has a blocking job for it.
- **Full battery before any push**, and read `grep -c '^PASS'` and every `^FAIL`, not the tail.
- **Findings before fixes.** A big-bang refactor PR is the worst possible shape here. Land the
  reconciliation table first; let the director route from it.

---

## 14. What would make this handoff a failure

Named so you can avoid them:

- **Proposing fixes before the reconciliation table exists.** Every prior session that skipped
  measurement produced a confident wrong answer, and four of them in one night were about pixels.
- **Deleting instrument because the ratio looks bad.** Read `QUALITY.md`'s argument first.
- **"Cleaning up" the long comments.** They are cited, load-bearing, and have caught repeats.
- **Treating `legacy/` as dead code.** It is the source you are supposed to copy from.
- **Taking a green suite as evidence.** It is evidence that a suite ran. Whether it could have failed is
  a separate question and usually the only one that matters.
- **Reporting and stopping.** Reporting is not stopping. Take the next item.

Welcome. The tree is honest with you if you interrogate it, and it will lie to you politely if you don't.
