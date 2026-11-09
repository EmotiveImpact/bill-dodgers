extends SceneTree
const PartyInput = preload("res://src/party_input.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func _initialize() -> void:
	var input = PartyInput.new()
	var p1: Dictionary = input.from_snapshot(0, "p2", {KEY_A: true, KEY_G: true, KEY_R: true, KEY_W: true, KEY_E: true})
	check(not p1.left and not p1.jump and not p1.special and not p1.aim and not p1.shoot, "P2 keyboard never controls P1")
	var p2: Dictionary = input.from_snapshot(1, "p2", {KEY_A: true, KEY_G: true, KEY_R: true, KEY_W: true, KEY_E: true})
	check(p2.left and p2.jump and p2.special and p2.aim and p2.shoot, "source patched P2 bindings include E fire")
	p1 = input.from_snapshot(0, "p2", {KEY_UP: true})
	check(p1.aim and not p1.jump and not p1.shoot, "source patched up aims without jump or auto fire")
	p1 = input.from_snapshot(0, "solo", {KEY_A: true, KEY_Z: true, KEY_X: true, KEY_C: true})
	check(p1.left and p1.jump and p1.shoot and p1.special, "native solo aliases retained")
	p2 = input.from_snapshot(1, "p2", {}, {"jump": true, "shoot": true})
	check(not p2.jump and not p2.shoot, "P1 touch never reaches P2")
	p1 = input.from_snapshot(0, "cpu", {}, {"jump": true, "shoot": true})
	check(p1.jump and p1.shoot, "P1 multitouch can jump and fire together")
	p2 = input.from_snapshot(1, "cpu", {KEY_G: true})
	check(not p2.jump, "human keys do not drive CPU mate")
	input.bind_gamepad(1, 9)
	p2 = input.from_snapshot(1, "p2", {}, {}, {9: {"stick": Vector2(0.5, -0.8), "buttons": [JOY_BUTTON_A, JOY_BUTTON_X]}})
	check(p2.right and p2.aim and p2.jump and p2.shoot, "assigned gamepad axes and simultaneous buttons")
	p1 = input.from_snapshot(0, "p2", {}, {}, {9: {"stick": Vector2(1, 0), "buttons": [JOY_BUTTON_A]}})
	check(not p1.right and not p1.jump, "assigned P2 pad never drives P1")
	p2 = input.from_snapshot(1, "p2", {}, {}, {9: {"stick": Vector2(0.1, -0.1), "buttons": []}})
	check(not p2.right and not p2.aim, "controller deadzone")
	p2 = input.from_snapshot(1, "p2", {}, {}, {})
	check(not p2.right and not p2.jump and input.gamepads[1] == 9, "disconnect neutralizes without remapping controller")
	input.release_all()
	p1 = input.from_snapshot(0, "solo", {KEY_Z: true, KEY_RIGHT: true})
	check(not p1.jump and not p1.right, "pause and focus loss suppress held actions")
	input.from_snapshot(0, "solo", {})
	p1 = input.from_snapshot(0, "solo", {KEY_Z: true, KEY_RIGHT: true})
	check(p1.jump and p1.right, "release then press rearms actions")
	input.bind_gamepad(0, 9)
	check(input.gamepads[1] == -1 and input.gamepads[0] == 9, "a controller belongs to only one actor")
	check(not input.bind_gamepad(2, 8) and not input.bind_gamepad(0, -2), "invalid controller binding rejected")
	var keyboard = PartyInput.new()
	var press := InputEventKey.new()
	press.physical_keycode = KEY_G
	press.keycode = KEY_G
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	check(keyboard.read(1, "p2").jump and not keyboard.read(0, "p2").jump, "engine key event reaches only P2 through actual polling path")
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	check(not keyboard.read(1, "p2").jump, "engine key release clears actual polling path")
	print("Party input: %d checks, %d failures. Synthetic input, not physical-device acceptance." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
