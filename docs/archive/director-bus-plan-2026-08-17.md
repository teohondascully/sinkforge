> **ARCHIVED 2026-08-27.** Untracked since the 2026-08-25 pivot (`docs/superpowers/plans/2026-08-17-director-bus.md`).
> Implementation plan for the coordination tool `DIRECTOR_BUS.md` describes. Moved here while closing the
> `.git/info/exclude` hole (ANVIL step 1). Kept for provenance.

---

# Director Bus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a small shared mailbox through which the director can issue evidence-backed lane corrections to C1 and C2 without the user relaying messages.

**Architecture:** `tools/director_bus.sh` derives a mailbox under Git's shared common directory, so all worktrees see the same command and acknowledgement records. Plain markdown records make directives inspectable; a focused shell contract test uses an override directory and verifies issue, poll, acknowledgement, blocking status, and resolution. The bus has no daemon, Git hook, or new harness layer.

**Tech Stack:** Bash 3.2-compatible shell, Git common-directory discovery, POSIX filesystem operations.

**Spec:** `docs/DIRECTOR_BUS.md`

## Global Constraints

- Keep `docs/tracelog/c1.md` and `docs/tracelog/c2.md` read-only to the director.
- The live mailbox must be outside Git worktrees at `$(git rev-parse --git-common-dir)/sinkforge-director`.
- Support only `c1`, `c2`, and `all` targets; support only the five documented severities.
- A blocking directive remains blocking until a director resolution record exists; acknowledgement never resolves it.
- Use no daemon, hook, background process, Godot process, or harness registration.
- Keep all shell syntax compatible with macOS Bash 3.2 and run `bash -n` before commit.

---

### Task 1: Contract-test the empty, directed, acknowledged, blocking, and resolved states

**Files:**
- Create: `tools/test_director_bus.sh`
- Test: `tools/test_director_bus.sh`

**Interfaces:**
- Consumes: future `tools/director_bus.sh` commands `init`, `issue`, `poll`, `ack`, `status`, and `resolve`.
- Produces: a zero-exit shell test which confines all bus state to `SF_DIRECTOR_BUS_DIR`.

- [ ] **Step 1: Write the failing test**

```sh
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
BUS="SF_DIRECTOR_BUS_DIR=$TMP_ROOT/bus bash $ROOT/tools/director_bus.sh"
$BUS init
$BUS poll c1
printf '%s\n' 'Evidence for C1.' | $BUS issue c1 REDIRECT T0.2 'Cover lodes across seeds'
$BUS poll c2 | grep -q 'no unread'
$BUS poll c1 | grep -q 'Cover lodes across seeds'
printf '%s\n' 'Accepted.' | $BUS ack c1 0001 ACCEPT
printf '%s\n' 'Stop evidence.' | $BUS issue c1 HALT T2.3 'Do not optimise the DIG loop'
if $BUS poll c1; then exit 1; fi
printf '%s\n' 'Evidence reviewed.' | $BUS resolve 0002 'Superseded by a verified baseline'
$BUS poll c1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tools/test_director_bus.sh`

Expected: FAIL because `tools/director_bus.sh` does not exist.

- [ ] **Step 3: Write minimal implementation**

Implement the six commands documented in `docs/DIRECTOR_BUS.md`, with immutable command files, separate acknowledgements and resolution records, and exit code `3` for an unresolved matching blocking directive.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tools/test_director_bus.sh`

Expected: `director_bus: contract PASS` and exit `0`.

- [ ] **Step 5: Commit**

```bash
git add tools/test_director_bus.sh tools/director_bus.sh docs/DIRECTOR_BUS.md docs/superpowers/plans/2026-08-17-director-bus.md
git commit -m "feat(coordination): add the director bus"
```

### Task 2: Validate visibility from another worktree and create the first two corrections

**Files:**
- Modify: no tracked source files
- Runtime state: `$(git rev-parse --git-common-dir)/sinkforge-director/`

**Interfaces:**
- Consumes: `tools/director_bus.sh` from Task 1.
- Produces: two visible `c1`/`c2` directives and a reproducible status check.

- [ ] **Step 1: Create a C2 redirect with the audited lode evidence**

```sh
printf '%s\n' 'The new T0.2 test exercises only seed 1337, while docs/HARNESS_LAYERS.md requires seed-sensitive generation work to cover the corpus. The existing fuzz loop also omits WorldData.lodes from bounds, determinism, overlap, and load-ingestion invariants.' \
  | bash tools/director_bus.sh issue c2 REDIRECT T0.2 'Extend lode proof across the existing fuzz population'
```

- [ ] **Step 2: Create a C1 watch directive about the runner fix's scope**

```sh
printf '%s\n' 'The atomic done-marker change matches the observed false FAIL exit 0. Keep it limited to marker publication; rebase before landing because the branch is behind main, and report a runner-level reproduction or a clean sweep rather than inferring success from layer logs alone.' \
  | bash tools/director_bus.sh issue c1 WATCH T2.3 'Keep the harness marker fix narrow and evidence-backed'
```

- [ ] **Step 3: Verify both identities see only their own directives**

Run: `bash tools/director_bus.sh poll c1; bash tools/director_bus.sh poll c2; bash tools/director_bus.sh status`

Expected: C1 sees only its WATCH directive, C2 sees only its REDIRECT directive, and status reports both as unacknowledged and unresolved.

- [ ] **Step 4: Commit**

No commit: mailbox state is deliberately local operational state and must not enter Git history.
