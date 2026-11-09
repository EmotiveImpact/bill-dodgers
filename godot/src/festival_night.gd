extends RefCounted
## After-dark rules. Shared WorldThree owns tents, scene/checkpoint and mini;
## FestivalBoss owns the configurable Bailiff. Seconds, absolute world pixels.
## Source game/3-3/index.html:732,1144–1163,1287,1300,1306,1316–1317.
const COLORS := ["#ff8fc7", "#ffd23f", "#7fd6ff", "#9be37a"]
var dark := 0.0
var flash_time := 0.0
var fireworks: Array = []
var _fires: Array = []
var _authored_tent_glows: Array = []

func supports(id: String) -> bool: return id == "3-3"

func reset(host) -> void:
	dark = float(host.meta.get("l3", {}).get("dark", 0))
	flash_time = 0.0
	fireworks.clear()
	_fires = host.level.get("fires", []).duplicate(true)
	_authored_tent_glows.clear()
	# JS TENTS maps only the first FOUR columns. Preserve that effective
	# behavior: the fifth authored flag does not become t.glow in the source.
	for row in host.level.get("tents", []):
		_authored_tent_glows.append(row[4] if row.size() > 4 else false)

func _active(host, runtime) -> bool:
	return supports(host.level_id) and runtime._can_step(host)

func timers_tick(dt: float, host, runtime) -> void:
	# At shared cheer decay, before tent/tied timers and checkpoint.
	if _active(host, runtime): flash_time = maxf(0, flash_time - dt)

func fire_hits(row: Array, feet: Vector2) -> bool:
	return absf(feet.x - float(row[0])) < 34 and absf(feet.y - float(row[1])) < 30

func fires_tick(host, runtime) -> void:
	# After checkpoint/banner damage; before moving surfaces/spotlights.
	if not _active(host, runtime): return
	for row in _fires:
		if host.has_method("combat_participants"):
			for p in host.combat_participants():
				if int(p.hearts) <= 0 or p.get("down", false) or not fire_hits(row, p.p): continue
				if p.get("host_player", false): host.hurt_player(float(row[0]))
				else: host.hurt_combat_participant(p, float(row[0]))
		elif host.hearts > 0 and fire_hits(row, host.player): host.hurt_player(float(row[0]))

func fireworks_tick(dt: float, host, runtime) -> void:
	# After spotlight phase, BEFORE mini trigger. Born sparks age this frame.
	# Consume one chance draw/frame, not a timer/Poisson approximation. RNG is
	# runtime-owned and injectable for deterministic tests; draw never uses it.
	if not _active(host, runtime): return
	if dark != 0 and runtime.rng.randf() < dt / 7.0:
		var x: float = host.camera.x + 100 + runtime.rng.randf() * (host.view_width() - 200)
		var y: float = host.view_top() + 60 + runtime.rng.randf() * 100
		var color: String = COLORS[mini(3, floori(runtime.rng.randf() * 4))]
		var sparks: Array = []
		for i in range(22):
			sparks.append(Vector2(cos(i * 0.2856) * (0.8 + runtime.rng.randf() * 0.4), sin(i * 0.2856) * (0.8 + runtime.rng.randf() * 0.4)))
		fireworks.append({"x": x, "y": y, "col": color, "t": 0.0, "s": sparks})
		flash_time = 0.5
		if host.has_method("festival_event"): host.festival_event({"type": "firework", "tone": {"from": 200, "to": 60, "duration": 0.4, "wave": "sine", "volume": 0.3}, "noise": {"duration": 0.4, "volume": 0.15, "frequency": 900, "delay": 0.05}})
	for firework in fireworks: firework.t += dt
	fireworks = fireworks.filter(func(f): return f.t < 1.4)

func darkness_alpha() -> float:
	return maxf(0, 1 - flash_time / 0.6) * (dark if dark != 0 else 0.8)

func snapshot() -> Dictionary:
	return {"dark": dark, "flash_time": flash_time, "darkness_alpha": darkness_alpha(), "fireworks": fireworks.duplicate(true), "fires": _fires.duplicate(true), "authored_tent_glows": _authored_tent_glows.duplicate()}
