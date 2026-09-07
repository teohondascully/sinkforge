# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-09-06, late. The integration pass under Astra's audit order, third part (the first
two are in `git log -p -- docs/BRIEF.md`: D0405–D0415, then D0416–D0428). THIS PART: the identity
rewrite executed (D0429); rank 9's local chart (D0430); sixteen more stranger runs in batches of three
(D0431–D0443), each batch read from its frames and fixed the same hour; the seat muted on the director's
word (D0437); the loop made faster (D0439); T031, T033, T034, T037 taken provisionally; the update for
Codex and Astra written (`docs/audits/2026-09-06-update-for-codex.md`).** Twenty-one strangers in all;
frames under `tests/body/recordings/playtest_2026-09-06_stranger{1..21}/` (local); reports in
`docs/playtests/`; the mission template tracked at `docs/playtests/MISSION_TEMPLATE.md`.

**Headline: the chimney that took eight of nine strangers has taken none of nine since the cap (D0434).
The first rung, which eight of nine strangers cleared in seconds before, was lost by two of three in
each of the next two batches -- every time to the POINTER, not the verb: the ring's ruler (D0436), the
ring's speck (D0438), a chevron pointed at on air (D0443) -- and each was fixed and pinned within the
hour. Nothing since D0443 has been played by a stranger; strangers 19-21 are running on 8e2bb4b1 as this
is written, and their frames are the only evidence that will count.**

---

## What landed

**Strangers 7-21, five batches, one fix-set each.** D0434: the chimney capped (two clay cells, T031
provisional), the drop's TOO FAR on the machine it fell short of, GRAPPLE says POINT, the smelt how-to
says the whole stack. D0436: the ring prefers hits at the body's own level (a buried vein 3.4 m below beat
the surface vein by the ruler and two strangers never mined); NOTHING THERE for the slash on air. D0438:
the level rule for machines and piles; "a step to your LEFT"; NOTHING THERE at 90 ticks restarted by a
break; the crown falls with the trunk (`TreeFall`, grounded-wood support, T034 provisional). D0440: THE
WAY DOWN, once the surface is walked with rock broken and nothing dug (T037 provisional). D0442: the
arrival tick says "+1 ingot · 2 more" (T033). D0443: the near marker is the target's own metre outlined;
WRONG STACK when the selected stack is not what the machine takes; the smelt how-to says hold ORE; every
rung's how-to pinned to wrap whole.

**The instrument.** The seat settles the body (D0436) and then the camera (D0438) before every frame,
reporting `settled_ticks` and `still`; boots muted, receipt recording the bus (D0437); one call a burst,
the journal riding the command (D0439): 21.5 → 15-20 s a burst. `--muted` for any scripted boot.

**Also.** D0431 the ring's search reaches the screen and pays across frames; D0432 every airborne source
occluded like the lamp; D0433 the ring tightens as the body arrives; D0435 pumping posed (561,084 shapes
triangulate; my predicted control was wrong and rewritten); D0441 the large map is a 64 x 106 m window at
six pixels a metre, not a 63 px sliver.

---

## What was learned

1. **Nearest by the ruler is not nearest by the player's means.** The ring picked the buried vein two
   metres under the surface over the surface vein nine metres across, and the how-to still said "at your
   feet". Rank by the axis the player cannot cheaply traverse: level first, distance second (D0436,
   D0438). It still cannot see walkability: from 3 m down, the buried forge beats the surface one (S18).
2. **A marker beside the thing invites the pointer to it.** The 0.35 m ring was a nine-pixel speck behind
   the boot (S13 dug under their own feet); the chevron hung over the target was pointed at, on air, three
   times (S17). The marker has to BE the thing: the target's own metre, outlined (D0443).
3. **A frame taken while anything still moves is a picture of the past.** The body slid after the key
   (S10, 18 s of MINE into air), then the camera eased for fifty more ticks after the body stopped (my own
   check, two metres off). Settle every free-running thing before the capture, and log the settle.
4. **One verb with one silent precondition costs a stranger who did everything else right.** Q drops the
   SELECTED stack; S16 mined the ore, stood beside the forge, and dropped clay four times under a lesson
   that said "stand BESIDE it". Name what fell and what was wanted (D0443).
5. **A lesson that fires on ordinary play is noise that hides the rare case.** NOTHING THERE at 20 ticks
   docked after every metre broke under a held pointer; 90 ticks and a break-restart keep it for the
   pointer that is really lost (D0438).
6. **Support is a chain to the ground, not adjacency to anything.** The first live felling left one trunk
   cell inside the canopy and the whole crown stood on it. Grounded wood holds leaves; a stub in the air
   holds nothing and stays (its cuts are the player's) (D0438).
7. **A batch of three is a hypothesis generator, not a measurement.** 8/9 → 2/6 on the first rung has a
   mechanism in every frame and no control for Haiku's skill (runs 9 and 15 never tried the verb). The
   auditors were asked for the control (the update's §7 and §10).
8. **A fix-set is validated only by the batch AFTER it.** Batch 16-18 ran on 3ed91cfa and is evidence of
   D0443's PROBLEMS, not its fixes; the second auditor read this correctly. Every report names its build.
9. **The loop's latency, not the fixes, set the pace.** ~20 s of wall for 1.5 s of play, 1:13; four
   hours produced eleven ledger entries of game fixes. One call a burst was the cheap rung (D0439); the
   rest is the question put to Codex and Astra.
10. **A gate in a `;` chain does not gate.** 95bed33e was pushed with the size gate red because the gate
    ran before the `&&`; fixed one commit later. The gate is the last command before the commit, joined
    with `&&`, never `;` or a pipe.
11. **The seat's speakers are the director's.** Three seats played the mix on the machine the director was
    using; the mute existed and nothing scripted set it. A seat is silent by construction now (D0437).
12. **Two sessions in one checkout: an uncommitted file can vanish.** This brief's first regeneration was
    written and was gone minutes later with `git status` clean, while a second session audited the same
    tree and ran suites in it (the harness lock is mandatory; the file was not committed). Commit the
    brief at once; declare file ownership between sessions (`docs/PEER_SESSIONS.md`).

---

## The decisions this round is waiting on

**The commit identity.** The second auditor read the director's request as "commits authored as the Gmail
address"; the repository's `authorship` gate requires ONE identity across every commit, and 1,300-odd
commits carry `121736842+teohondascully@users.noreply.github.com` -- the Gmail address was the drift the
rewrite (D0429) removed. If the director wants the Gmail identity, that is a policy change and a
whole-history rewrite; nothing is rewritten without that word. **Play the opening** (`godot --path .`):
the outline on the vein, THE WAY DOWN after a walk, the felled crown, the large map (M). **Provisional,
overrule by deletion:** T031 the cap (two record lines), T034 the crown (two hook lines), T037 the lesson
(one row), T033 the tick's remainder. **Open:** T032 four ring kinds; T035 RUN_SPEED 9.4 m/s against a 64 m
world; T036 the world ends without a wall; D0427 as Part B's first line or a switch at zero; the loop's
next rung (the update's §10). T024–T030 unchanged.

**CI:** 143203a1 green; every later run through 19ce5702 was cancelled by the next push (concurrency);
8e2bb4b1 was in progress with headed boot, structural gates and authorship green (the second auditor's
read). Read `gh run view <id> --json jobs`, not the suite lines.

---

## Anything that felt wrong even though it passed

**The first-rung regression has no control for agent skill.** **The level rule's early stop is disabled
when every hit is out of band** (a vertical shaft): 40k visits budgeted over ten frames, restarted every
metre the body moves -- no regression on the scripted walk (quiet p99 1.6-1.8 ms either arm), unmeasured
in the bad case. **The perf numbers are from the machine's slow regime** (frame p50 7.5-9 ms, D0418's two
regimes). **WRONG STACK is pinned on synthetic observations only**; the real drop journey (the pack's fall
and `drop_went` in one observe, two machines in range, a multi-recipe machine) is not exercised. **The
journals are intent-before-the-frame now** (the note rides the command), so "what I saw" lands one entry
late.

---

## Blocked, and what it's waiting on

Nothing is blocked. The GPU profile needs a GPU timer on an idle machine (D0418). The stranger programme's
n needs the loop to be cheaper (the update's §10, put to the auditors).
