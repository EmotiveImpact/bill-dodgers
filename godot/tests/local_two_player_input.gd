extends RefCounted
## Synthetic engine events, NOT a physical keyboard/controller/phone test.
const KEYS := [
	{"left": KEY_LEFT, "right": KEY_RIGHT, "jump": KEY_Z, "down": KEY_DOWN, "shoot": KEY_X, "aim": KEY_UP, "special": KEY_C, "dash": KEY_Q},
	{"left": KEY_A, "right": KEY_D, "jump": KEY_G, "down": KEY_S, "shoot": KEY_F, "aim": KEY_W, "special": KEY_R, "dash": KEY_T},
]
var held: Dictionary = {}
var event_count := [0, 0]

func controls(first: Dictionary = {}, second: Dictionary = {}) -> void:
	for slot in 2:
		var wanted: Dictionary = first if slot == 0 else second
		for action in KEYS[slot]:
			var key: int = KEYS[slot][action]
			var pressed: bool = wanted.get(action, false)
			if pressed == held.get(key, false): continue
			var event := InputEventKey.new()
			event.keycode = key
			event.physical_keycode = key
			event.pressed = pressed
			Input.parse_input_event(event)
			held[key] = pressed
			event_count[slot] += 1
	Input.flush_buffered_events()

func frame(game, first: Dictionary = {}, second: Dictionary = {}, dt := 1.0 / 60.0) -> void:
	controls(first, second)
	# Exactly one real production input poll / world frame, never one per actor.
	game._physics_process(dt)

func release() -> void:
	controls()
