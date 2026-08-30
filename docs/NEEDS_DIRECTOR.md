# Needs director

Things a session stopped on rather than plowed through. **Nothing here has been applied.** Each entry
is a diagnosis plus a proposed remedy, held because the call is a judgment the director owns: a feel
decision, a policy decision, or a trade with no obviously right side.

Created 2026-08-30 for the presentation run, which was briefed to park rather than decide. Read this
before `docs/WORKING.md` if you are picking the run up cold — WORKING.md says what happened, this says
what is waiting on you.

**How to close one:** rule on it, then delete the entry and record the ruling in
`docs/DECISIONS_LEDGER.md`. An entry that stays here after a ruling is worse than no entry, because
the next session cannot tell a live question from a settled one.

---

## P001 · The fast fuzz suite gates 5 of its 7 violation types

**Status:** open · **Cost to apply:** ~20 minutes · **Raised by:** Codex audit, 2026-08-30

`tests/test_body_fuzz_fast.gd` counts seven violation types and asserts hard-zero on five of them.
`bounds` and `floor_selection` are printed and not gated — the suite says so out loud on its own line
52, `"(reported, not gated)"`, so this is a documented choice rather than an oversight. Codex's
reading is still fair: the suite passes while reporting hundreds of bounds violations, and a reader
who sees a green suite does not see that number.

**Why it was left ungated, and why that reasoning only half holds.** Under uniform random input the
body walks into the world edge constantly, and the bounds clamp is the designed recovery — the fuzz
oracle itself grants a bounds tick arbitrary displacement (`fixture_body_fuzz_probe.gd`'s
`_max_legit_displacement`). So the count is expected to be large and has no principled zero. That
argues against a hard-zero assertion. It does **not** argue against a ceiling.

**Proposed remedy: ratchet, do not zero.** The fast sweep is 100 seeds x 500 ticks with a fixed
terrain seed and a fixed input RNG, so its bounds count is *deterministic*, not statistical — the same
commit produces the same number every time. **Measured on this run's tip: `bounds=922`,
`floor_selection=0`.** Pin 922 as a maximum, with that number and the commit that set it written
beside the assertion. A change that makes the body escape the world more often then fails loudly; a
change that reduces it fails too, which is the correct prompt to lower the pin deliberately rather
than let it drift. Evidence it is a real pin and not a coincidence: this run changed the resolver and
the count did not move in the fast window, while the full 1.5M-tick sweep moved by exactly 1
(1,179,016 → 1,179,015).

**Why this is yours and not mine.** A ratchet is a policy: it makes every future change carry the
burden of explaining a number nobody chose on purpose. `docs/QUALITY.md` gate 7 is already one of
those and is already red. Adding a second ratchet without a ruling is how a project acquires gates it
resents.

---

## P002 · The recorded-session replay is scratch, not a test

**Status:** open · **Cost to apply:** ~1 hour · **Raised by:** Codex audit, 2026-08-30

Four of the director's own play sessions are committed under `tests/body/recordings/`, and the thing
that replays them and checks them — `tools/scratch/trace_lift.gd` — is gitignored. It has caught
three real defects (D0209, D0212, D0213's verification) and it runs nowhere. Every claim made from it,
including this run's, rests on a session having chosen to run it by hand.

**Proposed remedy.** Promote it to `tests/test_recorded_sessions.gd`: replay every
`tests/body/recordings/play_*.log`, assert 0 bad ticks, 0 airborne climbs, and 0 unconsented corner
nudges per session. About 7,000 ticks total across the four, so it costs a second or two. Two things
it has to carry over, both learned the hard way: the air-control ratio comes from the log's own header
and never from the current default, and `chamber=` is only believable in a log that also carries
`air_control=` (one commit introduced both, so the co-field is the evidence the first was measured
rather than hardcoded).

**Why this is yours.** It makes every recording the director makes into a **binding regression test**.
That is exactly what you want while the body is frozen, and exactly what you do not want the first
time a deliberate feel change legitimately invalidates an old session — at which point the suite fails
for the right reason and someone has to decide whether the recording or the game is wrong. That policy
("a recording is binding until the director retires it") is the ruling, not the code.

---

## P003 · Local and CI runs of the size gate measure different populations

**Status:** open · **Cost to apply:** ~10 minutes · **Raised by:** this session, 2026-08-30

`tools/layer_lint/gd_scan.py::gd_files_excluding` enumerates with `root.rglob("*.gd")` and denies only
top-level `legacy/` and dotted directories. Git's ignore rules are never consulted. So
`check_size_limits.py` lints every gitignored `.gd` under `tools/scratch/` on a developer's machine and
lints none of them in CI, where a fresh checkout has no scratch directory at all.

**It is not only noise.** It means a local gate run can FAIL for a reason CI can never see, and — the
sharper half — a local run can be made to PASS by deleting an untracked file. This run hit both:
`trace_lift.gd::_replay` crossed the 50-line function limit while being edited, and the fix was to
reshape a throwaway tool to satisfy a gate that will never see it. The same gate name reports on two
different populations depending on where it runs, which is the thing `docs/QUALITY.md` exists to stop.

**Proposed remedy.** Filter the enumeration through `git check-ignore --stdin` (one subprocess, cheap)
so both runs see the tracked set. Fallback for a non-git checkout: keep today's behaviour.

**Why this is yours.** The alternative reading is that scratch tools *should* be linted, on the grounds
that a scratch tool that produced a shipped number is not really scratch — this session's own
`trace_lift.gd` is the argument for that. Which population the gate is *supposed* to cover is a
QUALITY.md question, and changing an enforcement's population is exactly the kind of change that
should not happen quietly inside an unattended run.

---

## P004 · The per-commit fuzzer is pointed at a world that poses neither the corner nudge nor the defect

**Status:** open · **Cost to apply:** ~2 hours · **Raised by:** this session, 2026-08-30 (D0213)

Wiring D0213's consent invariant into `fixture_body_fuzz_probe.gd` produced a green that means
nothing, and finding out why produced a fact about the fuzzer worth ruling on.

**Measured, not reasoned.** Over the fast window (100 seeds x 500 ticks = 50,000 ticks) the new
`translation_consent` counter reports **0 with the D0213 defect present and 0 with it fixed**. The
count path is not broken: wiring the same line to `bounds_violation_this_tick` prints **922**. What is
never reached is the *condition*. The same run fires `corner_corrected_this_tick` **0 times** — the
fuzzer does not pose the mechanic at all, never mind the defect in it.

**The cause is the world, not the input.** `fixture_shaft_replay_probe.gd` runs the identical goalless
driver over 20,000 ticks of a **generated shaft** and hits the unconsented case **twice** (`corner_ok=18,
corner_unconsented=2` with the defect; `11` and `0` with the gate). A shaft is walls, every wall contact
depenetrates and zeroes `vel_x`, and a ceiling is always overhead — so the precondition is common there
and rare in the open `HostileChamber` the fuzzer runs in. `docs/DECISIONS_LEDGER.md` D0055 already
recorded that the chamber's one hand-placed corner tile stopped being reached once the held-jump bug it
had been fitted against was fixed; nobody re-placed it, and nothing has exercised corner correction in
this fixture since.

**Proposed remedy, and it is cheaper than the one this entry first proposed.** Not a new input
distribution — a second *world*. Run the existing fuzz driver against `ShaftGenerator` output as an
additional seed band, reusing `fixture_shaft_replay_probe.gd`'s own construction. The input generator,
the violation types and the determinism all stay exactly as they are; only the geometry the body is
dropped into changes, and the geometry is the thing that was missing.

**Why this is yours.** It roughly doubles the nightly sweep, which is already the longest job in the
harness, and it introduces a second population whose numbers are not comparable with the first — a
permanent complication to every "the fuzzer says N" statement made afterward. It also raises a question
nobody has answered: whether `HostileChamber` should be *repaired* instead (its corner tile has been
unreachable since D0055, so it is carrying a feature it no longer tests), which is a fixture-design call
rather than a harness-throughput one.
