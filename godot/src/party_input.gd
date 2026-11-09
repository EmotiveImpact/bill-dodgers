extends RefCounted
## Source patched keyboard bindings; P1 touch never leaks into P2. Controller
## assignments are explicit and stable across disconnection, not sorted per frame.
const ACTIONS := ["left", "right", "jump", "down", "shoot", "aim", "special", "dash"]
const P1 := {"left": [KEY_LEFT], "right": [KEY_RIGHT], "jump": [KEY_Z], "down": [KEY_DOWN], "shoot": [KEY_SPACE, KEY_X, KEY_K], "aim": [KEY_UP], "special": [KEY_C], "dash": [KEY_SHIFT, KEY_Q]}
const P2 := {"left": [KEY_A], "right": [KEY_D], "jump": [KEY_G], "down": [KEY_S], "shoot": [KEY_F, KEY_E], "aim": [KEY_W], "special": [KEY_R], "dash": [KEY_T]}
const SOLO_ALIASES := {"left": KEY_A, "right": KEY_D, "down": KEY_S}
const DEADZONE := 0.25
var gamepads := {0: -1, 1: -1}
var _blocked := [{}, {}]

func bind_gamepad(slot: int, device: int) -> bool:
	if slot not in [0, 1] or device < -1: return false
	var other := 1 - slot
	if device >= 0 and int(gamepads[other]) == device: gamepads[other] = -1
	gamepads[slot] = device
	return true

func release_all() -> void:
	# Call for focus loss, pause, rotation or mode changes. The first neutral
	# observation rearms each action, so held keys cannot fire on resume.
	for slot in 2:
		for action in ACTIONS: _blocked[slot][action] = true

func read(slot: int, mode: String, touch: Dictionary = {}) -> Dictionary:
	var keys: Dictionary = {}
	for bindings in [P1, P2]:
		for action in bindings:
			for key in bindings[action]: keys[key] = Input.is_physical_key_pressed(key)
	var pads: Dictionary = {}
	for device in Input.get_connected_joypads():
		var buttons: Array = []
		for button in [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
			if Input.is_joy_button_pressed(device, button): buttons.append(button)
		pads[device] = {"stick": Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)), "buttons": buttons}
	return from_snapshot(slot, mode, keys, touch, pads)

func from_snapshot(slot: int, mode: String, keys: Dictionary = {}, touch: Dictionary = {}, pads: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	for action in ACTIONS: result[action] = false
	if slot not in [0, 1] or (slot == 1 and mode != "p2"): return result
	var bindings: Dictionary = P1 if slot == 0 else P2
	for action in ACTIONS:
		for key in bindings[action]: result[action] = result[action] or bool(keys.get(key, false))
		if slot == 0:
			result[action] = result[action] or bool(touch.get(action, false))
			# Preserve the native one-player convenience, without P1 consuming P2 keys.
			if mode != "p2" and SOLO_ALIASES.has(action): result[action] = result[action] or bool(keys.get(SOLO_ALIASES[action], false))
	var device := int(gamepads[slot])
	if device >= 0 and pads.has(device):
		var pad: Dictionary = pads[device]
		var stick: Vector2 = pad.get("stick", Vector2.ZERO)
		var buttons: Array = pad.get("buttons", [])
		result.left = result.left or stick.x < -DEADZONE or JOY_BUTTON_DPAD_LEFT in buttons
		result.right = result.right or stick.x > DEADZONE or JOY_BUTTON_DPAD_RIGHT in buttons
		result.down = result.down or stick.y > DEADZONE or JOY_BUTTON_DPAD_DOWN in buttons
		result.aim = result.aim or stick.y < -DEADZONE or JOY_BUTTON_DPAD_UP in buttons
		result.jump = result.jump or JOY_BUTTON_A in buttons
		result.shoot = result.shoot or JOY_BUTTON_X in buttons or JOY_BUTTON_RIGHT_SHOULDER in buttons
		result.special = result.special or JOY_BUTTON_Y in buttons
		result.dash = result.dash or JOY_BUTTON_LEFT_SHOULDER in buttons
	for action in ACTIONS:
		if _blocked[slot].get(action, false):
			if not result[action]: _blocked[slot].erase(action)
			result[action] = false
	return result
