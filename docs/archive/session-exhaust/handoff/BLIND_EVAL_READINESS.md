# Blind agent-play opening evaluation — readiness audit and manual-pilot plan

**Scope.** An audit of the six readiness gates in
[`docs/AGENT_PLAY_EVALUATION_PROTOCOL.md`](../AGENT_PLAY_EVALUATION_PROTOCOL.md) (lines 36–58), an
enumeration of every privileged input reachable through the existing play tooling, and a pre-registered
five-minute blind pilot. **This is not an implementation, a harness layer, a threshold change, or a
scored evaluation.**

**Provenance.** Read-only audit of tree `/Users/thondascully/Projects/sinkforge`, branch `main`, head
`c7f3898` (the working tree was clean at `eb3a1e4` when the audit began; `c7f3898` landed mid-audit and
is cited where used). **Nothing was executed.** No Godot process, no harness layer, no capture, no
corpus run, no write-side git command. Every claim below is a source reading or a reading of another
session's committed measurement, and each is labelled as one or the other.

---

## 0. How to read this document

Two kinds of statement appear, and they are marked throughout:

- **OBSERVED** — a file, line, and quoted text I read in this tree. Reproducible with `sed -n`/`grep -n`.
- **INFERRED** — reasoning on top of observations. Can be wrong without any observation being wrong.

**What I measured: nothing.** I ran no instrument. Every number in this document was measured by
somebody else and is attributed. **What I reasoned about: all six verdicts.** A gate verdict is an
inference from source text, not a measurement of the running game, and three of the six (1, 4, 5) would
be settled differently by a run than by a read. Those are named in §7.

**One universal I am deliberately not stating.** I checked the *default* new-game path (`main.gd:683-688`
→ `world_seeder.gd:17-25`). I did **not** check the save-restore path, the `boot_skip_title` reload path,
or any harness fixture's world. Where I say "a new game", I mean the default new-game path and nothing
else.

---

## 1. Three corrections to the briefing I was given

Each of these is load-bearing for a gate verdict, so they are first rather than buried.

### 1.1 `18af7cd` retired the **key legend**, not the objective slab

The brief I received stated: *"The permanent objective slab was retired (`18af7cd`)."*

**OBSERVED.** `git log -1 --format='%B' 18af7cd` is titled **"feat(hud): the key legend retires itself,
one key at a time"** and its body reads *"The subjective audit's charge against the bottom-left legend
was not that it is ugly … but that it is PERMANENT."* Its diffstat is `scenes/hud.gd | 38 +`,
`scenes/main.gd | 8 +`.

**OBSERVED.** `docs/PRIORITY.md:348` agrees with the commit and not with the brief:
> **SHIPPED (`18af7cd`)** — the persistent bottom-left key legend now retires learned verbs contextually.

**OBSERVED.** The commits that actually retired the permanent objective plate are **`adb947e`**
("feat(hud): the goal may announce itself; it may not stand over you", 2026-08-17 14:39) and
**`e57f381`** ("feat(hud): after the first lesson, nothing is offered", 2026-08-17 14:52), recovered via
`git log -L 718,723:scenes/hud.gd`. Both are ancestors of `HEAD`.

**Why it matters:** gate 3 is scored against the objective rail. Citing the wrong commit would have put
a phantom citation into a gate verdict — the exact defect class this repo has been burned by four times
(`docs/PRIORITY.md` note at `docs/ORCHESTRATOR.md:162-165`).

### 1.2 `docs/ORCHESTRATOR.md:245-247` names three `PlayAgent` methods that do not exist

**OBSERVED.** `docs/ORCHESTRATOR.md:245-247`:
> **`tools/play_agent.gd`** — a scripted player exposing real verbs: `walk_to_column`, `dig_down_to`,
> `mine_cell`, `do_mine`, `place`, `craft`, `research`, `grapple`. It drives `MainView`'s actual input
> path, not the sim directly.

**OBSERVED.** `grep -n '^func \|^static func ' tools/play_agent.gd` returns 30 functions. `place`,
`research` and `grapple` are **not among them**; `grep -c grapple tools/play_agent.gd` returns **0**. The
nearest real members are `do_build` (`play_agent.gd:140`) and `build_at` (`:587`); crafting is
`craft` (`:582`); research has no `PlayAgent` entry point at all — `ArcDriver` calls
`agent.main.try_research(...)` directly (`arc_driver.gd:144`).

**OBSERVED.** The second sentence is also wrong in the half that matters here. `PlayAgent` writes the
body's axes directly rather than through the input map — `player.input_dir = float(dir)`
(`play_agent.gd:189`), `player.input_climb = 1.0` (`:446`), `player.auto_input = false` (`:152`) — and
reads and writes the sim directly (`:597-598`, `:605`, `:98`). It drives `MainView`'s **verb** layer for
mine/build/craft/deposit; it does not drive its **input** path.

**INFERRED.** `play_agent.gd`'s own header (`:4-14`) is honest about this and even names the `give()`
hatch. The overstatement is in `ORCHESTRATOR.md`'s paraphrase, and it is the sentence a reader would use
to conclude that gate 6 is nearly met. Correcting it is not my file to edit; it is reported here.

### 1.3 A new game is **not** an unmodified generated seed

**OBSERVED.** `scenes/main.gd:683-688`:
```
func _seed_world() -> void:
    var gen: WorldGen = LayeredWorldGen.new()
    ...
    sim.load_world(world)
    WorldSeeder.seed_tutorial(sim, dev_start)
```

**OBSERVED.** `scenes/world_seeder.gd:17-25` — `seed_tutorial` unconditionally runs
`_seed_starter_vein`, `_seed_tutorial_coal`, `_seed_tutorial_tree`, `_seed_starter_adit`,
`_seed_tutorial_mineshaft`, `_seed_starter_kit`. Only `_dev_seed_pack` is gated on `dev_start`
(`world_seeder.gd:24-25`), and `dev_start` is `false` by default (`main.gd:104`).

**OBSERVED.** What that overwrites onto every generated world, at fixed coordinates:

| fixture | where | source |
|---|---|---|
| starter ore vein, richness 200 | `(47, SURFACE)`, `(48, SURFACE)` | `world_seeder.gd:31-34`, `main.gd:621` |
| tutorial coal, richness 200 | `(54, SURFACE)` | `world_seeder.gd:39-42`, `main.gd:627` |
| pre-dug starter adit (8 cells) + lode written straight into `sim.lode` | cols 52–54 | `world_seeder.gd:52-67`, `main.gd:670-674` |
| bootstrap forge, pre-placed `processor.tres` | `(46, SURFACE)` | `world_seeder.gd:128-131`, `main.gd:607` |
| pre-carved drill shaft + open drill cell | col 56, `SURFACE`..`SURFACE+1` | `world_seeder.gd:134-135`, `main.gd:606,611` |
| the drill's target ore vein, richness **400** | `(56, SURFACE+2)` | `world_seeder.gd:136-137`, `main.gd:612,614` |
| second, pre-placed auto-line forge | `(56, SURFACE+3)` | `world_seeder.gd:138-141`, `main.gd:613` |
| starter pickaxe injected into the pack | — | `world_seeder.gd:148-151` |

**CORRECTED 2026-08-17, and the correction is the useful part.** An earlier revision of this section
drew the conclusion *"three seeds give one opening with three backdrops; seed variance is not a property
of the opening on this build."* **That inference is refuted by measurement and is withdrawn.** It was a
true claim about the code (six features stamped unconditionally, no `if`) from which a claim about
*behaviour* was drawn without measuring the behaviour.

**OBSERVED — I verified this myself rather than transcribing it.** `seed_corpus.sh:158` copies each
failing cell's log to `${TMPDIR}/seed_corpus.<layer>.<seed>.log`, and the `check_pacing` logs from the
T1.0b sweep are still on disk. `check_pacing.gd:116` prints
`"played %d frames (opening %d, descent %d)"`, where *opening* is Act One — the first-automation arc,
`check_pacing.gd:105-107`. Reading them directly:

| seed | opening (frames) | descent | total |
|---|---:|---:|---:|
| 20260817 | **664** | 284 | 948 |
| 99 | 1318 | **0** | 1318 |
| 31337 | 1381 | 370 | 1751 |
| 7 | 1441 | **0** | 1441 |
| 4242 | 1669 | 262 | 1931 |
| 512 | **10086** | 344 | 10430 |

**A fifteen-fold spread is not one opening.** What `seed_tutorial` fixes is a handful of cells at spawn;
what varies is everything the agent crosses *between* them — and seed 512's opening runs about seven
times the median of this set before any descent begins.

**So the accurate claim is narrower, and it is still load-bearing:** *the opening's scripted features are
seed-invariant, while the world the player crosses between them is not, and the second effect is large.*

**Two boundaries on that table, because it is a selected sample and not the corpus.**

1. **These six seeds are the ones that FAILED**, selected on the outcome. `seed_corpus.sh:157-158` copies
   a log only for a failing cell, so 1337 and 8675309 — the two that passed — left no log and **their
   opening lengths are unmeasured here.** Selection on a correlated outcome can inflate the *magnitude* of
   the spread. It cannot manufacture variance that is absent: if openings were seed-invariant these six
   would cluster regardless of why they were selected, and they span 664 to 10086. **The direction of the
   conclusion is safe; the "fifteen-fold" figure is from six of eight seeds, all failing.**
2. **Seeds 7 and 99 record `descent 0`, so for those two rows "opening" is the entire session.** The
   opening-to-opening comparison is unaffected. **INFERRED, not verified:** this is the signature of T5.2
   (`PRIORITY.md:742-745`) — `check_pacing.gd:110` calls `dig_down_to(...)` without `require_arrival`, and
   `play_agent.gd:345-353` documents that on a world with a void under the spawn column the call *"returned
   true immediately, having dug nothing and gone nowhere"*, **naming seed 99 as the case**. Seed 99 showing
   `descent 0` is what that defect predicts. I did not verify a void on seed 7 and cannot run anything, so
   this is corroboration of a known defect, not a new finding.

**What it means for the evaluation design.** The protocol's population rule
(`AGENT_PLAY_EVALUATION_PROTOCOL.md:61-66`) asks for three generated seeds so worldgen variance is
sampled — and on this build it genuinely is sampled, strongly. But the two effects are **superimposed and
not separable by the report format**: a difference between two seeds' openings could be the traversal
between fixtures (large, seed-driven) or the fixtures themselves (zero, by construction), and nothing in
a score vector distinguishes them. **The fix is not more seeds; it is recording which of the two an
observation is about, at the moment it is made.**

**This is not a criticism of the fixture.** Every player gets it; it is shipped tutorial design. It is a
statement about what the evaluation can attribute.

---

## 2. The six readiness gates

Gate text is quoted from `docs/AGENT_PLAY_EVALUATION_PROTOCOL.md:40-54`. The pilot (rollout step 2,
`:164-165`) requires gates **1, 3, 5, 6**; gates 2 and 4 gate the 20-minute run only.

| # | Gate | Verdict | Blocks the 5-min pilot? |
|---|---|---|---|
| 1 | Safe isolation | **UNCERTAIN** | yes — convertible by procedure, no code |
| 2 | Truthful route | **NOT READY** | no (20-min only) |
| 3 | Unmanufactured desire | **UNCERTAIN** | yes — needs a director ruling, no code |
| 4 | Legible route | **NOT READY** | no (20-min only) |
| 5 | Evidence feed | **NOT READY** | yes — satisfiable out-of-repo, no code |
| 6 | Actor boundary | **NOT READY** | **yes — this is the blocker** |

---

### Gate 1 — Safe isolation → **UNCERTAIN**

> *"the run cannot read, overwrite, or delete a real player save and it owns the machine lock for its
> whole session."*

**OBSERVED — the mechanism exists and is real.** `tools/run_harness.sh:129-143` redirects `HOME`,
`XDG_DATA_HOME` and `XDG_CONFIG_HOME` to a per-repo-root temporary home, because *"Godot keys `user://`
on the project NAME, so every checkout of Sinkforge on this machine — worktrees included — reads and
writes one … app_userdata/Sinkforge/"* (`:109-111`). The save slot is `user://sinkforge.save`
(`main.gd:26`); settings are `user://settings.cfg` (`settings.gd:38`). With `HOME` moved, both follow.

**OBSERVED — `with_machine.sh` carries the same isolation and the machine lock.**
`tools/with_machine.sh:36-43` repeats the redirect; `:66-91` takes a machine-wide lockdir, clears a lock
whose owning pid is gone (`:71-75`), and exits **5** rather than 0 on give-up (`:76-85`). Godot's exit
code passes through (`:93`). `tools/check_lock.sh` tests exactly those four properties.

**OBSERVED — three gaps, all specific.**

1. **`with_machine.sh` fails OPEN where `run_harness.sh` fails closed.** Compare:
   - `run_harness.sh:131-132` — `mkdir -p … || { echo "!! could not create the isolated home at $SF_HOME"; exit 2; }`
   - `with_machine.sh:38-42` — `if mkdir -p "$SF_HOME/.local/share" "$SF_HOME/.config"; then export HOME=…; fi`

   If that `mkdir` fails on the wrapper path, the `if` simply does not fire, no message is printed, and
   Godot runs **against the player's real `user://`**. This is the exact shape catalogued at
   `docs/PEER_SESSIONS.md:1066-1069` (a restore whose broken state is indistinguishable from its working
   state).

2. **No production witness on the wrapper path.** `SF_PRODUCTION_SLOT` is exported only by
   `run_harness.sh:136,138`, and `tools/save_sentinel.gd:71` is the only consumer. A session launched
   through `with_machine.sh` gets isolation but **no arm/verify bracket**, so "the save came out
   byte-identical" is asserted by construction and never witnessed.

3. **The wrapper actively refuses an ordinary interactive launch.** `with_machine.sh:55-64` refuses any
   invocation whose first argument is not a flag, and its own error text names the failure mode as
   Godot *"ignor[ing] those and just play[ing] the game"* (`:59`). A blind pilot **is** "just play the
   game". It is reachable — any Godot flag first (e.g. `--resolution 1920x1080`) satisfies the guard and
   `--path <root>` is supplied at `:93` — but **there is no documented invocation for it anywhere in the
   repo**, and nothing has ever exercised the interactive path under isolation.

**What would make it READY** — no code, three procedural steps, all reusing existing tools:
1. Before the session: `save_sentinel.gd -- arm <statefile>` with `SF_PRODUCTION_SLOT` exported by hand
   to the real slot path (`run_harness.sh:136` gives the macOS expression verbatim), then confirm the
   isolated home directory exists on disk.
2. Launch through `with_machine.sh` with a leading Godot flag, so the lock is held for the whole session.
3. After: `save_sentinel.gd -- verify <statefile>`. Record both outputs in the evidence bundle.

**Whose lane.** `tools/*.sh` is out of my write scope and is claimed by the peer sessions
(`docs/tracelog/c2.md:1004`). Finding 1 above is a defect report, not a patch.

---

### Gate 2 — Truthful route → **NOT READY**

> *"an unmodified generated seed contains usable lode and the first research → drill route can be
> completed through player-facing verbs. No injected inventory, pre-dug path, direct sim call,
> map-coordinate oracle, or objective-step driver is allowed."*

Three independent reasons, in descending order of how hard they are to fix.

**(a) OBSERVED — the first half of the gate is met; the second half is met by a fixture, not by the
world.** Generated lode is real: `WorldData.lodes` (`src/core/world_data.gd:43`),
`LayeredWorldGen._seed_lodes` (`layered_world_gen.gd:346,949`), `_grow_lode` writing
`world.lodes[cell] = material` (`:1004`). `docs/PRIORITY.md:246-270` records the evidence (378 cells on
1337; 12 seeds × 5 sizes).

But **the first research → drill route does not touch generated lode at all.** Its vein is the injected
solid-ore cell `MINESHAFT_ORE_CELL` at `(56, SURFACE+2)` with hardcoded richness 400
(`world_seeder.gd:136-137`, `main.gd:612,614`). Generated lode and the drill route are, today, disjoint
subsystems. `docs/PRIORITY.md:243-244` says the pay chute is *"untested, not exonerated"* — no fixture
has driven a rig on a generated lode and watched it pay.

**(b) OBSERVED — every prohibited category is present in the shipped opening**, per §1.3: injected
inventory (`world_seeder.gd:148-151`), pre-dug path (`:52-67`, `:134-135`), direct sim call
(`sim.set_solid`, `sim.deposits[...]`, `sim.place_machine` throughout `world_seeder.gd:31-141`),
map-coordinate oracle (`main.gd:606-627`), objective-step driver (`scenes/objectives.gd:37-53`).

**INFERRED.** The gate's prohibitions were plainly written about the *evaluation's* setup, not the
game's. But they cannot be applied to the evaluation without a rule that distinguishes the two, because
on this build the evaluation setup is empty and the game supplies all five. **That rule does not exist
and the director has to write it.** The honest statement is: the route is completable through
player-facing verbs, and it is completable *because it was arranged in advance at fixed coordinates*.

**(c) OBSERVED, other session's measurement — the seed population is bimodal.**
`docs/PRIORITY.md:173-207` (T1.0b, committed `c7f3898`) records `SF_CORPUS_ONLY=check_pacing bash
tools/seed_corpus.sh` on head `d51c546`: seeds 1337 (15% / 32.2) and 8675309 (14% / 28.7) pass; 99, 31337
and 7 are marginally over the 20% silence cap; **4242 (56% / 13.5), 20260817 (67% / 17.9) and 512
(92% / 3.0) are somewhere else entirely**, against `QUIET_SHARE_CAP = 0.20` (`check_pacing.gd:50`) and
`DENSITY_FLOOR = 24.0` (`:51`), whose provenance line is *"Measured 2026-08-16: longest silence 15%,
density 30.6"* (`check_pacing.gd:48`) — **one world, on the day they were written**.

**Carried limits, verbatim from the row that records it** (`PRIORITY.md:196-200`): `check_pacing`
measures a `PlayAgent` session's event stream, so a thin session means either *the world is barren* **or**
*the scripted agent fails to make things happen in that world*. Those have opposite remedies and this
table separates neither. **Do not read the table as "three of eight worlds are barren."** Provenance is
also incomplete on purpose: a peer's `check_pacing` repair (`dc9d8e9`, +36 lines) is branch-only, their
seed 99 passed where `main`'s fails, and a re-run is owed after that merge.

**What would make it READY.** Either (i) a director rule stating which of the shipped tutorial fixtures
count as "the game" rather than "injection", **and** a first-automation route that consumes generated
lode rather than an injected vein; or (ii) an explicit restatement of gate 2 that scopes it to the
evaluation's own setup. Plus the T1.0b re-run after `dc9d8e9` merges.

**Whose lane.** Lode work is c2's, shipped (`PRIORITY.md:74`). The `check_pacing` repair is the peer's
T5.2 (`PRIORITY.md:742-745`). The rule is the director's.

---

### Gate 3 — Unmanufactured desire → **UNCERTAIN**

> *"the permanent objective rail is absent after the opening lesson. Contextual world guidance may
> remain, but an on-screen command cannot supply the answer being judged."*

Assessed against what is on screen **today** (`main`, head `c7f3898`).

**OBSERVED — clause 1 is satisfied, and this is real work that landed.**
`scenes/hud.gd:722` — `const GOAL_PERSISTS_THROUGH: int = 1`. `hud.gd:768-776`:
```
if objectives.current_index() < GOAL_PERSISTS_THROUGH:
    # The opening lesson keeps the plate, and the how-to that arrives with it and fades.
    ...
else:
    goal_a = stalled                     # nothing is OFFERED after the first lesson
    hint_a = stalled
```
and the docstring at `hud.gd:701-703`: *"So AFTER THE OPENING LESSON, NOTHING IS OFFERED. Later steps do
not announce, do not hold, and do not fade — the top of the screen is simply empty, and guidance is
REACTIVE ONLY."* Shipped `adb947e` + `e57f381` (see §1.1). The measured HUD footprint on a bare screen
is **7.84% of canvas, ratcheted at 8.00%** (`PRIORITY.md:388`), with the boundary printed alongside it
(`PRIORITY.md:400-405`: panels only, a lower bound, and explicitly not the "85–90% floats above the
world" figure). The Bazaar state is **91.95%** (`PRIORITY.md:398`) — a full-screen modal, but a modal
the player opens.

**OBSERVED — three surfaces that still supply an answer.**

1. **The world-space guide ring, for five of thirteen steps, with no fade and no persistence dial.**
   `main.gd:2558-2583` maps the current objective id to cells; `world_renderer.gd:1442-1477` draws them
   as a pulsing reticle plus *"A bobbing down-pointer floated HIGH ABOVE the cell … with a tether line
   back down to the exact rock so the eye tracks marker → target"* (`:1465-1467`). The targets:
   - `mine` → `_nearest_ore_to_player()` (`main.gd:2612`), a full scan of `sim.solid` for the nearest ore cell;
   - `smelt` → `_first_forge()` (`main.gd:2603`);
   - `wood` → `_nearest_tree_to_player()` (`main.gd:2629`);
   - `bazaar` → `sim.bazaar_completion_cell()` (`main.gd:2576`);
   - `build` → `MINESHAFT_DRILL_CELL` (`main.gd:2580`).

   `world_renderer.gd:1457` describes its own visual language as *"pure 'UI marker' — never heat, never
   magic"*.

   **INFERRED.** By placement this is "contextual world guidance", which the gate's second clause
   permits, and `hud.gd:703-706` cites it as the *"attach later guidance to the world object"* half of
   the same recommendation. By function it is a nearest-resource oracle that answers **"first resource
   noticed"** — one of the protocol's own marked timestamps (`:102`) — and it feeds directly into the
   **Opportunity legibility** row (`:125`), whose 0-anchor is *"Does not notice a useful visible
   opportunity"*. **The gate's wording does not resolve this and the director must.**

2. **Reactive guidance restores the full imperative label after 40 seconds of stalling on a step.**
   `hud.gd:691` — `const HINT_STUCK: float = 40.0`; `:767` — `var stalled: float = clampf((age -
   HINT_STUCK) / GOAL_FADE, 0.0, 1.0)`; `:777-778` — `if hint_a > 0.0: hint = str(step["label"])`. The
   labels are literal commands: `objectives.gd:42` — *"Research AUTOMATION at the Bazaar — press T by
   the stall, then ENTER on the lit rung (needs an ore sample + 2 ingots)"*; `:44` — *"Drop the Drill
   into the shaft just ABOVE the ore vein (RMB) — it bores down into it"*.

   **INFERRED.** In a 300-second pilot, 40 seconds of hesitation is not an edge case; it is the expected
   behaviour of a confused actor, and it is exactly the moment the evaluation most wants to observe. The
   feature is good design and a direct contaminant of this measurement.

3. **The opening step's plate is permanent and names both the verb and the place.**
   `objectives.gd:38` — *"Dig ore — hold LMB on the metal-flecked rock by spawn"*.

**OBSERVED — an existing harness gauge points the opposite way from this gate.**
`tools/check_loop_health.gd:18-20` scores a **GUIDANCE-GAP** penalty — *"frames where the current
objective is UNMET yet the game offers NO reachable world guide target"* — weighted heaviest of the
three components (`GUIDANCE_PEN_PER_GAP: float = 0.20`, `:69`) against `SCORE_FLOOR: float = 90.0`
(`:61`), reading `agent.main._guide_targets()` at `:187`. **A change that satisfied gate 3 by removing
the ring would drive a currently-green layer red.** That is not an argument against either; it is a
collision that should be surfaced before somebody discovers it by breaking the suite.

**What would make it READY.** A director ruling on one question — *does a world-space pulsing reticle
over a computed nearest-resource cell count as "contextual world guidance" or as "supplying the answer
being judged"?* — plus, if the answer is the latter, a run-time way to suppress the ring and the
40-second hint for the duration of an evaluation without editing thresholds. Two dials already exist and
are named in their own comments: `GOAL_PERSISTS_THROUGH` (`hud.gd:722`, *"set it to 0 to remove the plate
outright"*) and the `match` arms at `main.gd:2562-2582`. **I am not proposing either change** — that is
gameplay code, another session's lane, and changing the game to make an evaluation succeed is forbidden
by my brief and by `PRIORITY.md:862`.

**Whose lane.** T2.1, c2 (`PRIORITY.md:77`, `docs/tracelog/c2.md:995`).

---

### Gate 4 — Legible route → **NOT READY**

> *"every underground region required by the route has passed the current rock/void readability
> requirement. A route that requires navigating chance-level dark interiors returns `INVALID`, not a
> low agency score."*

**OBSERVED — the requirement is written down and the picture does not meet it.**
`tools/check_rock_reads.gd:104` — `const READ_FLOOR: float = 0.75`, asserted at `:221-223`
(*"a player can tell rock from air out in the dark"*). `docs/PRIORITY.md:541-543`, pooled across three
viewpoints over three runs:

| subject | n | median | vs air | verdict |
|---|---|---|---|---|
| plain **BOUNDARY** rock | 79 | 16.11 | **79%** | clears the 75% floor |
| plain **INTERIOR** rock | 302 | 7.45 | **56%** | near chance |

**OBSERVED — the layer is deliberately unregistered because it fails by design.**
`tools/run_harness.sh:259-267`: *"DELIBERATELY NOT REGISTERED while 6a is open. check_rock_reads
measures a defect that has not been fixed yet, so it fails every run by design … This is NOT the floor
being lowered. The floor stays at 75%."* `check_contact_edge` (6b) is unregistered on the same terms
(`:269-270`).

**INFERRED — but the pilot may not need this gate at all.** Rollout step 2 (`protocol:164-165`) gates
the pilot on 1, 3, 5, 6 only. §4 below therefore proposes a pilot whose *stopping condition* is time,
not depth, so a route through dark interiors is possible but not required. **If the pilot's actor
descends into unlit rock, the run returns `INVALID` under `protocol:152`** — and that is a pre-registered
outcome, not a surprise (see §5.7).

**Whose lane and dependency.** T3.1, peer/c1 (`PRIORITY.md:76,533`; `docs/tracelog/c1.md:75,85-86`).
Gate 4 clears when 6a's interior arm reaches 75% and `check_rock_reads` is registered. Note
`PRIORITY.md:569-572`: the projection repair `c6f23b8` is branch-only, so a run from `main` today
reproduces the *withdrawn* numbers.

---

### Gate 5 — Evidence feed → **NOT READY** (as repo capability; satisfiable by procedure)

> *"video or ordered captures, audio status, exact input cadence, commit, settings, seed, and save state
> can all be retained without overwriting canonical captures."*

**OBSERVED — item by item.**

| required | exists? | evidence |
|---|---|---|
| video | **no** | `grep -rn 'write-movie\|MovieWriter\|movie_writer\|fixed-fps'` across the repo returns nothing. Godot's own movie-maker mode is unused and unconfigured. |
| ordered captures | **no** | `capture_moments.gd:234` writes one fixed path per named moment: `res://_moment_%s%s%s.png`. There is no sequence, index, or timestamp facility. |
| audio status | partial | `settings.gd:25-26` (`muted`, `master`) persisted to `user://settings.cfg` (`:38`). Readable; not emitted into any evidence record. |
| exact input cadence | **no** | no input recorder anywhere. `check_teaching.gd:221-225` inspects `InputEventKey`/`InputEventMouseButton` for its own purpose; nothing logs a session. |
| commit / seed | available | `git rev-parse`; the seed is shown on the title screen and lives at `sim.world_seed` (`main.gd:77-83`). |
| save state | available | `save_sentinel.gd` arm/verify, per gate 1. |
| **without overwriting canonical captures** | **actively at risk** | see below. |

**OBSERVED — the canonical-capture hazard is real and has already fired twice.**
`capture_moments.gd:250-283` exists because a contaminated frame overwrote a good one; `zoom.gd:40-49`
exists because *"The peer ran this to look at something and silently replaced two of them with their
crops."* The surviving rule is stated at `zoom.gd:49`: *"no tool that is not `capture_moments.gd` writes
a `_moment_` file."* The gitignored diagnostic namespace is `_diag_*.png` (`.gitignore:100`).

**OBSERVED — `capture_moments.gd` cannot be reused for a live pilot even if it were pointed elsewhere.**
`capture_moments.gd:108-120` (`_deafen`) sets `Controls.deaf = true` and disables input processing
recursively across the tree, precisely so *"a hand resting on W or a held mouse button"* cannot reach the
game. A tool whose contract is "no input reaches the game" is the exact inverse of what a pilot needs.

**What would make it READY — and it must not be a tool.** `PRIORITY.md:847` (kill list #8) and `:854`
(#12) forbid a new harness subsystem for this before two or three manual runs. So the evidence feed for
the pilot is an **out-of-repo procedure**, specified in §5.6: OS-level screen recording, an
operator-kept input log, and a `git rev-parse` / settings / seed / sentinel header written by hand into
one gitignored bundle directory. Zero new code, zero repo writes outside `_diag_`-class scratch.

---

### Gate 6 — Actor boundary → **NOT READY.** This is the blocker.

> *"the actor can be given only player-visible information. If the implementation still exposes
> `FactorySim`, target cells, inventories, resource lists, objective IDs, or world-event state to its
> decision policy, the evaluation is `INVALID`."*

**OBSERVED — the gate is not a matter of degree for any in-repo actor.** `tools/play_agent.gd:147-152`:
```
func _init(scene_tree: SceneTree, main_view: MainView) -> void:
	tree = scene_tree
	main = main_view
	sim = main.sim
	player = main._player
	player.auto_input = false   # the agent, not the keyboard, drives the body
```
Construction binds the authoritative sim and the body. Every consumer of `PlayAgent` inherits this:
`play_tests.gd`, `check_loop_health.gd:29`, `check_pacing.gd:31`, `capture_moments.gd:37`,
`check_contact_edge.gd:39`, `check_depth_reads.gd:32`, `tools/_scratch_t10_deadhead.gd:26`.

**INFERRED — the two-channel distinction is what makes this a blocker rather than a cleanup, and it is
stated in full at §3.0.** In short: the **effect** channel (how the actor changes the world) is mostly
legitimate, going through `MainView`'s reach-gated `try_*` verbs; the **decision** channel (how the actor
chooses what to do) is **100% privileged, with no non-privileged path at any point.** Gate 6 is written
about the decision policy. **There is no partial credit available here.**

**OBSERVED — and there is no external actor channel either.** The only computer-use tool available in
this session is `mcp__claude-in-chrome__computer`; I loaded its schema to check rather than assuming.
Its description reads *"Use a mouse and keyboard to interact with **a web browser**"* and its
`tabId` parameter is **required** on every action. **It cannot drive a native macOS window.** So an AI
actor cannot, today, receive this game's frames and send it ordinary input.

**What would make it READY** — one of three, and none of them exists in the repo:
1. Provision an OS-level screenshot-and-input channel for a fresh zero-context agent. This is the "Sees
   tier" (`ORCHESTRATOR.md:263-284`) extended from a read-only image judge to an actor.
2. Recruit one naive human actor. `PRIORITY.md:104-106` records that the project cannot obtain this
   cohort.
3. The **operator-relay** shape proposed in §4 — a naive agent that sees only screenshots and returns
   one instruction at a time, executed literally by an operator who adds nothing. It satisfies the gate's
   text at the cost of input cadence, and it needs no code and no new tool.

**Whose lane.** `docs/tracelog/c1.md:90` lists *"blind actor / Evaluation A rig — **QUEUED**"* in c1's
lane. **This audit does not build it, and §4 is a proposal for the director, not an assignment to c1.**

---

## 3. Privileged inputs — the enumeration

### 3.0 The finding this list exists to support — read this before the tables

**There are two channels, and only one of them is nearly compliant.**

- The **effect channel** — how the actor *changes* the world — is mostly legitimate. Mining, building,
  crafting, depositing and researching all go through `MainView`'s reach-gated `try_*` verbs, which is
  what `play_agent.gd:4-8` claims and it is broadly true: if the body cannot walk to a cell, it cannot
  mine it. Two leaks only: `give()` writes the inventory directly (`play_agent.gd:597-598`), and axis and
  facing are written straight onto the body, bypassing the input map (`play_agent.gd:152,189,446`;
  `arc_driver.gd:94,188,221`).
- The **decision channel** — how the actor chooses *what* to do — is **100% privileged, with no
  non-privileged path at any point.** Every target is computed by scanning `sim.solid`, reading
  `sim.inventory`, consulting an objective id, or reading a hardcoded fixture coordinate. There is not
  one decision in either driver that is reached from something a player could see.

**Gate 6 is written about the decision policy** (`protocol:52-54`). That is why it is a blocker rather
than a cleanup: there is no partial credit available, and no amount of tightening the effect channel
moves it. An actor that reached its decisions from pixels would need the 56 entries below to have zero
replacements — not fewer.

Every privileged input reachable through `PlayAgent`, `ArcDriver`, or a layer that drives them. Grouped
by what a player could *not* know. **Every line was read in this tree.** "P" = `tools/play_agent.gd`,
"A" = `tools/arc_driver.gd`, "T" = `tools/play_tests.gd`, "M" = `scenes/main.gd`.

### 3.1 Construction-level bindings (the root of everything below)

| # | Input | Site |
|---|---|---|
| 1 | `main: MainView` — the live controller | P:20, P:148-149 |
| 2 | `sim: FactorySim` — the authoritative world | P:21, P:150 |
| 3 | `player: Player` — the body object | P:22, P:151 |
| 4 | `player.auto_input = false` — the human input path is switched off for the session | P:152 |

### 3.2 Direct `FactorySim` reads — hidden world state

| # | Input | What a player cannot see | Sites |
|---|---|---|---|
| 5 | `sim.solid` (whole dictionary, iterated) | every material of every cell in the world, through rock | P:605-612; A:248-256, A:265-281, A:288-296; T:614, T:754, T:1313-1315, T:1353-1357, T:1366-1368, T:1415-1417 |
| 6 | `sim.is_solid(cell)` | X-ray of any single cell | P:198, 200, 205, 210, 256, 261, 297, 299, 372, 384, 386, 396, 514, 531-532, 540-546 |
| 7 | `sim.inventory` (whole dictionary) | every carried item and count, without opening the pack | P:98-99, 243, 428, 575-578; A:77, 83, 98, 102, 111, 135, 156, 176, 182, 208-232; T:1121-1146, 1180-1187, 1202-1209 |
| 8 | `sim.inventory_slots()` | the pack's slot layout | P:552 |
| 9 | `sim.is_climbable(cell)` | whether a cell holds a rope | P:429, 433, 517 |
| 10 | `sim.in_bounds(cell)` | the world's exact extent | P:514, 531, 540, 544 |
| 11 | `sim.machine_at(cell)` | machine occupancy of an arbitrary cell | P:514, 531, 541, 545; A:170 |
| 12 | `sim.machines` (array) | every machine in the world, at once | P:562-565; A:301-303, 310-311; T:292, 1326, 1341 |
| 13 | `m.fuel`, `m.input_buffer` | a machine's **internal** fuel and buffer contents | A:302 |
| 14 | `m.def.behavior` | a machine's behaviour id | A:302, 311 |
| 15 | `sim.surface_row(col)` | the terrain-height oracle for any column | P:572; T:225, 319, 329, 351, 931 |
| 16 | `sim.is_researched(tech)` | the research ledger | A:129; T:1153 |
| 17 | `sim.drill_column_remaining(cell)` | ore left beneath a cell, through solid rock | A:164 |
| 18 | `sim.bazaar_completion_cell()` | **the exact cell that completes the ruined frame** | A:116 |
| 19 | `sim.find_bazaars()` | every claimed Bazaar's position | A:123, 237 |
| 20 | `sim.total_produced` | lifetime production counters | T:1186, 1208 |
| 21 | `sim.water`, `sim.water_at(cell)` | fluid volume per cell | T:544, 675, 692, 703, 889 |
| 22 | `FactorySim.BAZAAR_W`, `FactorySim.DESCENT_QUOTA` | sim constants | A:240; T:238 |

### 3.3 Direct `FactorySim` **writes** — the world is edited, not played

| # | Input | Sites |
|---|---|---|
| 23 | `PlayAgent.give(item, n)` → `sim.inventory[item] += n` (arbitrary injection) | P:597-598 |
| 24 | 31 `agent.give(...)` call sites in the play-test suite | T:117, 118, 132, 146, 166, 232, 236, 237, 238, 347, 348, 459, 460, 461, 462, 589, 812, 813, 814, 815, 926, 927, 928, 999, 1000, 1023, 1024, 1055, 1086, 1389, 1393 |
| 25 | `sim.deposits[cell] = N` — richness written straight into the world | T:231, 442, 987 |

### 3.4 `MainView` privates and fixture coordinates — the map-coordinate oracle

| # | Input | Sites |
|---|---|---|
| 26 | `main._player` | P:151 |
| 27 | `main._can_reach(cell)` (private reach predicate) | P:185, 202, 211, 221, 386, 389, 490, 514 |
| 28 | `main._cell_at(pos)` / `main._cell_center(cell)` (world↔cell projection) | P:187, 194, 221, 267, 272, 312, 330, 383, 395, 404, 482, 497, 503, 505, 609; A:252, 270, 292 |
| 29 | `main._placeable(cell)` | P:202, 222, 490 |
| 30 | `main._inv_selected = i` (hotbar index written directly) | P:555 |
| 31 | `main._near_bazaar()` | A:241 |
| 32 | `main._guide_targets()` — reading the objective-hint oracle as data | `check_loop_health.gd:187` |
| 33 | `MainView.MINESHAFT_COL` = 56 | M:606; A:161, 186, 250; T:1417 |
| 34 | `MainView.MINESHAFT_FORGE_CELL` = (46, SURFACE) | M:607; A:91, 219, 223 |
| 35 | `MainView.MINESHAFT_DRILL_CELL` = (56, SURFACE+1) | M:611; A:163 |
| 36 | `MainView.SURFACE` | M:598; A:141, 215 |
| 37 | `MainView.MINESHAFT_ORE_CELL`, `AUTO_FORGE_CELL`, `STARTER_VEIN_CELL`, `TUTORIAL_COAL_CELLS`, `ADIT_COLS` | M:612, 613, 621, 627, 670 |

### 3.5 `Player` internals — the body is driven, not controlled

| # | Input | Sites |
|---|---|---|
| 38 | `player.input_dir` written directly (bypasses the input map) | P:186, 189, 235, 290, 311, 394, 441-442, 446, 459, 461, 472 |
| 39 | `player.input_climb` written directly | P:425, 446, 458, 469 |
| 40 | `player.facing = 1` written directly | A:94, 188, 221; T:1134, 1198 |
| 41 | `player.request_jump()` | P:45, 169, 483 |
| 42 | `player.position`, `.velocity`, `.on_floor`, `.climbing` — exact body state | P:185-187, 225, 288, 327, 423, 449, 473, 488 |
| 43 | `Player.HEIGHT`, `Player.RUN_SPEED` | P:288, 482, 488 |

### 3.6 Recipe and rules tables — prices known before they are shown

| # | Input | Sites |
|---|---|---|
| 44 | `ResearchRules.tech(&"automation")["cost"][&"ingot"]` | A:131; T:1155 |
| 45 | `load("res://src/data/machines/drill.tres").craft_cost[&"ingot"]` | A:18, A:149 |

### 3.7 Objective-step drivers — the category gate 2 names explicitly

| # | Input | Sites |
|---|---|---|
| 46 | `ArcDriver.play(agent, obj, until)` — walks `obj.steps` by id, one branch per signpost | A:25-45, A:59-70 |
| 47 | `Objectives.steps` / `obj.is_done(id)` | `scenes/objectives.gd:37-53`, `:100-101`; A:27, 32, 37, 45 |
| 48 | `ArcDriver.step_count(obj, until)` | A:50-54 |
| 49 | A **second, duplicated copy** of the same ladder inside the play-test suite | T:1102-1113 and T:1119-1420 |

**On #49 — a drift hazard, reported because it is in the file's own words.** `arc_driver.gd:11-14` says:
*"It lives on its own because more than one harness layer needs to play the same opening and they must be
playing the SAME one … Two copies of an arc are two arcs, and the day they drift is the day the two
numbers stop being about the same game."* `check_loop_health.gd:30` and `check_pacing.gd:33` preload
`ARC`; `play_tests.gd` does not — it carries its own `_do_step` / `_step_*` / `_ensure_ingots` /
`_nearest_*` family. **The second copy the docstring forbids exists.** I have not diffed them
line-by-line and do not claim they have drifted; I claim only that the structural guarantee the comment
asserts is not in force.

### 3.8 Target-selection oracles — the "resource list" gate 6 names

| # | Oracle | Sites |
|---|---|---|
| 50 | `PlayAgent.nearest_material(material)` — nearest cell of any material, worldwide | P:602-613 |
| 51 | `ArcDriver._nearest_ore_not_shaft` | A:245-256 |
| 52 | `ArcDriver._nearest_tree_base` — finds a trunk by its leaf crown, then walks to its base | A:261-281 |
| 53 | `ArcDriver._nearest_coal` | A:285-296 |
| 54 | `PlayAgent._rope_anchor_above` | P:511-519 |
| 55 | `PlayAgent._floored_exit` / `_exit_dir` | P:528-534, 537-547 |
| 56 | **In the shipped game**: `MainView._guide_targets()` → `_nearest_ore_to_player()` / `_first_forge()` / `_nearest_tree_to_player()` / `sim.bazaar_completion_cell()` | M:2558-2583, 2603, 2612-2625, 2629 |

**#56 is the one that matters most**, because unlike 50–55 it is not tooling — it is rendered to the
screen for every player, every run, and it is the reason gate 3 is UNCERTAIN rather than READY.

**Count.** 56 distinct privileged inputs across 8 categories. **INFERRED:** the list is exhaustive for
`play_agent.gd` and `arc_driver.gd`, which I read in full. It is a *sample* for `play_tests.gd` (1,478
lines, grepped rather than read end to end) and for the layers that construct a `PlayAgent`. Treat 5–49
as complete for the two driver files and as a floor elsewhere.

---

## 4. The smallest five-minute blind pilot

**Its job, from `protocol:165`: "validate the evidence process, not grade the game."** Everything below
is chosen to be the least thing that tests the process end to end.

**Shape: operator-relay, turn-based.**

- A **fresh, zero-context actor agent** — no source, no docs, no commits, no prior session — receives a
  screenshot and returns exactly one plain-language instruction ("walk left", "hold the left mouse
  button on the speckled rock just left of the miner").
- An **operator** executes that instruction **literally and without interpretation**, then takes the
  next screenshot. The operator answers no questions, offers no hints, and does not act on anything the
  actor did not say.
- A continuous screen recording runs for the whole session, independent of the turn loop.
- **Five minutes of wall-clock game time**, not five minutes of turns. The clock runs while the actor
  thinks; the pilot stops at 300 s of elapsed session or when the actor says it has no preferred action.

**Why this shape and not something better.** It is the only shape that satisfies gate 6 with zero code
(§2, gate 6). It is honest about its own defect: **turn-based input is nothing like human input cadence**,
which the protocol already anticipates at `:180-181` (*"Agent audiovisual and input capability may not
model human latency, dexterity, attention…"*). It therefore cannot support any timing, fatigue, or
flow claim — and does not try to.

**What it deliberately does not include:** no harness layer, no fixture, no threshold, no scoring
rubric, no second seed, no judge panel, no gameplay change. Per `PRIORITY.md:847` and `:854`.

---

## 5. Pre-registration

Registered before any run, as `DIRECTOR_BRIEF.md:279-295` requires. Deviating from any line below invalidates the
pilot rather than amending it.

### 5.1 Build and environment
- Commit: recorded with `git rev-parse HEAD` immediately before launch, and `git status --short` must be
  **empty**.
- Launch: through `tools/with_machine.sh` with a leading Godot flag, so the machine lock is held for the
  whole session and `user://` is isolated (`with_machine.sh:36-43,66-91`).
- `dev_start` must be `false` — it is the default (`main.gd:104`) and no `--script` boot is used, so
  nothing can set it.
- Before launch, confirm the isolated home directory exists on disk (the `with_machine.sh:38` fail-open,
  §2 gate 1).

### 5.2 Actor feed
Rendered frames only, at the window's native presentation, delivered as PNG screenshots one per turn.
**No transcript generated from simulation state**, no logs, no file access, no code, no docs, no commit
messages, no prior session context. Declared gaps, per `protocol:179-181`: the actor sees **still
frames, not motion**; it has **no audio**; its reaction latency is turn-length, not human.

### 5.3 Controls
Ordinary keyboard and mouse, via the operator, restricted to what the game binds (`scenes/controls.gd`).
The actor may name any key or mouse action; it may not name a cell coordinate, a seed, an item id, or a
menu it has not seen on screen. If it does, the operator records the attempt and does not execute it.

### 5.4 Actor prompt — **verbatim, from `protocol:86-88`**

> You are starting a new game. Play naturally for up to 20 minutes of normal game time. Use only what the
> game shows and the controls available to a player. You may stop whenever you no longer have a preferred
> action. Do not ask for an objective; choose what to do from the world and interface.

**One pre-registered deviation, and it is the only one.** "20 minutes" is replaced by "5 minutes" and
nothing else changes. `protocol:84` permits a revision only if pre-registered; this is that registration,
and its reason is `protocol:56-57` (*"The first manual pilot may stop at the five-minute orientation
checkpoint"*).

**Checked against `protocol:90-92`:** the prompt names no automation, lode, drill, hauling, Factorio,
Freight Winch, desired emotion, or expected solution. Neither may any operator message. **The words
"drill", "automation", "lode", "haul", "winch", "factory" and "ore" are forbidden to the operator for the
whole session**, including in the post-run interview's first question.

### 5.5 Seed selection rule
**Registered rule: `SF_SEED=1337`, the first entry of the committed corpus** (`tools/seed_corpus.sh:30` —
`CORPUS=(1337 4242 7 99 20260817 31337 512 8675309)`, whose header states *"1337 leads because it is the
shipping seed and the one every historical measurement used"*). Set via `SF_SEED`, which
`MainView.default_seed()` consults (`main.gd:64-66`); the title screen then displays it and the actor
presses ENTER on an unchanged seed, which drops the veil without a reboot (`main.gd:435-442`).

**Two reasons, and the second is a limitation I am choosing on purpose.**
1. The pilot validates the evidence process. Introducing seed variance adds a second uncontrolled factor
   to a run whose job is to test the apparatus.
2. **Pinning to 1337 makes the pilot a statement about one world, and I am saying so before the run
   rather than after being challenged.** T1.0b (`PRIORITY.md:173-207`) is the record of exactly this
   failure: floors calibrated on 1337 and six of eight corpus seeds failing them. The pilot inherits that
   defect knowingly, because the alternative — drawing blind from a bimodal population where seed 512
   yields 92% silence at 3.0 events/1000 frames — would produce a result about worldgen wearing the
   costume of a result about the apparatus.

**What must change before a scored 20-minute run may draw from the corpus.** All three, not any one:
(a) T1.0b's re-run after the peer's `check_pacing` repair (`dc9d8e9`) merges, so the distribution is
measured on one fixture; (b) a stated pre-condition that separates *barren world* from *scripted agent
fails in this world* — the limit `PRIORITY.md:196-200` names and this table cannot resolve; (c) a
pre-declared replacement rule, per `protocol:68-70`, under which a seed lacking a legal opening route is
**recorded with its failure mechanism and player-visible symptom** and both results stay in the report.

**Why that caveat is load-bearing rather than boilerplate, per §1.3.** It would be easy to read
"scripted opening features are identical on every seed" as "so the seed barely matters for a five-minute
run, and pinning to 1337 costs almost nothing." **The measurement says the opposite.** The fixtures are
seed-invariant; the world crossed between them is not, and it varies by roughly fifteen-fold in opening
length across the six seeds with logs (664 to 10086 frames). **1337's own opening length is unmeasured**
— it passed, so `seed_corpus.sh:157-158` kept no log — but it is the seed every historical measurement
used and the one that clears the pacing floors comfortably (15% silence, 32.2 density,
`PRIORITY.md:181`). A pilot on it is a statement about a world already known to be well-behaved on the
one axis we have measured, and it does not transfer to 512 at 92% silence and 3.0 events/1000 frames.
**The non-generalisation caveat is doing real work here; do not drop it as a formality.**

### 5.6 Recording artifacts
One gitignored bundle directory outside the repo (session scratchpad), containing:

1. `session.mp4` — continuous OS-level screen recording, started before launch, stopped after quit.
   **Out-of-repo by necessity**: no movie writer exists (§2 gate 5), and `capture_moments.gd` cannot be
   used because it deafens input (`capture_moments.gd:108-120`) and writes canonical tracked paths
   (`:234`).
2. `turns.log` — one line per turn: wall clock, the actor's verbatim instruction, and the operator's
   verbatim keystrokes. This is the "exact input cadence" record, and it is a hand-kept log rather than
   an instrument. Say so in the report.
3. `header.txt` — `git rev-parse HEAD`; `git status --short`; the seed; the resolution; `Settings.muted`
   and `Settings.master` as they stood; the isolated-home path; the machine-lock pid.
4. `sentinel.arm.txt` / `sentinel.verify.txt` — `save_sentinel.gd` output before and after (§2 gate 1).
5. `actor.md` — every message the actor sent, and the post-run interview, kept separate from the turn log
   so that spontaneous action and prompted explanation are never scored together (`protocol:92`).

**Nothing writes into the repo.** No `_moment_*` file is created or touched — `zoom.gd:49` states the
rule and this pilot obeys it. If any still frame must live in the tree, it uses the gitignored
`_diag_*.png` namespace (`.gitignore:100`) and nothing else.

### 5.7 Invalidation rules — pre-registered, from `protocol:149-156`
The pilot returns **`INVALID`** — never pass, fail, or a score — if any of these occurs:

1. The sentinel's verify does not match its arm, **or** the isolated home was not in place at launch.
2. The machine lock was not held for the whole session (`with_machine.sh` exit 5, or another Godot
   process observed on the box).
3. The operator interprets, hints, answers a question, or executes anything the actor did not literally
   say — including a "obviously they meant" correction.
4. Any forbidden word (§5.4) is spoken by the operator before the interview closes.
5. The actor is exposed to source, docs, commits, a prior session, or this document.
6. The route the actor takes requires navigating unlit rock interiors — gate 4 is open at 56% against a
   75% floor (`check_rock_reads.gd:104`; `PRIORITY.md:542`), so `protocol:153` makes this `INVALID`
   rather than a low agency score.
7. The screen recording fails, truncates, or the turn log has a gap.
8. Godot crashes, hangs (the macOS keychain boot hang, `ORCHESTRATOR.md:396-398`), or is killed.

**A ninth, specific to gate 3, and it is a measurement rule rather than a failure.** The turn log must
mark every turn on which the objective plate, the reactive how-to (`hud.gd:777-778`, arriving after
`HINT_STUCK = 40.0`, `:691`) or a world guide ring (`world_renderer.gd:1442`) was visible. **If a guide
ring was on screen when the actor first noticed the resource it then mined, no Opportunity-legibility
observation may be drawn from that moment** — the game answered the question the run was asking.

### 5.8 Judges
**None.** The pilot produces a raw evidence bundle and a timeline. It is not scored, and no rubric vector
is filled in. Judging begins at the three-seed run, and at that point `protocol:113-117` applies: two
judges sharing a model family, prompt wording, or evidence order are **correlated, not independent**.

**This applies to me.** This document was written by one model reading source; if the same model family
later judges the pilot's evidence, its agreement with this audit is partly a shared prior, not
corroboration. `PRIORITY.md:857-858` (kill list #13) names exactly this, and I am naming it against my
own output rather than only against future work.

---

## 6. What the pilot can and cannot conclude

**It can conclude:**
- whether the evidence bundle in §5.6 is recoverable, complete, and legible to someone who was not there;
- whether the actor boundary survives contact with an operator — i.e. whether §5.7's rules 3 and 4 are
  followable in practice, or whether the operator's hands leak intent;
- whether the invalidation triggers fire when they should, and whether an `INVALID` outcome is
  reportable as diagnosis rather than as a failed run;
- whether the forbidden-word discipline is sustainable through a post-run interview;
- roughly how much wall-clock and machine-lock time a scored run would cost.

**It cannot conclude anything about the game.** Specifically not:
- **fun, tactility, flow, or willingness to continue.** `protocol:33` and `DIRECTOR_BRIEF.md:270-271`
  reserve these to human sessions.
- **orientation or opportunity legibility**, while the guide ring points at the first ore
  (§2 gate 3, §5.7 rule 9).
- **anything time-based** — pacing, hesitation length, idle periods, "first dig at T+n". Turn-based
  input makes every duration an artifact of the relay, not of the game.
- **anything about worldgen or seed robustness.** One seed — and per §1.3 that limit is *stronger* than
  it looks, not weaker: opening length varies about fifteen-fold across the six corpus seeds with logs,
  so a single-seed result is a sample of one from a wide and bimodal distribution. What the pilot sees is
  1337's traversal, not "the opening".
- **anything about the automation payoff, the lode route, or the Freight Winch premise.** Five minutes
  does not reach them, and `protocol:30` forbids the output from authorizing a Freight Winch,
  capacity limit, or new objective in any case.
- **whether an *agent* can play this game.** The operator-relay shape tests the evidence process with an
  agent's judgement and a human's hands. It says nothing about an autonomous agent actor.

**And one thing it must not be allowed to conclude by accumulation.** A clean pilot is evidence that the
apparatus works. It is not a partial result about the opening, and it must not be cited later as "the
five-minute run went fine" — `protocol:56-57` is explicit that a pilot *"must not be presented as a
20-minute result if any later readiness gate fails"*, and gates 2, 4, 5 and 6 all fail today.

---

## 7. Open items I could not assess without a run

Named rather than guessed, per the brief.

1. **Whether `with_machine.sh`'s isolation actually holds on an interactive (non-`--script`) boot.**
   Never exercised. A source read shows the redirect is unconditional on that path; only a run and a
   sentinel verify would prove it. (Gate 1.)
2. **What the bare opening screen actually shows on seed 1337 today.** The HUD footprint numbers
   (`PRIORITY.md:388-398`) are the peer's measurement and are panel-area only, by their own stated
   boundary (`:400-405`). I have not seen a current frame. Gate 3's verdict rests on source, not pixels.
3. **Whether the guide ring is legible enough to function as an answer.** `world_renderer.gd:1442-1477`
   describes a bright reticle and chevron; whether a first-timer's eye actually goes there is a pixel
   question and belongs to the Sees tier, not to a source audit. (Gate 3.)
4. **Whether the first research → drill route completes on a *generated* world without the tutorial
   fixture.** Untestable by reading, and untested by any fixture — `PRIORITY.md:243-244` says the pay
   chute is *"untested, not exonerated"*. (Gate 2.)
5. **Whether `play_tests.gd`'s duplicated arc has drifted from `arc_driver.gd`.** I established that two
   copies exist (§3.7 #49); I did not diff them semantically and make no claim that they differ.
6. **T1.0b's distribution after the peer's `check_pacing` repair (`dc9d8e9`) merges.** The cited table is
   `main`'s fixture at head `d51c546`; the peer's seed 99 passed where `main`'s fails, and a re-run is
   owed. (Gate 2, §5.5.)
7. **Whether an OS-level computer-use channel could be provisioned for an actor agent on this box.**
   I verified only that the channel available to *this* session cannot do it (`mcp__claude-in-chrome__computer`
   requires a `tabId`). What else the user's environment could offer is outside what I can see. (Gate 6.)

---

## 8. Recommendation

Gates 1, 3 and 5 are all convertible without a line of code — gate 1 by the three-step sentinel
procedure, gate 3 by one director ruling, gate 5 by an out-of-repo recording procedure. Gate 6 is not.
There is no channel today by which a naive actor can receive this game's frames and send it ordinary
input: `PlayAgent`/`ArcDriver` cannot be reused because construction binds `MainView`, `FactorySim` and
`Player` (`tools/play_agent.gd:147-152`), which `protocol:52-54` makes `INVALID` by its own text, and the
only computer-use tool available here is browser-scoped. Until an actor channel exists, a "blind pilot"
would be run by the person who built the game — the least blind actor obtainable — and would return
`INVALID` for the reason the protocol names at `:152` (*"the actor accesses privileged state"*).

**FIX READINESS BLOCKER** — gate 6, the actor channel: no means exists for a naive actor to receive
player-visible frames and send ordinary input to the running game, and every in-repo actor is
constructed with `MainView`/`FactorySim`/`Player` references at `tools/play_agent.gd:147-152`. The
cheapest remedy that clears it is the operator-relay shape pre-registered in §4–§5, which requires no
code, no new tool, and no gameplay change — only a director ruling on gate 3 and one person willing to
be the hands.
