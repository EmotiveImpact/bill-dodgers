extends RefCounted
## Big-top late phases, source game/3-4/index.html:729–730,1294–1315.
## Seconds and absolute feet. The shared runtime owns geometry and player carry.
var movers: Array = []
var spots: Array = []
var events_done: Array[int] = []
var _events: Array = []

func supports(id: String) -> bool: return id == "3-4"

func reset(host, runtime) -> void:
	# New level instance: bind only AFTER shared solids/platforms were copied.
	movers.clear()
	spots.clear()
	events_done.clear()
	_events = host.meta.get("l3", {}).get("events", []).duplicate(true)
	if not supports(host.level_id): return
	var surfaces: Array = runtime.surfaces(host)
	var count: int = host.level.get("solids", []).size()
	for row in host.level.get("movers", []):
		var index := int(row[0])
		var base: Array = host.level.plats[index]
		movers.append({"q": surfaces[count + index], "index": index, "x0": float(base[0]), "x1": float(base[1]), "top": float(base[2]), "ax": float(row[1]), "ay": float(row[2]), "per": float(row[3]) / 1000.0, "ph": float(row[4]) if row.size() > 4 else 0.0})
	for row in host.level.get("spots", []):
		spots.append({"x": float(row[0]), "y": float(row[1]), "on": false, "hp": 2, "a": 0.0, "t": runtime.rng.randf() * 6.0})

func reset_round() -> void:
	# Source reset3 preserves randomized t and existing mover position/deltas.
	# A fresh native run uses reset instead, consistently with shared geometry.
	events_done.clear()
	for spot in spots:
		spot.on = false
		spot.hp = 2

func _active(host, runtime) -> bool:
	return supports(host.level_id) and runtime._can_step(host)

func events_tick(host, runtime) -> void:
	if not _active(host, runtime): return
	for i in range(_events.size()):
		var row: Array = _events[i]
		if i in events_done or host.camera.x < float(row[0]): continue
		events_done.append(i)
		var event := {"banner": String(row[1]), "sub": String(row[2]), "say": String(row[1]) + ". " + String(row[2])}
		host.status = event.banner + ". " + event.sub
		if host.has_method("festival_event"): host.festival_event(event)

func movers_tick(host, runtime) -> void:
	if not _active(host, runtime): return
	for mover in movers:
		# Source literal6.283 is intentional, NOT TAU. Base is immutable.
		var k := sin(float(runtime.level_time) / float(mover.per) * 6.283 + float(mover.ph))
		var surface: Dictionary = mover.q
		var row: Array = surface.row
		var x := float(mover.x0) + float(mover.ax) * k
		var top := float(mover.top) + float(mover.ay) * absf(k)
		surface.dx = x - float(row[0])
		surface.dy = top - float(row[2])
		row[0] = x
		row[1] = float(mover.x1) + float(mover.ax) * k
		row[2] = top
	# Includes bubbled bots already reinserted by the ordinary enemy pass.
	for bot in host.enemies:
		var surface: Dictionary = bot.get("surface", {})
		if surface.is_empty() or not float(surface.get("dx", 0)) or bot.get("hop", null) != null or bot.state == "pop": continue
		bot.p.x += float(surface.dx)
		bot.p.y = float(surface.row[2])

func spotlights_tick(dt: float, host, runtime) -> void:
	# AFTER ordinary projectiles and their wall/camera cleanup, not a sweep.
	if not _active(host, runtime): return
	for spot in spots:
		spot.t += dt
		if not spot.on:
			for shot in host.bullets:
				if shot.get("enemy", false) or shot.get("dead", false): continue
				if absf(shot.p.x - float(spot.x)) >= 26 or absf(shot.p.y - float(spot.y) - 4) >= 26: continue
				shot.dead = true
				spot.hp -= 1 # Damage multiplier/ghost does not change switch HP.
				host.sfx("hitBot")
				if spot.hp <= 0:
					spot.on = true
					host.sfx("power")
					if host.has_method("festival_event"): host.festival_event({"type": "spotlight_on", "position": Vector2(spot.x, spot.y - 30), "text": "Lights on!", "colour": "#fff3b0"})
		# No inner-loop break after activation: source consumes remaining hits.
		if spot.on:
			for bot in host.enemies:
				if bot.state != "pop" and beam_hits(spot, bot.p): bot.dz = maxf(float(bot.get("dz", 0)), 0.25)

func beam_hits(spot: Dictionary, feet: Vector2) -> bool:
	var dy := feet.y - 60 - float(spot.y)
	return dy > 0 and absf(atan2(feet.x - float(spot.x), dy) - sin(float(spot.t) / 0.9) * 0.6) < 0.2

func snapshot() -> Dictionary:
	return {"movers": movers.duplicate(true), "spots": spots.duplicate(true), "events_done": events_done.duplicate()}
