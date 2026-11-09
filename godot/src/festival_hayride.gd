extends "res://src/festival_queue_rush.gd"
## Hay ride extension, game/3-5/index.html:855–860,1309–1311,1321–1338.
## Shared queue rules supply auto/warmup/branches/events/end predicate.
## Seconds, absolute feet and px/s. Never a host.boss or a completion gate.
var harvester: Dictionary = {}

func supports(id: String) -> bool: return id == "3-5"

func reset(host) -> void:
	super.reset(host)
	harvester = {}

func bind_trailer(host, runtime) -> void:
	# Fresh load only, AFTER live surfaces exist, BEFORE initial floor lookup.
	if not supports(host.level_id): return
	var config: Dictionary = host.meta.get("l3", {}).get("trailer", {})
	if config.is_empty(): return
	var index := int(host.level.get("solids", []).size()) + int(config.plat)
	runtime.trailer = runtime.surfaces(host)[index]
	runtime.trailer.dx = 0.0

func trailer_tick(host, runtime) -> void:
	if not _active(host, runtime) or runtime.trailer.is_empty(): return
	var deck: Dictionary = runtime.trailer
	deck.row[0] += runtime.cam_dx
	deck.row[1] += runtime.cam_dx
	deck.dx = runtime.cam_dx
	# Source carries bots by dx only, after mover/trailer updates. Cached
	# surface identities are shared with landing and include bubbled bots.
	for bot in host.enemies:
		var surface: Dictionary = bot.get("surface", {})
		if surface.is_empty() or not float(surface.get("dx", 0)) or bot.get("hop", null) != null or bot.state == "pop": continue
		bot.p.x += float(surface.dx)
		bot.p.y = float(surface.row[2])

func scene_translate(distance: float, runtime) -> void:
	if not runtime.trailer.is_empty():
		runtime.trailer.row[0] += distance
		runtime.trailer.row[1] += distance
	# Do not overwrite dx: this is source sceneJump, not normal late motion.
	if not harvester.is_empty() and not harvester.get("done", false): harvester.x += distance

func harvester_tick(dt: float, host, runtime) -> void:
	if not _active(host, runtime) or runtime.trailer.is_empty(): return
	var config: Dictionary = host.meta.get("l3", {}).get("harv", {})
	if harvester.is_empty() and not config.is_empty() and host.camera.x >= float(config.cam):
		var hp: float = float(config.hp) * (1.3 if host.combat.participant_count > 1 else 1.0)
		harvester = {"x": host.camera.x - 420, "hp": hp, "max": hp, "flash": 0.0, "t": 0.0, "dead": false}
		host.sfx("warn")
		_emit(host, {"type": "harvester_start", "banner": "Warning!", "sub": "A harvester bot is right behind you", "warn": true, "boss_music": true, "say": "Warning. A harvester bot is chasing the trailer. Turn round and shoot it."})
	if harvester.is_empty(): return
	var h := harvester
	var row: Array = runtime.trailer.row
	h.t += dt
	h.flash = maxf(0, float(h.flash) - dt)
	if h.hp <= 0:
		if not h.dead:
			h.dead = true
			h.t = 0.0
			host.sfx("pop")
			host.sfx("stomp")
			host.add_coins(Vector2(row[0] + 80, row[2] - 100), 14)
			_emit(host, {"type": "harvester_down", "boss_music": false, "shake": 14, "bits": [Vector2(h.x - 100, row[2] - 100), Vector2(h.x - 140, row[2] - 100), Vector2(h.x - 180, row[2] - 100), Vector2(h.x - 220, row[2] - 100), Vector2(h.x - 260, row[2] - 100)], "position": Vector2(row[0] + 100, row[2] - 220), "text": "Harvested!", "say": "The harvester bot is beaten."})
		h.x += runtime.cam_dx - 300 * dt
		if h.t > 3.0: harvester = {"dead": true, "hp": 0.0, "x": -1e9, "flash": 0.0, "t": 0.0, "done": true}
		return
	h.x += runtime.cam_dx
	var goal: float = row[0] + (40 if sin(float(h.t) / 2.6) > 0.6 else -60)
	h.x = move_toward(float(h.x), goal, 50 * dt)
	# Late unswept test sees shots surviving ordinary enemies/boss/crates/walls.
	# Each hit always costs one HP and shoves six pixels, even ability ghosts.
	for shot in host.bullets:
		if shot.get("enemy", false) or shot.get("dead", false): continue
		if shot.p.x < h.x + 10 and shot.p.x > h.x - 340 and shot.p.y > float(row[2]) - 300:
			shot.dead = true
			shot.life = 0.0
			h.hp -= 1
			h.flash = 0.08
			h.x -= 6
			host.sfx("hitBot")
	# No early death return: source scans remaining shots, harms and can shoot
	# in the lethal frame. Death/drop happens next late update.
	for player in host.combat._living(host):
		if player.p.x < h.x + 30 and absf(player.p.y - float(row[2])) < 60: host.combat._hurt(host, player, player.p.x - 60)
	if runtime.rng.randf() < dt / 2.6:
		host.combat._bill(host, Vector2(h.x - 120, row[2] - 280), Vector2(250 + runtime.rng.randf() * 200, -400), 1400, "big")
		host.sfx("throw")

func _emit(host, event: Dictionary) -> void:
	if event.has("say"): host.status = String(event.say)
	if host.has_method("festival_event"): host.festival_event(event)

func snapshot() -> Dictionary:
	var data := super.snapshot()
	data.harvester = harvester.duplicate(true)
	return data
