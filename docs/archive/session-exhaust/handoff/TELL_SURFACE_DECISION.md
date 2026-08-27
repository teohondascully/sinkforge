# The two-session tell in the published tree — inventory and one decision for you

Your standing constraint is that nothing pushed may carry obvious signs of AI authorship. This is what
is currently in the **tracked** tree against that constraint, what has been fixed, and the one call I
did not make on your behalf.

This file is in `docs/handoff/`, which is gitignored, so it does not itself ship.

## The measurement

100 hits across 28 tracked files, matching `peer session`, `the peer`, `` `c1` ``, `` `c2` ``,
`subagent`, `orchestrat`. Recompute at any time:

```sh
for f in $(git ls-files | grep -vE '\.(png|uid|import|gdshader)$'); do
  n=$(grep -cE '(peer session|peer-session|\bthe peer\b|\ba peer\b|`c1`|`c2`|subagent|orchestrat)' "$f")
  [ "$n" -gt 0 ] && printf '%5d  %s\n' "$n" "$f"
done | sort -rn
```

Note the two false-positive families, so a future sweep does not "fix" them: `c0`/`c1`/`c2` are common
`Vector2i` cell variables throughout, and `check_encoding.gd` discusses the literal bytes
`c3 a2 c2 80 c2 94`. Those are code and data. Also legitimate: `tools/play_agent.gd` is a real file and
"the agent" meaning that automated play-testing driver is ordinary vocabulary for a test bot. What is a
tell is an agent that is a *collaborator* rather than a *program*.

## Handled without asking

- **~33 hits across 25 source files** (`tools/*.gd`, `tools/*.sh`, `scenes/fine_terrain.gd`,
  `scenes/terrain_painter.gd`) — de-attributed, not deleted. The comments record real methodological
  findings that were expensive to learn; only the second party was removed. *"MEASURED IN PIXELS BY c2,
  WITH A BASELINE, WHICH IS THE PART THAT MATTERS"* keeps the finding and loses the name.
- **`.gitignore`'s header block**, which announced itself as "THE AGENT-PROCESS CORPUS" and enumerated
  "session traces, handoff prompts, orchestration and peer-session protocol". Reworded to "working
  notes". No ignore rule changed — the diff is comment lines only, and that was checked rather than
  assumed. This one mattered out of proportion to its size: `.gitignore` is among the first files
  anyone opens.

## The call I did not make — 64 hits, two documents

`docs/PRIORITY.md` (40) and `docs/VISUAL_RECOMMENDATIONS_SURFACE.md` (22), plus `docs/DIRECTOR_BUS.md`
(2) and `docs/SANDBOX.md` (1).

**These are not comments that can be reworded.** `PRIORITY.md`'s work model is built out of the thing
that is the tell: every active item carries a *holder* of "me" or "peer", there are director rulings
reassigning work between them, and whole sections are one session correcting another. Removing the
attribution does not clean the document, it changes what the document says. That is an editorial
decision about what your public repository contains, and it is the same class of call you have already
reserved for `tools/director_bus.sh`.

Three options, in the order I would rank them:

1. **Gitignore them, as `docs/tracelog/` and `docs/handoff/` already are.** They are planning material,
   not product documentation, and the repo reads fine without them. Cheapest and loses nothing real.
   **If you take this one, copy each file outside the repo BEFORE committing the removal** — `git rm
   --cached` does not preserve a file against a later rebase, and 22 files were lost here that way once.
2. **Rewrite them as a single-author roadmap.** Most faithful to the repo reading as one person's work,
   and the most effort — the holder model has to be replaced with something, not just deleted.
3. **Leave them.** Defensible: they read as a rigorous engineering log, and a reader who is not looking
   for the pattern may not find it. But `` `c1` ``, `` `c2` `` and "the peer session" appear 62 times,
   so a reader who *is* looking will find it immediately.

There is a fourth thing worth knowing whichever you pick: **`.gitignore` publishes the names of the
files it hides.** `/docs/PEER_SESSIONS.md` and `/docs/ORCHESTRATOR.md` appear in the tracked tree as
ignore rules even though their contents do not. Fixing that means renaming your working files or moving
them under one neutral directory, and they are your files, so I left them alone.

## Addendum — what the source pass could not reach, and one string it nearly broke

The de-attribution pass rewrote **71 sites across 25 files**, and it also caught a family the obvious
search misses: *"two sessions"*, *"a neighbouring session"*, *"a waiting session"* — 17 sites in the lock
and harness tooling, where the argument is about two **runs** sharing one machine and reads identically
that way. Plus four calling the reader of the capture set *"a zero-context vision agent"* where "viewer"
is both accurate and the ordinary word. The diff was 103 insertions against 103 deletions, with exactly
two non-comment lines, both printed prose, both checked repo-wide for use as a key first.

**One string could not be reworded alone and is now done.** The capture manifest generator's closing
sentence is byte-compared against the tracked document it writes, and CI runs that comparison — so
changing the generator without regenerating the document turns the job red. Both halves went in together
and `--check` passes.

**Four remaining tells are filenames, not prose, and renaming them is your call:**

| where | what it says |
|---|---|
| `tools/check_progressive_bake.gd:15`, `tools/seed_corpus.sh:78` | cite `docs/PEER_SESSIONS.md` by path |
| `tools/check_frametime.gd:330`, `tools/check_rock_reads.gd:122` | cite a file under `docs/handoff/` |
| `tools/run_harness.sh:375` | points at `docs/tracelog/` |

The sentences around them are clean now; the paths are the tell. Rewriting a citation while the file
still exists under that name would break the citation, so they were left. This is the same knot as the
`.gitignore` one above — the ignore rules publish the names of the files they hide — and one rename of
the working files under a single neutral directory would close all of it at once. They are your files, so
I did not move them.

Two untracked working-tree files also carry process-shaped names and are not pushed:
`tools/_scratch_clock_tick.gd`, and any `_scratch_*` siblings. Harmless while untracked; worth knowing
before any `git add -A`, which is one reason nothing here ever uses it.
