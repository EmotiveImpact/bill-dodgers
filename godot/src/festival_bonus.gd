extends RefCounted
## 3-S source bonus rules. Seconds, absolute world pixels. WorldThree owns
## authored coins and FestivalCombat owns collection/age/camera culling.
## The host consumes clear events through its ordinary, capability-gated
## completion path, which deliberately sweeps every surviving coin.
## Source game/3-S/index.html:623-629,1294-1298,1324-1327.
var timer_elapsed := 0.0
var timer_duration := 0.0
var completion_reported := false
var clear_reason := ""
var _host_id := 0
var _run_generation := -1

func supports(id: String) -> bool:
	return id == "3-S"

func reset(host) -> void:
	timer_elapsed = 0.0
	timer_duration = float(host.meta.get("l3", {}).get("timer", 0)) / 1000.0
	completion_reported = false
	clear_reason = ""
	_host_id = host.get_instance_id()
	_run_generation = host.world_three.run_generation

func _active(host, runtime) -> bool:
	return supports(host.level_id) and host.get_instance_id() == _host_id and runtime.run_generation == _run_generation and runtime._can_step(host) and host.mode == "play" and not completion_reported

func before_authored_coins(host, runtime) -> Dictionary:
	# Immediately after finds/scenes/events, BEFORE _authored_coins. A fresh
	# empty inventory is not completion. A later empty stay inventory is,
	# even when coins vanished behind the camera instead of being collected.
	if not _active(host, runtime) or timer_duration <= 0 or not runtime._coins_started: return {}
	if host.coins.any(func(coin): return bool(coin.get("stay", false))): return {}
	return _clear_event(host, "empty", "All collected!")

func late_tick(dt: float, host, runtime) -> Dictionary:
	# Last levelUpdate timer phase, AFTER jar attraction and BEFORE the base
	# updateBoss/updateJar calls. Do not advance this at objective_tick.
	if not _active(host, runtime) or timer_duration <= 0: return {}
	timer_elapsed += dt
	if timer_elapsed >= timer_duration: return _clear_event(host, "timeout", "Time's up!")
	return {}

func _clear_event(host, reason: String, label: String) -> Dictionary:
	completion_reported = true
	clear_reason = reason
	# Source banner is formed BEFORE stageClear sweeps the remaining coins.
	# Never add money here or erase coins: the normal completion path does it
	# once, together with the save and celebration.
	return {"type": "clear", "reason": reason, "banner": label, "sub": "£%d for the jar" % int(host.score), "timer_elapsed": timer_elapsed, "score_before_sweep": int(host.score), "remaining_coins": host.coins.size()}

func snapshot() -> Dictionary:
	return {"timer_elapsed": timer_elapsed, "timer_duration": timer_duration, "completion_reported": completion_reported, "clear_reason": clear_reason}
