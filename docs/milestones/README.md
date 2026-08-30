# Milestone captures

The migration's visual record, one set per slice. The index — what each frame shows, which commit produced
it, and which recording goes with it — is `docs/MILESTONES.md`, not this file.

Produced by `tools/capture_moments.sh <slice-label>` at a fixed resolution, a fixed camera and a fixed
seed, so that milestone-to-milestone frames are directly comparable and only the content differs. Every
filename carries the short SHA of the commit that produced it; a `-dirty` suffix means the working tree was
not clean and the named commit will NOT reproduce that frame.

`.gdignore` keeps this directory out of Godot's resource scanner, the same as `history/` and `docs/media/`.
CI runs `godot --headless --import` from a clean clone with no cache in both jobs, so every tracked image
would otherwise be imported twice per push for no benefit — nothing references these as resources.
`capture_moments.sh` writes them through a plain OS path, which does not need the engine to import them.

Do not delete a capture to save space. These are records of a world that no longer exists once the game
moves underneath them; they are not regenerable by re-running anything.
