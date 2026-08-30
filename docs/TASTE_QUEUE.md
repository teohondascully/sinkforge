# Taste queue

Feel, visual, and design judgment calls, batched for the director in one sitting. Never mixed with
correctness — that goes through the gates, not here. `CONTEXT.md`, "Review bandwidth" and "Playable
fixtures"; format detail in `docs/ARCHITECTURE.md` §6.

Every entry is a playable fixture ID and exactly one question. If a fixture needs two questions, it
should be two fixtures.

```
F### · <fixture name / what it isolates> · <one question>
```

---

Empty. No fixtures exist yet — `harness/` and `scenarios/` are skeletons, and a fixture needs a real
driver and scenario format under it. First entries expected once the stage-4 fixtures land
(`ONBOARDING.md`, item 4: the hostile chamber and a rope traversal segment).

---

## Slice 0 (D0189) — the legacy palette, now on the world

Not fixtures in the `F###` sense (no fixture format exists yet); these are the two visual judgment calls
Slice 0 produced that are the director's, not the engineer's.

**T001 · `ore_copper` reads SILVER, not copper.** It maps to legacy's `ore`, which is legacy's GENERIC
ore-in-rock record — a grey host with a silvery-white fleck. Legacy never authored a copper-specific
material, so there is nothing to lift. It was taken unaltered rather than retinted, because inventing a
copper hue and calling it a port would hide new art inside a migration. *Question: retint it toward
copper, or is a neutral ore-grey correct for the tier?*

**T002 · The band tint is at 0.10 and is nearly invisible.** Legacy's 8 band colours were authored as
ANNOUNCEMENT colours — type on a dark HUD plate, every one between 0.44 and 0.96 in its brightest channel.
Used as a background fill at full strength they wash the world out completely, so the scene leans the
background only 10% toward the current band. That makes depth-as-colour almost unreadable, which may be
right (the band belongs in a HUD readout at Slice 4, not in the dirt) or may be too timid. *Question:
raise the tint, or leave the world neutral and let the band live in the HUD?*
