# Runner and GPU checkpoint — September 9

Base inspected: `02592e04` (D0545), with Claude's D0546 bake edits in progress.
During this work Claude committed `d344a35d`, including this pass's five tooling files alongside
his bake changes. Do not reapply them. The subsequent foreground keeper and this report are a
separate follow-up. No history was rewritten; no shader was enabled.

## Assignment status

1. **Foreground launch bug fixed; uncontended presentation is not guaranteed.** `--front` no
   longer sends `--unfocused`. It now requests foreground activation by the launched PID only,
   stops when that run ends, and bounds AppleScript calls. Conflicting hidden/no-focus options
   are refused. Regression tests exercise emitted argv and the OS-call boundary. One live run
   after removing the flag passed both focus checks (median focused share 0.98). Another lost
   focus entirely; the keeper's subsequent run recorded 0.92/0.95 in its two warm windows and
   was correctly WITHHELD. Do not lower the 0.95 guard. Concurrent apps/tests remain a real
   limitation; this is not a promise of sustained ownership on a shared desktop.
2. **Setup reporting complete.** D0545's `setup=` duration, callbacks, observed/painted cells,
   percentage and area ratio survive in each window. Warm totals sum their own measurements;
   setup is part of prep, never added to it. Missing legacy setup remains null, not zero.
   D0546's solid and dilated counts also survive per reason. Tested through real saved JSON.
3. **Provenance implemented.** `perf_identity.py` hashes runtime source/assets, including
   untracked additions; records full HEAD, engine version/binary hash, platform, hashed host,
   settings hash and graphics-environment hash. Each repetition preserves exact argv, timestamps,
   renderer/device startup line and raw seat output. Sources/preferences are checked before/after
   each run; differing repetition identities are refused. Comparisons reject missing legacy
   provenance or mismatched zoom, ticks, regime, engine, host, settings, environment and renderer.
   Code hashes may differ for the intended treatment. Seat-flag differences require the explicit
   `--allow-seat-change` declaration. Source snapshots do not detect edits reverted between them;
   they are not a replacement for a quiet benchmark tree. The settings path assumes the shipped
   Godot default user directory; changing that convention requires updating the recorder.
4. **A real GPU instrument is now exercised.** Xcode Metal System Trace captured the game;
   `metal_trace.py` reads exported GPU execution intervals for an explicit PID. It resolves
   Instruments references, excludes other processes and unions overlapping intervals. Tests
   distinguish overlap from addition and an absent subject from zero GPU cost. This does NOT
   make Godot's `rgpu=0` meaningful, and is not an automatic per-frame GPU profiler.
5. **Shader parity remains OPEN, not silently approved.** Matched surface mining captures now
   exist, both tick 121, zoom 2, body cell (130,75). Terrain patterns visibly differ; there is no
   evidence justifying a blanket brightness compensation. The old 2.44–3x claim was already
   withdrawn in the D0538/D0540 audit. The shader explicitly substitutes eleven noise fields;
   exact parity requires matching those fields and isolated render comparisons, not multiplying
   the output. No exact-noise port or seam correction landed here. T040 remains the director's
   enablement decision. The surface captures are not a proof that every chunk boundary is sound.

## Evidence (local ephemeral artifacts, not checked into git)

- `/tmp/sinkforge-front-setup-fixed.json`: first focus-valid run; phase VALID. Median-window
  142.6 fps, observed warm maximum 33.77 ms. One observation, not an optimisation comparison.
- `/tmp/sinkforge-provenance-dig.json`: saved identity end-to-end; frames withheld at focus 0/0.
- `/tmp/sinkforge-front-owned.json`: keeper run; phase VALID, frames withheld at focus 0.92/0.95.
  Warm setup 41.313 ms / 238 callbacks, observed 193,242 cells, painted 26,706 cells.
- `/tmp/sinkforge-metal-dig.trace`, `/tmp/sinkforge-metal-gpu.xml`,
  `/tmp/sinkforge-metal-dig.log`: Instruments trace/export/log. Target PID 92987, M4 Pro,
  20.476836-second capture; 19,958 active intervals. Their union is 1,052.345328 ms.
  Channel unions: Compute 176.562866 ms, Vertex 69.120552 ms, Fragment 817.386319 ms.
  Channel unions overlap and must not be added as elapsed frame time. The largest single interval
  was 8.711291 ms; this includes boot, not a warm-tail assertion. Another suite process was active,
  and Instruments reported backdated signposts. This is diagnostic GPU evidence, not an isolated
  benchmark or a shader-pass ranking. The raw trace contains other app metadata; keep it local.
- `/tmp/sinkforge-surface-cut-{cpu,shader}.png`: visually inspected matched surface scenario.

## Reproduce the GPU reader

```sh
xcrun xctrace record --template 'Metal System Trace' --time-limit 20s \
  --output /tmp/next-dig.trace --launch -- /Applications/Godot.app/Contents/MacOS/Godot \
  --resolution 1280x720 --disable-vsync --max-fps 0 --path /Users/thondascully/Projects/sinkforge \
  -- --fresh --muted --zoom=2 --quit-after=900 --perf-drive=dig
xcrun xctrace export --input /tmp/next-dig.trace --toc
xcrun xctrace export --input /tmp/next-dig.trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="metal-gpu-intervals"]' \
  --output /tmp/next-gpu.xml
python3 tools/metal_trace.py /tmp/next-gpu.xml --pid <PID_FROM_TOC>
```

## Verification and Claude's next action

Fresh `test_perf_fixture.py` and `test_metal_trace.py` pass; formatter on all five tooling files
and diff whitespace checks pass. Parser/focus/identity/GPU-reader tests were observed failing
before implementation. CodeRabbit is signed out, so review was direct. No full engine battery or
CI claim for this pass. Keep the existing gameplay and bake queue; these tools need no reapplication.
Do not describe all five assignments as fully closed: reliable uncontended focus and exact shader
parity still need work. Use a quiet desktop for frame claims and the trace reader for GPU evidence.
