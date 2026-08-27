# Update prompt — menu overhaul added to visual-triage program

Send this to the lead engineer after they have read the original visual-triage handoff:

---

**Director update: the Bazaar and Settings are now a first-class visual-quality milestone.**

I reviewed four additional frames: PACK, WORKS, BENCH, and SETTINGS. The finding is not “polish these
menus.” They currently read as a generic, grainy 2008 dashboard laid over SINKFORGE: nested dark rounded
cards, widely tracked uppercase text, gold rectangles used for unrelated meanings, detached resource chips,
huge dead space, dense but weak research graph, and a settings page whose alignment/binding list visibly
breaks down.

Read these additions before selecting further work:

1. `docs/VISUAL_TRIAGE.md` — new V5, Bazaar and settings as an installed industrial interface.
2. `docs/VISUAL_RECOMMENDATIONS_SURFACE.md` — new `MNU-01` through `MNU-35` ticket queue.
3. `docs/handoff/VISUAL_TRIAGE_MENU_UPDATE.md` — this update.

## Priority change

Create or request one concise **T2.1 menu-overhaul parent** after V1 guidance quietness. It is a major
player-facing presentation milestone and may be explored in parallel with T3.1, but do not let it displace
functional underground legibility. The parent should link to the `MNU-*` queue; do not paste 35 rows into
`PRIORITY.md`.

## First assignment: menu system prototype, not a reskin

Before changing every tab, produce a bounded visual-language and information-architecture proposal using a
capture matrix of:

- fresh-game PACK (one row);
- midgame PACK with many carried types;
- WORKS with selected available and unavailable items;
- BENCH with one actionable research path and late locked branches;
- SETTINGS including the longest binding list.

The prototype must answer:

1. What is the Bazaar physically and visually: counter, rack, work order, and research board—not generic
   dashboard cards?
2. How do PACK, WORKS, and BENCH navigate as semantic sections rather than numbered tutorial steps?
3. What does gold mean, and what visually distinguishes selected, locked, unavailable, affordable, and
   actionable?
4. Which information is global, cost-adjacent, contextual, or hidden until inspection?
5. When should the world show behind the interface, and when should it become a quiet utility modal?
6. How do Settings use an independent compact utility layout rather than the Bazaar shell?

Bring that proposal, its named screenshots, and one reversible representative mockup/capture to director
review before broad implementation.

## Non-negotiable constraints

- This is not an instruction to copy Noita’s visuals. Borrow world-first composition, information restraint,
  and material hierarchy; keep SINKFORGE’s industrial descent identity.
- Do not remove the PACK tab merely because it is large. It is currently the only correct view of inventory
  beyond the ten-slot hotbar. Fix its layout and decision density.
- Do not make a giant UI rewrite without the fresh/midgame/full/settings capture matrix.
- Preserve keyboard-only navigation, focus states, affordability comprehension, settings accessibility, and
  all existing functionality.
- A green layout test is not proof of a modern menu. Require before/after capture review at normal scale.
- Every `MNU-*` ticket closes as `SHIPPED`, `REJECTED`, `BLOCKED`, `INVALID`, or `SUPERSEDED`; “waiting” is
  not a state.

## Reporting

For every selected menu ticket report the exact frame, the observed problem, the treatment hypothesis, files
claimed, before/after evidence, functional/accessibility checks, and one outcome: `SHIP`, `REVERT`, `RUN ONE
MORE CONTROL`, or `DEFER`.

The desired result is not “prettier dark cards.” It is a Bazaar that feels like an industrial place where
the player sees one useful decision at a time, and settings that feel invisible enough to use.
