# Documents

**If a document is not listed as normative below, it is not normative.** That is the whole purpose of this file. The prior repository had 31 documents in this directory with no marker distinguishing live design from superseded design, and agents followed whichever was loudest.

---

## Normative

Read in this order. These describe what is true now and what must remain true.

| Document | What it holds | Read when |
|---|---|---|
| `../CONTEXT.md` | Orientation. Architecture in one page, the four rules, repo map, working constraints. | Every session, first. |
| `GDD.md` | Design state: locked, open, dead, and the dead ends already ruled out. | Before any design decision. |
| `ARCHITECTURE.md` | The layered instrument architecture. Dependency rules, determinism, interface contract, budgets. | Before any structural change. |
| `QUALITY.md` | The continuous gates. Harness truth standards. Definition of done. | Before opening a PR. |
| `CLAIMS.md` | The claim system: format, statuses, workflow, what each kind can establish. | Before writing a claim or a check. |
| `EXPERIENCE_EVALUATION.md` | The agent-play evaluation protocol for questions above a legibility check's reach. Specification and backlog, not a harness layer. | Before proposing any evaluation of fun, motivation, or desire. |
| `DECISIONS.md` | The architecture decision record. Why the sim is node-free, why determinism is provable, why content is data — the reasoning that makes this repository's structural claims checkable rather than asserted. | Before changing anything an ADR would gate, or citing why something is built the way it is. |
| `../ONBOARDING.md` | The session brief. Task 0, the ordered build sequence, the prohibitions. | Starting a session, or resuming after a gap. |
| `../claims/` | Not a document, but normative. Each claim is an assertion the project currently defends. | Continuously. |

Plus `adr/` — numbered decision records. An ADR is normative from the moment it merges.

---

## Archived

`archive/` holds superseded documents. Each carries a dated header saying what superseded it.

They are kept, not deleted, for one reason: `legacy/` still contains code that implements them, and an agent reading that code needs to be able to find out why it exists. A deleted rationale becomes an agent guessing.

Two archived documents are worth knowing about specifically:

- **The compatibility audit** measured the prior codebase against a target architecture. It remains accurate about the code it measured, and its methodology (thresholds stated before measurements, mechanical decision rule, a section on where the audit itself is likely wrong) is the standard for future audits.
- **The pivot plan** is the source of most of what is in `GDD.md` §9 about which dead systems are entangled with which. It found, among other things, that removing power gating without replacing it fails silently rather than loudly.

---

## Rules for this directory

- Every document has a status in its header: normative, archived, or ADR.
- A document that mixes durable and superseded content gets edited, not archived wholesale. Archiving a file to avoid editing it loses the durable half.
- Superseding a document means adding it to `archive/` with a dated header and removing it from the table above, in the same commit.
- **No automated checks on documents.** No count validation, no drift detection, no link auditing. The prior repository built all three and they became a maintenance surface of their own. Documents are reviewed by humans.
- If this directory exceeds roughly a dozen normative documents, something has been written that belongs in a claim, an ADR, or a `MODULE.md` instead.
