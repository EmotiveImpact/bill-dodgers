extends SceneTree
const Party = preload("res://src/party_runtime.gd")
const Bridge = preload("res://src/party_combat.gd")
class Host:
	extends "res://src/party_actor.gd"
	var score := 0
	var elapsed := 10.0
	var camera := Vector2(500, 0)
	var bridge
	var victims: Array = []
	var scene_safe := Vector2(100, 482)
	var scene_seen: Array = []
	func party_capture_scene(actor): actor.scene_state.safe_position = scene_safe
	func party_apply_scene(actor): scene_safe = actor.scene_state.get("safe_position", actor.player)
	func shift_scene_safe():
		scene_seen.append(scene_safe)
		scene_safe.x += 10
	func damage(amount: int) -> void:
		victims.append(bridge.active_slot)
		hearts -= amount
		invincible = 1.5
		velocity.x = -350
	func nested_damage() -> void:
		hearts -= 1
		bridge.call_for_actor(1, damage, [1])
		power = "split"
	func callback_pickups() -> void:
		hearts -= 1
		var records: Array = bridge.participants()
		records[bridge.active_slot].coins += 2
		bridge.credit_pop(bridge.active_slot)
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func _initialize() -> void:
	var party = Party.new()
	party.configure("p2", "jp", "maya")
	party.start("2-6", Vector2(500, 482))
	var first = party.actors[0]
	var second = party.actors[1]
	var host = Host.new()
	first.apply_native(host)
	var bridge = Bridge.new()
	host.bridge = bridge
	first.scene_state.safe_position = Vector2(100, 482)
	second.scene_state.safe_position = Vector2(300, 482)
	bridge.configure(party, host)
	check(bridge.begin_shared(), "shared phase begins once")
	bridge.call_for_actor(1, host.shift_scene_safe)
	check(host.scene_seen == [Vector2(300, 482)] and second.scene_state.safe_position == Vector2(310, 482), "temporary actor callback binds and captures its own scene safe state")
	check(host.scene_safe == Vector2(100, 482), "temporary callback restores previous actor scene safe state")
	check(not bridge.begin_shared(), "shared phase cannot be nested or double ticked")
	var records: Array = bridge.participants()
	check(records.size() == 2 and records[0].id == 0 and records[1].checkout_id == 1 and not records[0].host_player, "stable explicit actor identities for every record")
	check(not records[0].remote and not records[0].out and not records[1].remote and not records[1].out, "local roster metadata defaults are published")
	second.remote = true
	second.out = true
	bridge._publish(second)
	check(records[1].remote and records[1].out and not records[0].remote and not records[0].out, "remote and out metadata belong to their actual actor")
	records[1].remote = false
	records[1].out = false
	bridge.reconcile(1)
	check(second.remote and second.out and records[1].remote and records[1].out, "read-only remote and out metadata cannot mutate actor state through proxies")
	second.remote = false
	second.out = false
	bridge._publish(second)
	records[1].coins += 1
	check(is_same(records[1], bridge.participants()[1]) and bridge.participants()[1].coins == 1, "repeated roster queries retain direct pickup mutations")
	records[1].power = "debit"
	records[1].power_time = 12.0
	records[1].p = Vector2(470, 400)
	records[1].velocity = Vector2(100, -40)
	records[1].hurt_lock = 0.06
	records[1].player_animation = "hit"
	var crate := {"p": Vector2(470, 300), "st": "carried"}
	records[1].crate = crate
	records[1].bag = 0.7
	bridge.call_for_actor(1, host.damage, [1])
	check(host.character == "jp" and host.hearts == 3 and host.player == first.player, "victim callback restores original host actor")
	check(second.hearts == 2 and second.player == Vector2(470, 400) and second.coins == 1, "callback honors prior direct position and coin mutations")
	check(second.power == "debit" and second.power_time == 12 and second.invincible == 1.5, "pickup and damage survive together")
	check(second.velocity.x == -350 and second.velocity.y == -40, "damage uses victim velocity not leader velocity")
	check(is_same(second.scene_state.crate, crate) and second.scene_state.bag == 0.7, "puzzle state keeps carried crate identity")
	bridge.credit_pop(0, 2)
	bridge.credit_coin(0, 5)
	bridge.call_for_actor(0, host.damage, [1])
	check(first.pop_count == 2 and first.coins == 5 and first.hearts == 2, "credits to active actor survive facade capture")
	var surface := {"row": [100, 800, 482], "plat": false}
	records[1].tied = 0.6
	records[1].standing_surface = surface
	records[1].safe_position = Vector2(700, 482)
	bridge.call_for_actor(1, host.shift_scene_safe)
	check(second.scene_state.tied == 0.6 and is_same(second.scene_state.standing_surface, surface), "scene-only tied and support writes preserve original object identity")
	check(second.scene_state.safe_position == Vector2(710, 482), "dirty proxy safe applies before callback and new captured safe is not overwritten")
	records[1].erase("standing_surface")
	bridge.reconcile(1)
	check(not second.scene_state.has("standing_surface") and not records[1].has("standing_surface"), "removed actor support stays removed across publication")
	bridge.end_shared()
	check(not bridge.shared_phase and host.character == "jp" and host.hearts == 2 and host.pop_count == 2, "shared phase reconciles then restores P1 facade")
	check(host.elapsed == 10 and host.camera == Vector2(500, 0) and host.score == 0, "bridge never changes world clock camera or shared kitty")
	check(not bridge.end_shared(), "double shared finish rejected")
	first.hearts = 3
	second.hearts = 3
	first.apply_native(host)
	bridge.begin_shared()
	bridge.call_for_actor(0, host.nested_damage)
	check(first.hearts == 2 and second.hearts == 2 and first.power == "split", "nested callbacks preserve outer scalar edits and restore actor")
	bridge.call_for_actor(1, host.callback_pickups)
	check(second.hearts == 1 and second.coins == 3 and second.pop_count == 1, "callback proxy writes and scalar writes reconcile without loss")
	bridge.participants()[1].p = Vector2(900, 300)
	bridge.participants()[1].grounded = false
	bridge.end_shared(1)
	check(host.character == "maya" and host.player == Vector2(900, 300) and not host.grounded, "world relocation writes reach actor and requested restore slot")
	bridge.begin_shared(1)
	bridge.call_for_actor(1, host.damage, [1])
	check(second.down and second.hearts == 0 and not party.all_down(), "down state reconciles without incorrectly ending whole party")
	bridge.end_shared()
	check(host.victims == [1, 0, 1, 1], "each targeted callback executes exactly once")
	print("Party combat bridge: %d checks, %d failures. Adapter transactions, not integrated co-op/device acceptance." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
