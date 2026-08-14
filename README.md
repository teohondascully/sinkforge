sinkforge

a 2d side-view game about digging an industrial empire into a destructible
underworld. you play a person, not a cursor: you mine by hand, carry ore in
your pack, and feed it into machines. you can dig freely in every direction
like terraria, but the factories you build are strictly vertical, because the
core rule is that gravity is the conveyor belt. things fall down for free.
moving goods — or yourself — back up costs power. deeper is richer and more
dangerous, and there is no prestige or reset: it's one permanent vertical
empire that grows downward.

the loop

you start with nothing but a pickaxe. dig a vein by hand, haul the ore to a
forge, and smelt it. then you automate the work you just did yourself: drop a
drill on the vein so it bores down on its own, cap the forge so it feeds
itself, string hoppers and splitters to move the output, and lay copper
conduit to carry power. once the line runs without you, you climb back out and
go deeper. the whole game is the factorio idea of "automate what you did by
hand," dropped into a terraria world where you share the same physical space
as your machines and the falling ore.

depth and progression

the world is built as discrete depth layers. each one introduces a new
material and a new physical twist that changes how you build: topsoil to learn
the basics, then a stone layer where power arrives, then a flooded aquifer
layer where water pours downhill and you need pumps to hold it back, and so on
down. danger is located and opt-in — your carved-out base is safe by
construction because you mined it out of solid earth, while caves and deeper
layers are threats you choose to breach. the endgame is a single colossal
machine at the bottom of the world, the sinkforge, that you spend the whole
game working toward.

status

early and in active development. the opening arc is playable end to end: dig
by hand, build a self-feeding drill-and-forge line, wire up a coal generator
and power, use a lift to haul goods up, breach the seal into the next layer,
and drain an underground flood with a pump. lots of it is placeholder art and
rough edges. expect things to change.

running it

you need godot 4.6.2. clone the repo and either open project.godot in the
godot editor and press play, or run it from the command line:

    godot --path .

it targets desktop (macos, windows, linux). the art is 32px pixel-art tiles.

controls

    a / d or left / right    walk
    space                    jump (tap for a short hop, hold for a full one)
    w / s                    grip and climb up or down a placed rope
    left mouse               mine (hold to work through a painted dig plan)
    right mouse              place, or pick back up, the selected machine/block
    mouse wheel or 1-0       pick a hotbar slot
    q                        drop, or feed the cell you're facing
    e                        open your pack
    r                        research the next tech (at a bazaar)
    m                        map
    t                        tech tree
    g                        production dashboard
    z                        cycle zoom
    .                        toggle fast-forward
    p                        pause
    f5 / f9                  save / load
    esc                      settings
    h                        key help

how it's built

the simulation is a node-free, deterministic, fixed-tick model (see
src/core/factory_sim.gd). it is the single source of truth: every machine,
the terrain you dig, the power field, the water, and the items are all plain
data mutated only through a small set of discrete calls, so the same inputs
always produce the same result. the visuals and the player's body live in a
separate representation layer that only reads the simulation and draws it —
you could delete the player entirely and the production numbers would be
identical. worldgen and rendering never touch each other directly; they meet
through a small data contract (a material registry plus a two-grid world), so
you can change how the world is generated or how it looks without disturbing
the other.

tests

there's a fairly serious test harness. run the whole thing in parallel with:

    bash tools/run_harness.sh

it covers determinism and conservation in the simulation, movement and
"agility" gauges that measure how the body actually moves, and agent
play-tests that drive the real game to a goal through the same reach-gated
verbs a human uses — so a passing run means a person could actually complete
that goal from where they stand. it's meant to always be green.

layout

    scenes/     the godot scene, the player body, and all rendering
    src/core/   the simulation (the source of truth)
    src/data/   machine, recipe, and material definitions (godot resources)
    tools/      the test + measurement harness
    tests/      the determinism / conservation test suite
    assets/     sprites
    docs/       design notes — GDD.md, ARCHITECTURE.md, PROGRESSION.md
