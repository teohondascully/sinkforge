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
| `EXPERIENCE_EVALUATION.md` | Subordinate to `CLAIMS.md`, not a rival taxonomy: the concrete method for gathering evidence toward a claim `CLAIMS.md` §5 already permits (structural/balance/legibility with a stated proxy) but doesn't show how to build. Specification and backlog, not a harness layer — no claim may cite it in place of naming a real kind and metric. | Before proposing any evaluation of fun, motivation, or desire. |
| `DECISIONS.md` | The architecture decision record. Why the sim is node-free, why determinism is provable, why content is data — the reasoning that makes this repository's structural claims checkable rather than asserted. | Before changing anything an ADR would gate, or citing why something is built the way it is. |
| `../ONBOARDING.md` | The session brief. Task 0, the ordered build sequence, the prohibitions. | Starting a session, or resuming after a gap. |
| `../claims/` | Not a document, but normative. Each claim is an assertion the project currently defends. | Continuously. |
| `WORKING.md` | Current stage, what landed, what's in flight, open questions. Not a log — resets when a stage closes. | Every session, and continuously as work happens. |
| `DECISIONS_LEDGER.md` | Append-only judgment calls: decided, alternative, why, reverse cost. Numbers are permanent addresses, never reused or edited after the fact. | Whenever a judgment call is made, and before trusting any claim about why something was built a certain way. |
| `BRIEF.md` | This session's digest, regenerated last, before reporting. Its "What was learned" section is findings written while they're fresh — not the ledger's judgment-call record, and not a work log — because a project's narrative doesn't reassemble itself from thirty ledger entries after the fact. | Every session, and whenever the narrative behind a decision matters more than the decision itself. |
| `TASTE_QUEUE.md` | Feel/visual/design judgment calls as playable fixtures — kept separate from correctness so taste review never mixes with a bug report. | Before a director review round that includes anything feel- or visual-related. |
| `../history/` | Not a document, but curated: images, capped at 12. An image earns its place by illustrating a finding, not by marking a date — when a thirteenth is worth keeping, one comes out, and the swap is a line in `BRIEF.md`'s "What was learned." | When the visual record of a finding matters for the method story. |

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
