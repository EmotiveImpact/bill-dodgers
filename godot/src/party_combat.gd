extends RefCounted
## Stable mutable participant records for once-per-world collision/pickup passes.
## Begin/end bracket a SHARED phase; never refresh all proxies on every query.
## Actor-only callbacks may temporarily bind the host facade, including nested
## callbacks. Dirty record fields are reconciled before swapping the facade.
const FIELD_MAP := {
	"p": "player", "velocity": "velocity", "hearts": "hearts", "down": "down",
	"grounded": "grounded", "crouching": "crouching", "face": "face",
	"invincible": "invincible", "hurt_lock": "hurt_lock", "lock_animation": "lock_animation", "player_animation": "player_animation",
	"animation_time": "animation_time", "power": "power", "power_time": "power_time",
	"coins": "coins", "pop_count": "pop_count", "on_platform": "on_platform",
	"checkpoint": "checkpoint", "jump_held": "jump_held", "cooldown": "cooldown",
}
const SCENE_FIELDS := ["bag", "crate", "boss_hits", "px", "tied", "standing_surface", "safe_position"]
var active_slot := 0
var shared_phase := false
var _party
var _host: WeakRef
var _records: Dictionary = {}
var _baselines: Dictionary = {}
var _callback_depth := 0

func configure(party, host, initial_slot := 0) -> void:
	_party = party
	_host = weakref(host)
	active_slot = initial_slot
	shared_phase = false
	_callback_depth = 0
	_records.clear()
	_baselines.clear()
	for actor in _party.actors: _publish(actor)

func begin_shared(slot := -1) -> bool:
	if shared_phase or _host == null or _host.get_ref() == null: return false
	if slot >= 0: active_slot = slot
	var active = _party.actor_at(active_slot)
	if active == null: return false
	_capture(active, _host.get_ref())
	for actor in _party.actors: _publish(actor)
	shared_phase = true
	return true

func participants() -> Array:
	var result: Array = []
	for actor in _party.actors: result.append(_records[actor.slot])
	return result

func record(slot: int) -> Dictionary:
	return _records.get(slot, {})

func reconcile(slot: int) -> void:
	var actor = _party.actor_at(slot)
	if actor == null or not _records.has(slot): return
	var proxy: Dictionary = _records[slot]
	var baseline: Dictionary = _baselines[slot]
	# Only fields changed through the record win. This preserves newly captured
	# facade changes in unrelated fields (e.g. damage alongside a coin pickup).
	for key in FIELD_MAP:
		if proxy.has(key) and proxy.get(key) != baseline.get(key): actor.set(FIELD_MAP[key], proxy[key])
	for key in SCENE_FIELDS:
		if proxy.has(key) and (not baseline.has(key) or proxy[key] != baseline[key]): actor.scene_state[key] = proxy[key]
		elif not proxy.has(key) and baseline.has(key): actor.scene_state.erase(key)
	if proxy.has("jump_cd") and proxy.jump_cd != baseline.get("jump_cd"):
		actor.ai.jump_cooldown = float(proxy.jump_cd)
	if actor.hearts <= 0 and not actor.down: actor.mark_down()
	_publish(actor)

func end_shared(restore_slot := 0) -> bool:
	if not shared_phase or _callback_depth != 0: return false
	var host = _host.get_ref()
	if host == null: return false
	var active = _party.actor_at(active_slot)
	if active != null: _capture(active, host)
	for actor in _party.actors: reconcile(actor.slot)
	shared_phase = false
	active_slot = restore_slot
	var restore = _party.actor_at(restore_slot)
	if restore != null: _apply(restore, host)
	return true

func call_for_actor(slot: int, operation: Callable, arguments: Array = []) -> Variant:
	if not shared_phase or not operation.is_valid(): return null
	var actor = _party.actor_at(slot)
	var host = _host.get_ref()
	if actor == null or host == null: return null
	var previous := active_slot
	var current = _party.actor_at(previous)
	if current != null:
		_capture(current, host)
		reconcile(previous)
	reconcile(slot)
	active_slot = slot
	_apply(actor, host)
	_callback_depth += 1
	var result: Variant = operation.callv(arguments)
	_callback_depth -= 1
	_capture(actor, host)
	reconcile(slot)
	active_slot = previous
	var restore = _party.actor_at(previous)
	if restore != null:
		reconcile(previous)
		_apply(restore, host)
	return result

func credit_pop(slot: int, count := 1) -> void:
	# Operates through the record during a shared pass, including if slot is the
	# currently bound facade. Its dirty-field merge prevents capture rollback.
	if not shared_phase or not _records.has(slot): return
	var proxy: Dictionary = _records[slot]
	proxy.pop_count = int(proxy.pop_count) + maxi(0, count)

func credit_coin(slot: int, count := 1) -> void:
	# Shared kitty is the caller's separate once-per-coin responsibility.
	if not shared_phase or not _records.has(slot): return
	var proxy: Dictionary = _records[slot]
	proxy.coins = int(proxy.coins) + maxi(0, count)

func _publish(actor) -> void:
	var proxy: Dictionary = _records.get(actor.slot, {})
	proxy.id = actor.slot
	proxy.slot = actor.slot
	proxy.checkout_id = actor.slot
	proxy.host_player = false
	proxy.cpu = actor.cpu
	proxy.remote = actor.remote
	proxy.out = actor.out
	proxy.height = actor.character_height()
	proxy.character = actor.character
	for key in FIELD_MAP: proxy[key] = actor.get(FIELD_MAP[key])
	proxy.jump_cd = float(actor.ai.jump_cooldown)
	for key in SCENE_FIELDS:
		if actor.scene_state.has(key): proxy[key] = actor.scene_state[key]
		else: proxy.erase(key)
	_records[actor.slot] = proxy
	# All tracked fields are value types. Scene object references (crate) remain
	# original identities; never deep-copy world-owned objects into actor state.
	_baselines[actor.slot] = proxy.duplicate()

func _capture(actor, host) -> void:
	if host.has_method("party_capture_scene"): host.party_capture_scene(actor)
	actor.capture_native(host)

func _apply(actor, host) -> void:
	actor.apply_native(host)
	if host.has_method("party_apply_scene"): host.party_apply_scene(actor)
