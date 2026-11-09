extends "res://src/supermarket_renderer.gd"
## Isolated 2-S Sample sprint painter. Source: game/2-S/index.html1170–1186.
## World pixels / seconds, using the parent's bottom-anchored1.3x host camera.
## Paintings and stalls are decoration only. This does not enable the stage.

const PAVEMENT_AT := 0.855
const SHOP_PARALLAX := 0.55
const FRONT_PERIOD := 2100.0
const FRONT_REQUESTED_WIDTH := 12.0

func supports(id: String) -> bool:
	return id == "2-S"

func build_sky(host, _runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var cam: Vector2 = c.camera
	_rect(out, Rect2(cam.x - 10, cam.y - 10, c.width + 20, HEIGHT + 20), Color("4aa3e8"), "shopping_sky_fill")
	if not c.images.has("street"): return out
	# Source draws sky before translate(0, -round(camY)), so compensate the
	# host's world transform by adding cam.y via the shared tile-row helper.
	var y := source_round(float(c.ground) - 30 - PAVEMENT_AT * _size(c, "street").y - cam.y)
	_tile_row(out, c, "street", _crop(c, "street", 0, 0, 1, PAVEMENT_AT), SHOP_PARALLAX, y, "shopping_shops")
	return out

func build_level(host, _runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	# The source returns before floor/stalls if the main painting is absent.
	if not c.images.has("street"): return out
	var cam: Vector2 = c.camera
	var ground := float(c.ground)
	var ys := float(c.y_snap)
	_rect(out, Rect2(cam.x - 10, ground + ys, c.width + 20, HEIGHT), Color("9aa3b4"), "shopping_floor")
	# Unlike sky, pavement runs after the source's rounded vertical translation.
	_tile_row(out, c, "street", _crop(c, "street", 0, PAVEMENT_AT, 1, 1), 1, ground - 30 - source_round(cam.y), "shopping_pavement")
	var stalls: Array = c.level.get("stalls", [])
	for k in stalls.size():
		var x := float(stalls[k])
		var key := "stall%d" % (k % 4)
		if not c.images.has(key) or x + 300 <= cam.x - 40 or x - 20 >= cam.x + float(c.width) + 40: continue
		var size := _size(c, key)
		_rect(out, Rect2(_x(c, x + 8), ground - 2 + ys, size.x - 16, 8), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.25), "sample_stall_shadow")
		_texture(out, c, key, Rect2(_x(c, x), ground - size.y + 6 + ys, size.x, size.y), "sample_stall", Rect2(), false, {"stall_index": k, "world_x": x})
	return out

func build_mid(host, runtime = null) -> Array:
	# Authored2-S has coin rows, not mid-layer hazards. Keep the common W2
	# entity contract; inherited draw_mid calls host-owned pickups once after
	# these commands. Never turn the decorative stalls into collision or coins.
	return super.build_mid(host, runtime)

func build_front(host, _runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var scroll := float(c.camera.x) * 1.3
	# Source calls these "lamp posts", but fgPillars actually paints low
	# bollards: width12 is used for culling, then clamped to20 for drawing.
	var width := clampf(FRONT_REQUESTED_WIDTH, 20, 30)
	for index in range(int(floorf(scroll / FRONT_PERIOD)) - 1, int(floorf((scroll + float(c.width)) / FRONT_PERIOD)) + 2):
		var sx := source_round(index * FRONT_PERIOD + 900 - scroll)
		if sx < -FRONT_REQUESTED_WIDTH - 20 or sx > float(c.width) + 20: continue
		var x := float(c.camera.x) + sx
		var top := HEIGHT - 46 + float(c.y_snap)
		var colour := Color(20 / 255.0, 24 / 255.0, 40 / 255.0, 0.92)
		_rect(out, Rect2(x, top + 8, width, 46), colour, "foreground_bollard")
		_ellipse(out, Vector2(x + width / 2, top + 8), Vector2(width / 2, 6), colour, "foreground_bollard_cap")
		_rect(out, Rect2(x + 4, top + 10, 3, 46), Color(1, 214 / 255.0, 150 / 255.0, 0.55), "foreground_bollard_highlight")
	return out

# Shared bot sprites/overlays, texture sampling, drawing and optional scene iris
# are inherited unchanged. L is empty in2-S: there is no stage HUD/countdown.
# META.level.timer=100000 is dormant data, not a timer/freezer game mode.
