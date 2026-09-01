class_name RevealTerrainDraw
extends RefCounted

## The terrain cell loop lifted out of `tests/body/reveal_scene.gd`'s `_draw` (D0268), which was at
## 397/400 lines before the miner sprite landed and had no room for it. The third seam taken out of that
## file, after `RevealArgs` and `RevealRecording` (D0244) -- and taken for the same reason: the scene
## ORCHESTRATES (argv, ticks, recording, quitting) while this DRAWS, and the two have never needed to be
## in one file.
##
## NOT `view/visuals/terrain_painter.gd`. That is `docs/LEGACY_GAP.md` T1 #4, a real structural port onto
## the `WorldView` coordinator, and calling this that would claim a piece of work this is not. This is the
## same loop, in its own file, still drawing straight to the debug scene's canvas.
##
## Every WHY comment below came across verbatim; the 400-line cap is a reason to SPLIT at a seam, never a
## reason to trim the reasoning (`docs/QUALITY.md`).
static func draw_cells(canvas: CanvasItem, grid: TileGrid, look: MaterialLook, body_pos_x: int,
		cell_px: int, wide_view: bool, wide_view_row_cap: int) -> void:
	var view_center_col: int = Body._px_to_cell(body_pos_x)
	var col_lo: int = maxi(0, view_center_col - 60)
	var col_hi: int = mini(grid.width, view_center_col + 60)
	# 120-row cap only makes sense for the follow-the-body view -- `--wide-view` needs the WHOLE topsoil
	# band drawn (D0121), since the density contrast it exists to show is spread across it, not just the
	# top 120 of a band that runs 160 rows on both reveal-test sites. NOT the full grid height (up to
	# 1024 rows for max_depth_m=256): the reveal layer only ever places below row 0 and above
	# topsoil_end, so drawing past it would shrink the actually-relevant band to a sliver of a mostly
	# irrelevant screenshot. wide_view_row_cap is topsoil_end(160) + margin, not read from the site
	# config -- this scene already hardcodes plenty else about the two reveal-test sites specifically.
	var row_cap: int = mini(grid.height, wide_view_row_cap) if wide_view else mini(grid.height, 120)
	for col: int in range(col_lo, col_hi):
		for row: int in range(0, row_cap):
			var material: StringName = grid.get_material(Vector2i(col, row))
			if material == &"":
				continue
			canvas.draw_rect(Rect2(col * cell_px, row * cell_px, cell_px, cell_px),
				look.cell_color(material, col, row), true)
