extends "res://src/festival_renderer.gd"
## 3-S reuses the authored fieldB paintings, caravan cutouts, bale surfaces,
## receipt art and shared player layers. No stalls minigame or extra tents.
## Source game/3-S/index.html:1030-1050,1165-1168.

func supports(id: String) -> bool:
	return id == "3-S"

func _decor_cut(out: Array, c: Dictionary, decor: Array) -> void:
	if decor[0] != "sign":
		super._decor_cut(out, c, decor)
		return
	var wx := float(decor[1])
	if wx - float(c.camera.x) < -560 or wx - float(c.camera.x) > float(c.width) + 560: return
	var x := _x(c, wx)
	var y := float(decor[2]) + float(c.y_snap)
	# d[3] is a palette index for signs, not a horizontal flip flag.
	var colour := Color(TENT_COLOURS[int(decor[3])][0])
	_border(out, Rect2(x - 115, y - 70, 230, 56), 10, colour, Color("f5f1ea"), 3, "bonus_stall_sign")
	_rect(out, Rect2(x - 4, y - 14, 8, float(c.ground) - float(decor[2]) + 14), Color("9aa3b2"), "bonus_stall_sign_post")
	out.append({"type": "outlined_text", "position": Vector2(x, y - 42), "text": "Partner stall", "size": 13, "colour": Color.WHITE, "outline": Color("14243b"), "outline_size": 3.25, "tag": "bonus_stall_sign_label"})

func build_hud(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var duration := float(host.meta.get("l3", {}).get("timer", 0)) / 1000.0
	if duration > 0:
		# Accept a WorldThree snapshot/object or a direct bonus snapshot. Keep
		# the clock independent from host.elapsed and world level_time.
		var data = _state(runtime, "stage_data", {})
		var elapsed := float(_state(runtime, "timer_elapsed", data.get("timer_elapsed", 0)))
		var seconds := maxi(0, int(ceil(duration - elapsed)))
		var urgent := seconds <= 10
		_border(out, Rect2(410, 78, 140, 38), 12, Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.85), Color("ff8f8f") if urgent else GOLD, 2, "bonus_timer_back")
		out.append({"type": "outlined_text", "position": Vector2(480, 98), "text": "%ds" % seconds, "size": 22, "colour": Color("ffb3b3") if urgent else GOLD, "outline": Color("0e1726"), "outline_size": 5.5, "tag": "bonus_timer"})
	# Wipes, when present in a test snapshot, must still cover the HUD last.
	out.append_array(super.build_hud(host, runtime))
	return out
