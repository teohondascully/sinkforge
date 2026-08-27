# Area 6 — the KEEP-VERBATIM ledger

Every span the reachable-history scans still match, with the technical reason it stays. The director's
condition for authorising the force-push is that the scan reports zero unapproved tells **or** that each
remaining exception is documented here with a reason. This is that document.

A rule of the whole exercise, applied to every row below: **the scans match a word; only a reading decides
whether it is a tell.** `session` is the clearest case — it is the single most common word in both
categories, and a filter that treated it as a tell would have rewritten the game's own vocabulary.

---

## 1. The gameplay sense of "session" — 21 distinct spans, ~330 occurrences

A *play* session: one sitting of the game, from boot to quit. It is load-bearing domain vocabulary. Every
one of these describes state that resets when the player starts again, and there is no other word for it
that would not make the code worse.

| Where | The span | Why it is not a tell |
|---|---|---|
| `scenes/main.gd` | `## band index -> true, the bands announced this session` | the banner-once-per-band latch |
| `scenes/main.gd` | `Crossing into a band for the first time this session` | the same latch, described at its use |
| `scenes/main.gd` | `an engine that breached before this session doesn't boom retroactively` | save-load priming, so a loaded breach is silent |
| `scenes/main.gd` | `var _skids: int = 0 ## skids this session` | a counter the harness reads |
| `scenes/hud.gd` | `once the player has pressed it this session` | hint suppression after first use |
| `scenes/hints.gd` | `an item's count crossing 0 -> >0 THIS session` | the acquisition EDGE, which is the whole trigger |
| `scenes/objectives.gd` | `you must actually mine/smelt THIS session for a step to tick` | why a pre-stocked dev pack cannot complete a step |
| `tests/test_sim.gd` | `fires exactly once, on the acquisition EDGE (0 -> >0 this session)` | the test's statement of that contract |
| `tools/check_pacing.gd` | `struck a vein (%d this session)` / `the FIRST time this session` | the layer asserting the same gating |
| `scenes/world_renderer.gd` | `boot mid-morning (fixtures + first sessions read day)` | why `DAY_START_PHASE` is 0.10 |

`check_pacing` is even named for it — "session shape" is the pacing curve of one sitting.

## 2. "art director" — 2 spans, 48 occurrences

`scenes/hud.gd` and `tools/check_hud_layout.gd` (the latter inside a quotation of ticket T2.1):

> the HUD is currently the art director; ~85-90% of the interface floats above the world

This is ordinary design criticism — an interface accused of dominating the screen. It names no person and
describes no working arrangement. The **process** sense of the word, a call being someone's to make, was a
tell and every occurrence of it was rewritten; this one is craft vocabulary and stays.

## 3. The prose gate's own rule rows — `tools/check_prose.sh`

    (r"\bdirector\b", "director"),
    (r"\bpeer\b",     "peer"),
    (r"\bthe user\b", "the user"),

These are the *comment register* gate: code comments describe the code, not the project's people. A rule
forbidding a word is the opposite of using it, and a reader who finds this list finds a project that
declined to write about itself in its own source.

The one row that genuinely did advertise a vocabulary — `\bsub-?agents?\b|\bagent(?:s|ic|ically)?\b` — was
narrowed to `\bagents?\b` on `23dce82`, after confirming the wide digest sweep already covers both words
across every tracked file rather than only comments under `scenes/` and `src/`.

## 4. Three spans in one commit message — `fix(encoding): I corrupted five files with the tool I was editing them with`

These are the only spans the message scan still matches, and all three are in the same commit, which is
about mojibake:

| The span | Why it is not a tell |
|---|---|
| ``bytes are `c3 a2 c2 80 c2 94` `` | the six bytes a UTF-8 em-dash becomes when it is decoded as Latin-1 and re-encoded. `c2` is a hex byte value; changing it would falsify the diagnosis |
| ``bytes are `c3 a2 c2 80 c2 94` `` (second occurrence) | the same sequence quoted again later in the message |
| `carrying C1 control characters. U+0080..U+009F` | the C1 control-character block. The name is from the Unicode standard and the codepoint range is stated right beside it |

A scan for the session labels `c1` and `c2` cannot distinguish these from an identity, because at the level
of characters they are identical. Only reading the sentence does — which is the same point as §1, in the
one place where the collision is with hexadecimal rather than with English.

---

## What is NOT on this list

Everything else the scans found was rewritten. The counts at the last regeneration, over every reachable
blob and every reachable commit message, with a positive control in the same pass:

    blobs      4724/4724 objects parsed   vendor/AI 0   coordination 0   'director' 0 beyond §2 and §3
    messages    992/992  commits parsed    vendor/AI 0   coordination 0   beyond the three spans in §4

Positive controls in the same pass: 710 blobs carry the project name, 617 messages carry `harness` or
`check_`. Negative control `zzqqxx`: 0 in both. Coverage is asserted separately from the controls, because
a control proves the instrument can see and says nothing about whether it looked everywhere.

The scan that produced these is **wrap-aware**: comment markers stripped and newlines collapsed before
matching. A line-by-line scan reported clean while three tells sat in the history, split across a line
break — `several sessions keep their / own`, `the peer / session built afterwards`, and `the other session
working in / this repository`. A phrase rule cannot span a wrap, and neither can the instrument that looks
for one. Both had to be fixed together.
