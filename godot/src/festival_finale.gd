extends RefCounted
## Ticket Tout finale hooks, game/3-6/index.html:1320,1324.
## Shared FestivalBoss owns attacks/stage hops/jar physics. Seconds, pixels.

func supports(id: String) -> bool: return id == "3-6"

func sync_visuals(host, runtime) -> void:
	# Source toutMove samples x once for each distinct levelT, even when draw
	# runs repeatedly. Simulation owns that snapshot in the native renderer.
	if not supports(host.level_id) or host.boss == null: return
	var state: Dictionary = host.boss.state
	if state.has("visual_t") and state.visual_t == runtime.level_time: return
	state.moved = absf(float(state.x) - float(state.get("visual_x", state.x))) > 0.05
	state.visual_x = state.x
	state.visual_t = runtime.level_time

func after_mini_trigger(dt: float, host, runtime) -> void:
	if not supports(host.level_id) or not runtime._can_step(host): return
	var config: Dictionary = host.meta.get("l3", {}).get("boss", {})
	if not config.is_empty() and host.boss == null and host.camera.x >= float(host.level.w) - host.view_width() - 2 and host.combat.waves.all(func(wave): return wave.done):
		var entry := {"cam": float(host.level.w) - host.view_width()}
		entry.merge(config.duplicate(true), true)
		host.combat.start_boss(host, entry)
	# Source's late magnet precedes boss and jar clocks, using the previous
	# jar age. It is not a height-dependent pickup or an automatic clear.
	if host.boss == null: return
	var jar: Dictionary = host.boss.state.get("jar", {})
	if jar.is_empty() or jar.get("got", false) or float(jar.t) <= 1.4: return
	var players: Array = host.combat._living(host)
	if players.is_empty(): return
	var nearest: Dictionary = players[0]
	for player in players:
		if absf(player.p.x - jar.x) < absf(nearest.p.x - jar.x): nearest = player
	jar.x = move_toward(float(jar.x), nearest.p.x, 120 * dt)
