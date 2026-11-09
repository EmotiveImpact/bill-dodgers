extends RefCounted
## Source World 2 lvAuto and the late flame/low/block pass, deliberately isolated.
## Feet/positions are absolute pixels, velocities px/s, and clocks seconds.
## The owner integrates these phases; this component enables no stage by itself.
const KINDS := ["boost", "flame", "low", "block"]

var speed := 0.0
var boost := false
var elapsed := 0.0 # Snapshot of host.elapsed (source levelT), never a second clock.
var hazards: Array = []
var _base_speed := 0.0
var _ride := 0.0
var _host_id := 0
var _level_id := ""
var _generation := -1
var _runtime: WeakRef

func reset(host, runtime) -> void:
	_host_id = host.get_instance_id()
	_level_id = host.level_id
	_generation = runtime.run_generation
	_runtime = weakref(runtime)
	hazards = runtime.hazards.duplicate(true)
	_base_speed = float(host.level.get("auto", 0)) * 1000.0
	_ride = float(host.level.get("ride", 0))
	speed = _base_speed
	boost = false
	elapsed = float(host.elapsed)

func _can_step(host, runtime = null) -> bool:
	if _runtime == null: return false
	var owner = _runtime.get_ref()
	return owner != null and (runtime == null or runtime == owner) and owner.run_generation == _generation and host.get_instance_id() == _host_id and host.level_id == _level_id and host.mode == "play"

func auto_displacement(dt: float, host) -> float:
	# Invoke after player motion, before this frame's wave activation/completion.
	# Only the owner moves/clamps the camera; players are NOT carried or locked.
	if not _can_step(host) or _base_speed == 0: return 0.0
	elapsed = float(host.elapsed)
	var probe: float = host.camera.x + host.view_width() * 0.4
	boost = hazards.any(func(h): return h is Array and not h.is_empty() and h[0] == "boost" and probe > float(h[1]) and probe < float(h[2]))
	var living := _living(host)
	var front: float = host.camera.x
	if not living.is_empty():
		front = float(living[0].p.x)
		for player in living: front = maxf(front, float(player.p.x))
	var push := clampf(((front - host.camera.x) / host.view_width() - 0.5) * 400.0, 0.0, 120.0)
	var active_wave: bool = host.combat.waves.any(func(wave): return wave.started and not wave.done)
	var want := _base_speed * (1.55 if boost else 1.0) * (0.6 if active_wave else 1.0) + push
	speed += (want - speed) * minf(1.0, dt / 0.7)
	return speed * dt

func flame_phase(hazard: Array) -> float:
	# Evaluate in source milliseconds before converting back. Reading this is
	# pure: render count cannot advance gameplay or consume gameplay randomness.
	var offset := float(hazard[4]) if hazard.size() > 4 else 0.0
	return fposmod(elapsed * 1000.0 + offset, float(hazard[3])) / 1000.0

func hazards_tick(_dt: float, host, runtime) -> void:
	# Source order: shared drops -> this pass -> late carts/drones -> pickups.
	# main.elapsed advanced BEFORE player physics; runtime.elapsed may not have.
	if not _can_step(host, runtime): return
	elapsed = float(host.elapsed)
	for hazard in hazards:
		if not hazard is Array or hazard.is_empty(): continue
		match hazard[0]:
			"flame":
				if flame_phase(hazard) >= 1.0: continue
				for player in _living(host):
					if absf(player.p.x - float(hazard[1])) < 36 and player.p.y > float(hazard[2]) - 175 and player.p.y <= float(hazard[2]) + 4:
						_hurt(host, player, float(hazard[1]) - float(player.get("face", 1)))
			"low":
				for player in _living(host):
					var feet: float = player.p.y
					var top := feet - float(player.get("height", host.character_height())) * (0.56 if player.get("crouching", false) else 0.86) - _ride * 0.4
					var underside := float(hazard[2]) - float(hazard[3])
					if absf(player.p.x - float(hazard[1])) < 52 and top < underside and feet > underside - 40:
						_hurt(host, player, float(hazard[1]) + 200)
			"block":
				for player in _living(host):
					if absf(player.p.x - float(hazard[1])) < float(hazard[3]) / 2 + 12 and player.p.y > float(hazard[2]) - float(hazard[4]) + 8 and player.p.y <= float(hazard[2]) + 4:
						_hurt(host, player, float(hazard[1]) + 300)
						# This checks post-call inv, not whether hurt dealt damage.
						# Continue invulnerability also bounces; Maya's 900ms does not.
						if player.get("host_player", false):
							if host.invincible > 1.4:
								host.velocity.y = -700.0
								host.grounded = false
						elif float(player.get("invincible", 0)) > 1.4:
							var velocity: Vector2 = player.get("velocity", Vector2.ZERO)
							velocity.y = -700.0
							player.velocity = velocity
							player.grounded = false

func _living(host) -> Array:
	# Same roster and damage callbacks as supermarket_combat/hazards. Future
	# mutable non-host records additionally expose invincible/velocity for bounce.
	if host.has_method("combat_participants"):
		return host.combat_participants().filter(func(player): return not player.get("down", false) and int(player.hearts) > 0)
	if host.hearts <= 0: return []
	# Native hurt_player changes the displayed animation immediately, whereas
	# JS sets lockAct and leaves act unchanged until the next player update.
	# Retain a crouch interrupted by damage this frame. A jump/aim pose still
	# overrides stale held-down state; next-frame hurt lock clears crouching.
	var crouch: bool = host.crouching and host.player_animation in ["crouch", "hit"]
	return [{"host_player": true, "p": host.player, "hearts": host.hearts, "height": host.character_height(), "crouching": crouch, "face": host.face}]

func _hurt(host, player: Dictionary, from_x: float) -> void:
	if player.get("host_player", false): host.hurt_player(from_x)
	else: host.hurt_combat_participant(player, from_x)
