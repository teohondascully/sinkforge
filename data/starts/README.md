# data/starts

A START is what a new game's world holds before the first tick that generation did not put there: the
hand-authored fixtures of the opening (a surface vein to hand-mine, a coal seam, a stepped adit with a
lode in its back wall, a bootstrap forge pocket and a drill shaft), and the pack's opening stock. Legacy
kept these as fourteen layout constants on `MainView` and a procedure (`legacy/scenes/world_seeder.gd`)
that read them; here the layout is the record and `sim/run/world_seeder.gd` is the procedure that
stamps it, in file order, through the sim's own verbs (A′ step 3h, D0353).

`tutorial.yaml` is legacy's `seed_tutorial` translated: cells are metres from the spawn column on the
surface row; materials are this build's (`ore` → `ore_iron`, `earth` → `clay`); per-metre stocks are
written per 4 px cell (÷16, D0349). Not carried: the tutorial tree (flora and the `wood`/`leaves`
materials are not lifted yet) and the starter tool kit (a dead tool ladder, plan §3.2). `dev_kit.yaml`
is legacy's `_dev_seed_pack` minus the splitter (a ruling), for exercising the build loop without
hand-mining first; it is opt-in and stamps nothing into the world.

Schema: `SCHEMA.yaml`. Read through `data/starts/generated.gd` (`StartsRecords.RECORDS`), emitted by
`tools/data_codegen/generate.py`.
