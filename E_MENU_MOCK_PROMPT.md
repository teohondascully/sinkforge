# SINKFORGE — Working inventory overview and expandable factory drawing

Create a matched pair of high-fidelity game-interface mockups: A, the everyday E-menu overview; B, its Factory section expanded to fill the menu. Produce separate complete 1920 × 1080 images, never a collage. If only one image can be generated per response, generate A first and generate B when asked to continue. Preserve the same visual language and illustrative game state in both.

These are visual design studies. The specific quantities and factory layout below are a mock fixture, not claims about a shipped save or authorisation to change game mechanics.

## Refinement direction — preserve the working structure

If the recent overview and expanded factory mockups are attached, preserve their information architecture: carried supplies upper-left, horizontal hotbar beneath, compact selected-item actions below; factory preview upper-right, order and discovery below. Refine this pair, do not restart the design.

Correct their execution: remove nested framing and boxed inventory rows; tighten the list moderately; make the placement action recognisable; replace chunky explanatory arrows with a surveyed drawing of an actual excavation; and make expansion reveal detail instead of merely magnifying everything. The actual gameplay hotbar reference takes precedence over the generated mockups.

## The central idea

This is the menu a player repeatedly uses while building a factory, not a journal they read once.

It has two speeds:

- Quickly select equipment, check stock against an order, arrange familiar shortcuts and return to the shaft.
- Expand a useful preview to understand and appreciate the factory they have built.

The default screen combines working inventory with a few informative previews. Clicking a preview enlarges that SAME surface into a detailed view. It does not navigate to an unrelated page.

Every preview must earn its space before being clicked. A miniature factory drawing already shows the routes. An order already shows what remains. A discovery already shows the interesting object. Do not create giant navigation buttons disguised as dashboard cards.

The feeling: “I have what I need. I know what to do next. Look at what I built.”

## The game and its boundaries

Sinkforge is a side-on pixel-art excavation and factory game. A field engineer digs beneath a permanent surface rig. Gravity carries goods through the passages the player cuts: THE HOLE IS A CONVEYOR. Machinery processes and lifts materials. The rig issues orders for processed goods and grants machinery.

The factory is physical, not a network administered from a menu.

Carried items are types and counts, NOT a capacity-limited slot grid. No invented pack slots, weight limit, stack splitting or inventory expansion.

The menu prepares actions; the engineer performs them in the world. No remote feeding, collection, delivery, repair, crafting or automatic route construction. “Place in shaft” closes the menu into the normal world placement preview. It does not place remotely.

A carried Plate Press and an installed Plate Press are different things. Never show the carried machine as producing, starved or connected.

The world continues simulating while the menu captures body input. Do not display PAUSED. Counts may update without rows automatically rearranging.

## References and visual identity

If an actual gameplay screenshot is supplied, treat its hotbar as authoritative: preserve its slot count, bindings, icon assignments, proportions, quantity placement and selection language. Previously rejected notebook mockups are negative references, not layout templates.

Make a contemporary, tactile field-engineering tool. Warm mineral ivory, charcoal ink, restrained brass, subtle paper character and fine contact shadows. Keep the notebook's identity without drawing an enormous bound book, centre crease, page curls or stacked receipts.

Use clean sans-serif for operational information, selective expressive serif for object headings, and tabular numerals. Avoid distressed text, ornate frames, bevelled gold buttons and serif text everywhere.

Small object illustrations can have dimensional form and soft shadows. They must aid recognition, not turn half the menu into a specimen pedestal.

Use asymmetric regions, quiet tonal grouping and hairline separators. This is not a corporate dashboard of equal rounded cards. It is also not a full-screen infographic.

Reduce framing to a quiet surface edge where necessary. No repeated rounded outlines around inventory rows, no double gold panel borders, no heavy outer frame enclosing more heavy frames. Unselected rows sit directly on the surface. Selection, alignment and spacing establish hierarchy. Do not remove contrast or legibility in pursuit of minimalism.

The dimmed pixel-art shaft remains visible around the interface. Do not duplicate the hotbar in the background.

## Image A — The everyday working overview

Use one cohesive menu occupying approximately 88% of the screen width and 84% of its height, with safe margins. The left working region takes roughly 40% of the menu width; the right preview region takes the remainder. These are layout guides, not reasons to shrink text or pad empty space.

### Left: carried supplies and familiar equipment

Show these exact eight rows, all fitting without scrolling:

Coal — 12
Iron-bearing ore — 8
Iron ingot — 3
Clay — 24
Rope — 2
Torch — 4
Plate Press — 1
Glimmer — 1

Each row has a small recognisable icon, a legible name and a right-aligned count. Quiet separators, not a box around every row. Do not add redundant classification subtitles to every entry.

The dashes in the source list separate names from quantities; do NOT render a trailing dash after each name. Tighten row height moderately compared with the attached mockup, preserving comfortable text and pointer targets. Give the selected-item area the recovered room rather than stretching the list to fill the column.

Plate Press is selected with a pale brass wash and slim selection marker. Its icon is the actual machine, not a stack of plates.

Immediately beneath the carried rows, on the LEFT, show the familiar in-game hotbar as a HORIZONTAL row. Never make it vertical. Never move it into the right preview area.

Direct manipulation is the intended interaction: drag a carried item onto a shortcut to assign it; drag between shortcuts to swap. This does not transfer or consume goods. Do not show a drag in this default image.

No “Assign to hotbar” panel, assignment form, oversized assignment button, duplicate hotbar or permanent assignment instructions. Keyboard assignment should have a compact contextual equivalent using the game's actual bindings.

If no real gameplay hotbar reference exists, use this illustrative fallback only:
Show exactly eight separate shortcuts, each labelled once: 1 Torch, 2 Rope, 3 Clay, 4 Coal, 5 Plate Press, 6 unassigned, 7 unassigned, 8 unassigned. Never print the range “6–8” inside one position. Never add a second row of conflicting key labels underneath. Do not invent a K binding, tools or durability bars.
Bindings are not item quantities. Unassigned shortcuts do not imply empty pack capacity. A supplied actual gameplay reference overrides this fallback.

Beneath the hotbar, provide a compact selected-item summary, not a second full-height column:

Plate Press
Carried machine · 1
2 Iron ingots → 1 Plate

Include a small attractive machine illustration and one appropriately sized action:
Place in shaft

Render “Place in shaft” as an unmistakable compact button, not a line of description. Give it a restrained filled treatment and a clear keyboard-focus style when focused; it must not become a full-width gold banner. Selecting Plate Press in the list does not mean this action also has keyboard focus.

Do not repeat this as “Ready for placement,” “Primary action,” and another instruction paragraph. Keep the everyday equipment controls immediately understandable.

### Right: useful previews, not a wall of widgets

The Factory section is the largest preview. The current order is medium-sized. Latest discovery is small. Compose these as a coherent working surface with unequal emphasis, not three identical cards.

FACTORY SECTION:
Show a genuinely readable miniature of the exact installed topology specified below. The preview is the attraction: the player's own shaft translated into a compact engineering drawing.

Title: Factory section
Small supporting label: Installed routes

Use one small expand-corners icon at the upper-right of each expandable preview, with a consistent restrained hover/focus treatment. The whole preview is an activation target. No down-chevron suggesting collapse, no competing curved navigation arrow, and no giant “Open” button covering the drawing. Do not show machine-control buttons or invented throughput charts.

CURRENT ORDER:
Use this consistent illustrative state:

Ingots for the winch
Delivered 2 / 6 · Carrying 3
4 still needed · 1 more than you carry
On completion: Winch Head + Winch Station
Deliver at the surface rig.

A small illustration of the two granted components is enough. This order grants an ADDITIONAL pair; the existing pair shown in the factory is already installed. Do not describe the grant as unlocking the first ever winch.

This preview answers a practical question immediately: the player needs one more ingot beyond the three carried to finish the remaining delivery. Do not confuse carried goods with delivered goods.

No remote deliver button, giant stamp, redundant percentage or repeated reward illustration. Expanding this preview would reveal the full order and fulfilled-order history, but do not generate that third screen now.

LATEST DISCOVERY:
Glimmer
No workshop use recorded.
“Kept it anyway.”

Show a small blue-green crystal as a lovely object, not a rarity reward. No fake discovery depth, completion percentage, unread badge or flashing notification. Its expansion would show notes on discovered things, not reveal the entire future catalogue.

This discovery is useful for this pictured moment, not an obligatory permanent billboard. Do not design the overview around always having a new discovery to advertise. There is no automatic carousel, manufactured urgency or endless notification cycle.

### Conditional context, not compulsory clutter

For Image A, no installed machine is targeted. Do not invent a nearby-station panel.

The future explicit-target state can prioritise a station preview over Latest discovery without moving the carried list or hotbar. Such a preview would name the installation, explain its immediate cause-first state, and show its real ports and known contents. It would never guess the nearest machine, duplicate the carried-item card or offer remote transfers.

Do not render this alternate state in Image A.

### Navigation and chrome

Keep “Field notebook” modest. Settings is a small secondary control, not a dashboard tile. The inventory, order and factory preview are visible together without mandatory tab switching.

A restrained footer can read:
Arrows Navigate · Enter Open / Choose · Esc Close

Do not render design-spec labels such as “Dashboard,” “Context workspace,” “Task strip,” or “Primary action.” All text and controls fit inside the screen.

## Exact factory topology shared by A and B

This is an illustrative installed scene. Draw the SAME topology in the small preview and the expanded view:

- Surface Rig toward the right, with a Winch Station nearby.
- Drill at −12 m on the left.
- Drill feeds an excavated ore chute downward to a Processor at −24 m.
- Coal Hopper at −18 m, to the right of the ore chute.
- A separate descending coal chute joins the Processor intake. Mark this actual junction clearly.
- Processor output descends through an ingot route to a Winch Head at −28 m.
- Winch Head has a powered upward return on the right to the surface Winch Station.
- The Winch Station is NOT automatically connected to the Rig.
- A dotted route starts at the Winch Station and ends with an arrowhead pointing INTO the Surface Rig. Label it “Carry to rig.” This is the remaining manual step, never a route from Rig to Station. Do not add “Manual routoal” or any other invented label.

Label Ore, Coal, Ingots and Powered return where useful.

Use small machine silhouettes instead of generic flowchart boxes. The drawing should say “this is the shaft I built,” not “this is how a production chain works.” Replace thick filled arrows with fine surveyed channel boundaries and occasional small direction marks. Show restrained rock silhouettes immediately around the excavations, not a fully textured geological map.

Give the ore chute a modest crooked descent and a widened collection cavity above the Processor; keep every gravity-fed segment descending. The Processor's output route descends down and right into the lower Winch Head, rather than travelling horizontally through a magically powered arrow. Keep the coal route separate until its real intake junction. Preserve these same recognisable bends and cavity shape in both images. These are illustrative geometry choices, not additional machines or gameplay systems.

Show machines at their specified depths below the surface datum: do not draw the −12 m Drill sitting on the surface line. Distinguish the powered return through line style and direction, not colour alone. Do not draw decorative pipes or purchased conveyor belts where the route is excavated space.

Preserve approximate left/right geography and downward depth. Compress long empty distances with labelled break marks. A crossing is not a junction unless specified above.

This is a drawing of physical routes, not a recipe tree or technology tree. Do not force all possible factories into a DAG: actual return loops may exist. Do not add a loop to this particular example.

Do not invent route failures, throughput numbers, efficiency percentages, machine counts, telemetry or automatic completion. A known connection is not proof that material is currently flowing through it.

## Image B — Expand the factory, preserve its identity

The Factory section preview from A expands to occupy the usable menu area. Its title, drawing style, machines and approximate relative arrangement remain recognisable. This is semantic expansion, NOT a uniform zoom of the preview: keep the heading modest and labels near normal interface reading size instead of enlarging them into poster typography.

Use the extra room for clearer excavation silhouettes, the depth ruler, small intake/output marks at the specified connections, and better separation of routes and labels. Reveal those details without adding machinery, guessed telemetry or new connections. The small preview prioritises route recognition and machine identity; the expanded view adds geographic and port detail. It must not turn into a differently arranged generic node graph.

Inventory, hotbar, order and discovery recede completely in this expanded state. Do not squeeze them into an unreadable sidebar. Returning restores their prior state.

Title: Factory section
Subtitle: Current installation · Depths in metres

Show the exact topology above at comfortable reading size, including depth marks, the 28 m powered return and the dotted manual carry to the Rig. The player should be able to appreciate their own construction without studying a legend for a minute.

Include compact controls:
Back to overview
Presentation view

Use a simple back arrow for Back to overview and a clean-frame icon for Presentation view. Reserve the gear icon for Settings. Do not leave inventory shortcut numbers in the expanded view's footer.

Esc closes the entire E-menu. “Back to overview” returns to A and restores selection and scroll position. Do not label both operations Esc.

Keep this view read-only. No edit handles, placement palette, routing tools, autofix, teleport, feeding or remote administration. Selecting an installation may reveal its known state, not operate it.

Presentation view would remove interaction chrome and selection while retaining the drawing title, depth context and small legend for a clean shareable screenshot. Do not add social-network buttons, accounts, badges or achievements. Do not generate a third image unless requested.

Make this drawing feel personal and worth sharing: the shape of THIS factory, not a generic promotional factory illustration.

## Motion language connecting the two images

Design these static screens as endpoints of a spatial transition:

The clicked preview grows from its actual bounds into the expanded surface. Other regions recede. Its content maintains identity; finer detail becomes visible as space opens. Back reverses that movement and returns focus to the same preview.

A roughly 180–250 ms transition is a starting design intention, not a measured implementation requirement. It must be interruptible, avoid blocking repeated input and support reduced motion. Do not use paper-flip animations or a long ceremonial opening.

Show sharp settled images, not motion blur, transition storyboards or explanatory animation arrows.

Live counts update quietly without shuffling rows. Do not imply activity with decorative flowing particles when the factory is idle.

## How this scales

This pair depicts a small established factory. In the opening minutes, the overview should show only the real known shaft, current order and actual discoveries. It should not invent a mature network or fill space with locked cards.

The overview is not every subsystem at full detail. It offers useful previews and expands the one the player chooses. Full settings, full discovery catalogue and historical records do not all occupy the home surface.

Water could later have a distinct blue-green channel layer using real known connections, and power could have its own legible layer. Do not invent either network in these two images merely to decorate the schematic.

## Final visual checks

A must first read as a usable E-menu: carried stock, familiar horizontal hotbar on the left, a clear world-placement action.

The previews must provide information before being opened. The factory drawing gets more visual emphasis than the discovery note. Avoid dashboard-card repetition.

B must visibly be A's Factory section grown larger, not a different application.

Check the specific previous failures: no rounded box around every carried row; no trailing name dashes; no merged “6–8” shortcut; no duplicated bindings; placement looks actionable; expansion uses one consistent icon; manual carry points from Station to Rig; depth matches position; routes look excavated rather than giant infographic arrows; expanded labels are readable rather than enormous.

All names, quantities, assignments and connections must be consistent. No invented capacity, remote logistics, paused labels, oversized specimen box, fake analytics or cropped controls.

Aim for a warm, precise, responsive-feeling engineering tool that makes the player want to build, understand and return to their own factory.

Generate A and B as separate images. If limited to one output, generate A now and wait for “continue with B.”
