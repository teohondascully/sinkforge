Director-run only. If you are the session being audited, do not invoke this on yourself — the point of
the audit is checking whether that session under-reported, and a session that selects its own sample
defeats it. `CONTEXT.md`, "Review bandwidth."

Run:

    python3 tools/spot_audit.py

It samples one commit uniformly at random from those made after `docs/DECISIONS_LEDGER.md`'s own
creation. Read that commit's full diff (`git show <hash>`) and compare it against the ledger entries
that claim to cover it.
