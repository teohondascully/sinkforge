# Sinkforge visual review queue — 2026-09-07

This is a review queue, not a claim that every item should ship. It was made from five fresh captures on the current head: surface boot, horizon, shallow underground, close aim, and active mining. The captures were used as inspection evidence and are not canonical milestone art.

## Immediate testing-loop queue

The current seat is a screenshot-stepped actor. Three seats in parallel improve throughput only when the model can make progress while another seat is being analyzed. Today each seat is effectively serialized by frame inspection.

1. Keep one persistent agent context per seat; do not resend the mission and protocol every burst.
2. Make one orchestration call return the response JSON, screenshot path, journal append, and receipt together.
3. Add `--observe=event|fixed|milestone`; default stranger runs to event-triggered captures instead of every burst.
4. Add a bounded `moves` sequence with a single final capture, while interrupting on objective, inventory, refusal, lesson, landing, or machine events.
5. Return the previous action, visible result, and current game time beside every frame so the agent need not reread files.
6. Downscale the whole frame to 640×360 and attach native-resolution crops only for HUD, target, hotbar, or machine interaction.
7. Cache unchanged crops; do not resend a static minimap and objective card on every observation.
8. Add a settled-frame request that returns the first stable camera frame and does not wait a fixed 68 ticks when the camera is already still.
9. Add a burst deadline and classify timeout, app throttling, capture failure, and game stall separately.
10. Use a local action queue so the seat accepts the next command while the previous screenshot is being encoded.
11. Keep a last-known frame available immediately, then deliver the new frame asynchronously; never block the game on image transfer.
12. Run one competent physical-input “ceiling” replay through the seat to distinguish game/adapter failures from stranger hesitation.
13. Run blind stranger seats on pixels only; run regression seats on structured player-visible deltas; never mix the evidence.
14. Schedule six or nine seats only for questions that need a sample; do not parallelize a single causal debugging question.
15. Add a deterministic replay mode that consumes the physical input log without model inference.
16. Promote each discovered failure to a short replay before starting another exploratory batch.
17. Record tick, rendered frame, screenshot revision, and input burst ID in one receipt to prevent stale-frame analysis.
18. Add a `--quiet-audio` and a separate audio-enabled lane; do not let audio setup or mute state contaminate visual timing.
19. Keep performance replays independent from model waits and screenshot encoding.
20. Measure wall time per burst, agent latency, capture latency, and simulation time separately; optimize the largest term first.

The highest-return first three are persistent context, one-call observation bundles, and event-triggered/composed bursts. They preserve the current player-visible boundary and should reduce the present 1:13 play-to-wall ratio without training a model.

## Visual backlog

Priority labels: **P0** blocks comprehension or hides the play space; **P1** strongly affects readability/feel; **P2** polish, identity, or long-session quality. Each item has a concrete check so the queue does not become taste-only.

### HUD, layout, and information hierarchy

1. **P0 — Reserve an explicit action-safe rectangle.** Keep objective, lesson, minimap, and hotbar outside the region where the body, aim, and target are expected to appear. Verify with the closest zoom and maximum camera lead.
2. **P0 — Reduce objective-card height at rest.** The opening card occupies a large central band; collapse the how-to after the first calm read while leaving the goal and count visible.
3. **P0 — Move the objective card away from the character’s likely target line.** Capture target-left, target-right, and target-below scenes and reject any layout that hides the ringed object.
4. **P0 — Make lesson and objective styling distinct.** They currently share similar dark plates; use one hierarchy for “goal” and another for “reaction/help.” Verify that a player can name which one is actionable.
5. **P0 — Replace fixed hotbar width with content-aware width.** Render only the occupied wells plus one discoverable empty well, or provide a deliberate expand affordance. Test 0, 1, 5, and 10 occupied slots.
6. **P0 — Show hotbar capacity without implying a fixed maximum.** A compact “5/10” or expandable tray communicates both current contents and capacity; test whether a new player understands it without opening a menu.
7. **P0 — Make the selected slot unmistakable at native play zoom.** Use an outline and a restrained value lift rather than a saturated glow that competes with ore and lamps.
8. **P0 — Group temporary toasts by cause.** Merge repeated pickup, drop, and machine-arrival notifications instead of stacking multiple transient cards over the action.
9. **P0 — Give refusal feedback a stable location.** `TOO FAR`, `NOTHING THERE`, and `WRONG STACK` should appear in one predictable reaction slot, not wherever the current lesson queue happens to place them.
10. **P1 — Give the minimap a readable “you are here” marker.** The yellow body marker is small relative to the map; add a subtle halo or directional wedge and test it at deep zoom.
11. **P1 — Add a clear map mode label.** Distinguish local chart from expanded map with a small title and control hint so the player knows why the scale changed.
12. **P1 — Make map opacity adaptive.** Use a slightly more opaque panel over noisy rock and a lighter plate over empty sky; never sacrifice route legibility for transparency.
13. **P1 — Align HUD edges to one grid.** The objective, depth chip, minimap, lesson dock, and hotbar should share a small set of x/y insets; inspect at 16:9 and letterboxed aspect ratios.
14. **P1 — Add a UI scale option independent of camera zoom.** Verify that large text does not cover the action area and small text does not become unreadable on a 720p viewport.
15. **P1 — Make the bottom control legend context-sensitive.** Hide controls irrelevant to the current mode and add the active modal’s controls when a map/settings panel is open.
16. **P1 — Preserve modal focus visibly.** A thin focus ring or title-state change should show whether movement keys currently act on the world or the panel.
17. **P1 — Give the settings footer a single visual baseline.** Test long binding names, unbound actions, and the tenth hotbar digit without footer wrapping into the play area.
18. **P2 — Add a quiet “new information” accent.** Use a short pulse on a changed objective count rather than reanimating the entire card.
19. **P2 — Provide a clean HUD screenshot mode for reviews.** Hide debug-only labels and capture a consistent version for art direction comparisons.
20. **P2 — Add color-blind-safe redundancy.** Pair ore, danger, and machine state colors with shape, motion, or icon differences; test grayscale captures.

### Terrain, materials, and visual readability

21. **P0 — Establish three hard roles: air, background wall, and solid foreground.** Their value ranges must remain distinct in grayscale at play zoom.
22. **P0 — Reduce high-frequency rock grain behind the player’s target.** A target should win against the wall without requiring the bright ring to be searched for.
23. **P0 — Stop ore sparkle from becoming a generic rock texture.** Reserve the brightest flecks for actual ore and reduce sparkle density on country rock.
24. **P0 — Increase cavity edge readability without outlining every cell.** Use a restrained contact rim only at air/solid boundaries and test against the current back-wall misread.
25. **P0 — Make shallow holes read as holes.** The captures show large dark regions whose floor/wall relationship is ambiguous; add a controlled floor-plane value shift and verify with blind crops.
26. **P0 — Separate material value from lighting value.** A lamp should warm a material, not erase the difference between clay, rock, ore, and void.
27. **P1 — Give each geological bed a broad signature shape.** Keep the seeded irregular thickness but reduce the impression of randomly tiled horizontal strips.
28. **P1 — Reduce repeated square patch sizes.** Vary the scale of broad color masses so the eye does not see a hidden checkerboard.
29. **P1 — Add a readable foreground edge at the surface.** The grass/soil boundary should communicate “walkable top” immediately without a bright continuous outline.
30. **P1 — Make ore clusters directional.** A cluster or seam should suggest where to mine next, not appear as isolated decorative pixels.
31. **P1 — Add a subtle material response per class.** Clay can be matte, ore slightly reflective, and machine metal tighter; keep the differences soft and pixel-compatible.
32. **P1 — Validate readability at native play zoom, not only capture zoom.** A beautiful 1920×1080 review frame can conceal a target that is invisible in the actual camera.
33. **P1 — Test dark-on-dark boundaries with the lamp moved.** If a boundary disappears when the lamp crosses it, fix material contrast before adding more light.
34. **P1 — Make water shape and depth legible.** The cyan pool reads strongly, but its edge should show whether it is a one-cell puddle, a shaft fill, or a deeper body.
35. **P2 — Add sparse geological landmarks.** A distinctive band, pocket, or scar can help orientation without turning the world into a minimap painted onto terrain.
36. **P2 — Create a texture-frequency budget.** Every screen region should have a reason for being detailed; quiet corridors should remain quiet.
37. **P2 — Add a material review board.** Render every material under the same neutral light, lamp light, and deep ambient light before accepting palette changes.
38. **P2 — Add a crop-based regression set.** Keep fixed crops for surface edge, cavity mouth, ore, water, machine, and deep wall; compare value separation automatically.

### Lighting, shading, and atmosphere

39. **P0 — Remove the impression of a vertical sun from underground.** Surface light should enter through openings and soften with distance, not appear as uniform straight shafts everywhere.
40. **P0 — Make hole lighting occupancy-aware.** A cavity opening should brighten the visible floor and nearby walls while leaving occluded pockets dark; test a lamp above, beside, and inside a hole.
41. **P0 — Add a low-resolution warm bounce field.** Inject a restrained, surface-aware fraction of lamp energy into nearby open cells, then upscale smoothly.
42. **P0 — Prevent bounce leaking through thin walls.** Use occupancy-aware propagation or a wall mask; a blurred light texture alone is not acceptable.
43. **P0 — Add soft contact shading at actual support edges.** Ground, machine feet, and rock-to-air boundaries should receive gentle darkening without black cell outlines.
44. **P1 — Replace hard light-source boundaries with smooth falloff.** Tune inner radius, working radius, and outer radius as one readable gradient.
45. **P1 — Tint bounce by material very slightly.** Warm clay and muted ore can return different hues, but the effect must remain subordinate to material identity.
46. **P1 — Reduce cell-correlated lamp grain.** The current light field can read as noisy texture; vary it slowly in world space or remove it in dark regions.
47. **P1 — Add depth haze only behind interactable surfaces.** Cool distant rock and soften it slightly while keeping the target plane crisp.
48. **P1 — Treat open-sky ambience separately from underground ambience.** The horizon capture is nearly flat and gray; give the surface a clearer atmospheric gradient while preserving the deep’s cool palette.
49. **P1 — Light cavity ceilings and floors asymmetrically.** A lamp at the mouth should produce a readable gradient across the floor, not equal brightness on every face.
50. **P1 — Add a light-source priority budget.** Nearby lamp, machine beacon, and water glow should be composited by relevance so distant sources do not flatten the scene.
51. **P2 — Add subtle warm bounce around operating machines.** A working forge or generator should make its immediate room feel inhabited without becoming a second sun.
52. **P2 — Make deep darkness chromatic, not merely black.** Keep cool blue-violet ambient color with enough value to preserve navigation.
53. **P2 — Test lighting with particles disabled.** If the scene only reads because particles are bright, the base lighting/material hierarchy needs work.
54. **P2 — Profile every new full-screen lighting pass.** Keep low-resolution buffers, source culling, and a quality switch so visual softness does not silently consume the frame budget.

### Character, mining, and game feel

55. **P0 — Make the aim state readable before mining starts.** The close aim capture shows the miner and target space competing; add a restrained pointer/aim reticle that does not look like another ore ring.
56. **P0 — Make mining progress attach to the target.** The progress mark should be visible on the cell being worked, not only in a generic center location.
57. **P1 — Reduce the body’s visual occlusion of nearby targets.** When the target is beside the boot, move or offset the outline enough to remain readable without changing the true aim cell.
58. **P1 — Add a short tool wind-up and distinct break moment.** The player should feel the difference between accepted mining, too-far mining, air, and completed breakage.
59. **P1 — Use restrained recoil instead of broad camera shake.** The current scene has large circular light/aim geometry; extra shake can make target acquisition worse.
60. **P1 — Give movement a controlled stop response.** Compare immediate stop, short slide, and terrain-contact cases; choose one consistent physical language.
61. **P1 — Make jumps readable against dark rock.** Add a small landing/contact cue that does not resemble an objective marker.
62. **P2 — Add material-specific mining particles.** Clay dust, stone chips, and ore sparks should differ in shape and color but remain sparse.
63. **P2 — Add a one-frame tool contact flash only at valid impact.** It should be impossible to mistake an air swing for a successful hit.
64. **P2 — Review the miner silhouette at every zoom.** Helmet, lamp, tool, and carried item should remain identifiable at normal play scale.

### Machines, world identity, and polish

65. **P0 — Make machine input/output ports visible from the play camera.** A player should see where ore enters and ingots leave without opening a panel.
66. **P0 — Distinguish machine idle, working, starved, and completed states by shape or motion as well as color.** Verify in grayscale.
67. **P1 — Reduce machine label competition.** Labels should appear when useful and yield to the current target/lesson instead of making every screen a set of nameplates.
68. **P1 — Give the forge a stronger silhouette than the surrounding rock.** The current label helps, but the object itself should be recognizable at a glance.
69. **P1 — Make the first automation payoff visually obvious.** The arrival tick, moving item, and machine animation should form one causal sequence.
70. **P1 — Give the surface rig a signature landmark.** A recognizable structure helps the player orient after returning from depth.
71. **P1 — Add a small set of authored geological landmarks.** Use recurring shapes, not only random material noise, to make routes memorable.
72. **P1 — Make depth transitions visually continuous.** Surface, topsoil, cave, and deep should differ in atmosphere and material, not only the depth chip.
73. **P2 — Add a restrained warm industrial accent palette.** Amber, brass, and cyan should form a controlled identity across lamps, machines, and UI.
74. **P2 — Reduce decorative glows that have no gameplay meaning.** Every bright point should communicate resource, machine state, danger, or navigation.
75. **P2 — Add a color-and-value reference sheet to the art review.** Prevent each new feature from introducing a new unrelated black, amber, or cyan.
76. **P2 — Create before/after capture pairs for every visual change.** Pin seed, camera, tick, zoom, lighting sources, and particle seed; reject comparisons with changed framing.

## First visual slice I would execute

Do not tackle all 76 items at once. The highest-leverage slice is:

1. Dynamic hotbar width plus explicit capacity/selection treatment.
2. Objective/lesson compression and target-safe layout.
3. Solid/air/background value separation in grayscale.
4. Target-cell outline and mining progress at native play zoom.
5. Surface opening light and cavity floor/wall shading.
6. One low-resolution warm-bounce prototype with an occupancy leak test.
7. A fixed capture set and crop-based readability checks for all six changes.

The five review captures exposed enough competing signals that another lighting pass should wait until the target/material hierarchy is less noisy. A softer light on an unreadable rock field would make the scene prettier but not easier to play.
