# E-menu proposals — how to run this set

Six prompts, each a separate file at this repo's root, each self-contained. **Paste one whole file per
generation.** Do not combine them and do not attach the previous mockups; each is a fresh direction, not
a refinement of the ivory notebook.

| File | Direction | The question it answers |
|---|---|---|
| `EMENU_A_THE_LOAD.md` | The load | What if the weight limit is the entire screen? |
| `EMENU_B_THE_WINDOW.md` | The window | What if the menu is a live view into a running factory? |
| `EMENU_C_THE_SURVEY.md` | The survey | What if it only shows what you have actually walked? |
| `EMENU_D_THE_SLATE.md` | The slate | What if it is just our own HUD, grown? (the conservative one) |
| `EMENU_E_THE_STRIP.md` | The strip | What if there is no full-screen menu at all? |
| `EMENU_F_AT_THE_MACHINE.md` | At the machine | The state we use most and have never drawn. |

Suggested order: **D, A, B, F, C, E.** D first because it is the control — it is the shipped identity at
larger scale, and every other proposal should be judged against what it gives up relative to D.

## What changed from the last prompt, and why

The previous prompt was about 2,600 words and roughly half of them were negatives. Diffusion models do
not render "no": every *never print 6 to 8*, *do not invent a K binding*, *no trailing dashes* is a
constraint that can only be satisfied by accident. The K appeared on all eight slots **because K was
mentioned**. These are 450 to 600 words each, stated positively, one screen per prompt.

## The fixture is identical in all six, on purpose

So the six are directly comparable.

```
FREIGHT — counts against the load, 48 of 90 carried
  Clay 24 · Coal 12 · Iron-bearing ore 8 · Iron ingot 3 · Glimmer 1
KIT — rides free
  Torch 4 · Rope 2 · Plate Press 1
```

Three facts in that fixture come from the shipped code, not from taste:

- **`data/player/pack.yaml`: `bulk_cap: 90`, `inventory_slots: 10`.** The cap is real. The last prompt
  forbade it (*"no invented weight limit"*), which removed the only thing on the screen that forces a
  decision. That omission is most of why the result read as an infographic.
- **`sim/items/pack.gd`: "THE CAP TAXES FREIGHT, NOT THE KIT."** `is_bulk_item` is
  `not MachineDef.exists(item)`, so rope, torch and the Plate Press are exempt — `data/machines/` has
  `rope.yaml` and `torch.yaml`. Five of those eight rows cost 48 load; three cost nothing. Every
  proposal renders that split.
- **`view/hud/wanted_rule.gd` (D0592): the red upward triangle.** A machine that is starving wears it,
  and the stack that would feed it wears the same glyph in the same colour. Already built, already
  shipping, absent from both earlier mockups. In every fixture here the Processor at minus 24 metres is
  out of fuel and the player is carrying twelve coal.

The palette in each file is the real one from `view/hud/ui_theme.gd` and `view/visuals/item_look.gd`.
Note that **the shipped HUD is dark** (`#12141D` ground, brass `#CCA84D`) — the ivory notebook was a
fork from the game's own identity, so D and E hold the line and A, B, C and F test moving it.

## What to look at when they come back

1. **Does the load read before you read any number?** If you have to find "48 / 90" to know the pack is
   half full, the proposal failed its main job.
2. **Can you tell freight from kit at a glance**, without reading the headers?
3. **Does the red triangle land?** Do you notice a machine wants coal before anyone tells you?
4. **Is there anything on the screen that changes while you look at it?** A static panel is the
   infographic failure in its purest form.
5. **Where does your eye go first**, and is that the thing you open this menu to do?

Send the results back and I will do a side-by-side against these five and against the shipped HUD.

## Not covered here, deliberately

Sound, the expanded factory view, the order history, and the drag-to-assign interaction. Those are
worth their own pass once a direction is chosen; putting them in now is what made the last prompt
too long to obey.
