Post-compaction re-orientation. Run this before touching anything else:

1. Read `CLAUDE.md` and `docs/WORKING.md` in full.
2. Verify the repo's actual state against what `docs/WORKING.md` claims — check the commits it names
   exist (`git log`), the files it says landed exist, the gates it says are green actually pass right
   now. Do not trust the document's word for something a command can check in seconds.
3. State, in one paragraph, what you are about to do and why.
4. If that paragraph doesn't match what `docs/WORKING.md` claims, stop and say so rather than guessing
   forward — a mismatch here means either the document is stale or the last session's report was wrong,
   and both are worth surfacing before more work is built on top of either.
