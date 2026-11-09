extends RefCounted
## Queue jump extension. Shared WorldThree owns surfaces, carry, recovery,
## checkpoint, wipe and objective clocks; FestivalCombat owns all wave/enemy AI.
## Source: game/3-2/index.html:426,638,667,1180–1182,1295,1305–1307,1327.
## Times are seconds; positions are absolute feet pixels.
var end_run := 0.0
var events_done: Array[int] = []
var _duck: Array = []
var _events: Array = []

func supports(id: String) -> bool:
	return id == "3-2"

func reset(host) -> void:
	end_run = 0.0
	events_done.clear()
	_duck = host.level.get("duck", []).duplicate(true)
	_events = host.meta.get("l3", {}).get("events", []).duplicate(true)

func _active(host, runtime) -> bool:
	return supports(host.level_id) and runtime._can_step(host)

func auto_displacement(dt: float, host, runtime, frame_elapsed: float) -> float:
	# frame_elapsed includes this frame's dt: source increments levelT before
	# updatePlayer/camera, whereas the shared runtime records it after_camera.
	if not _active(host, runtime) or host.mode != "play" or runtime.wiping or frame_elapsed <= 1.8 or runtime.end_time > 0: return 0.0
	if host.boss != null:
		var boss_state = host.boss.state
		if (boss_state.get("state", "") if boss_state is Dictionary else boss_state) != "down": return 0.0
	return float(host.level.get("auto", 0)) * 1000.0 * dt

func end_ok(host) -> bool:
	var config: Dictionary = host.meta.get("l3", {})
	return supports(host.level_id) and not config.get("noEnd", false) and not config.get("boss", false)

func scene_can_start(host, runtime) -> bool:
	# Auto scenes intentionally ignore live bots and unfinished waves.
	return _active(host, runtime)

func squash(host, runtime) -> bool:
	# Call after old-camera clamp, before drop/jump/gravity. Warmup and wipe
	# suppress scrolling, NOT squash. Recovery forces normal damage, not death.
	if not _active(host, runtime) or host.hearts <= 0: return false
	if runtime.inside_wall(host, host.player - Vector2(0, 10)):
		runtime.recover_from_fall(host)
		return true
	return false

func banner_hits(row: Array, feet: Vector2, height: float, action: String) -> bool:
	if feet.x < float(row[0]) - 10 or feet.x > float(row[1]) + 10: return false
	var top := feet.y - height * (0.6 if action == "crouch" else 0.86)
	return top < float(row[2]) and feet.y > float(row[2]) - 40

func banners_tick(host, runtime) -> void:
	# Call directly after shared checkpoint. Use source act, not raw down input.
	if not _active(host, runtime): return
	for row in _duck:
		if host.has_method("combat_participants"):
			for participant in host.combat_participants():
				if int(participant.hearts) <= 0 or participant.get("down", false): continue
				if not banner_hits(row, participant.p, float(participant.height), str(participant.get("player_animation", "crouch" if participant.get("crouching", false) else "idle"))): continue
				if participant.get("host_player", false): host.hurt_player(participant.p.x + 40)
				else: host.hurt_combat_participant(participant, participant.p.x + 40)
		elif host.hearts > 0 and banner_hits(row, host.player, host.character_height(), host.player_animation):
			host.hurt_player(host.player.x + 40)

func events_tick(host, runtime) -> void:
	# Call directly after shared scene-trigger pass, before coins/checkpoint.
	if not _active(host, runtime): return
	for i in range(_events.size()):
		var row: Array = _events[i]
		if i in events_done or host.camera.x < float(row[0]): continue
		events_done.append(i)
		var event := {"banner": String(row[1]), "sub": String(row[2]), "say": String(row[1]) + ". " + String(row[2])}
		host.status = event.banner + ". " + event.sub
		if host.has_method("festival_event"): host.festival_event(event)

func late_tick(dt: float, host, runtime) -> void:
	# Last levelUpdate hook, including the attested final clear base frame.
	if _active(host, runtime) and runtime.end_time > 0: end_run += dt

func snapshot() -> Dictionary:
	return {"end_run": end_run, "events_done": events_done.duplicate(), "duck": _duck.duplicate(true)}
