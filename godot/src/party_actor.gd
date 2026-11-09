extends RefCounted
## Per-player state only. A host may swap this into its existing actor-phase API.
## Never capture camera, world time, score, enemies, bullets or scene singletons.
const Abilities = preload("res://src/abilities.gd")
const MovementSkills = preload("res://src/movement_skills.gd")
const NATIVE_FIELDS := [
	"character", "player", "velocity", "checkpoint", "face", "grounded", "jump_held",
	"cooldown", "invincible", "hearts", "on_platform", "drop_time", "crouching",
	"hurt_lock", "lock_animation", "shoot_time", "shoot_diagonal", "aim_time", "aim_up", "animation_time",
	"player_animation", "pop_count", "power", "power_time", "_last_floor", "_pre_grounded",
	"abilities", "movement_skills",
]
var slot := 0
var cpu := false
var remote := false
var out := false
var down := false
var revive := 0.0
var coins := 0
var character := "jp"
var player := Vector2.ZERO
var velocity := Vector2.ZERO
var checkpoint := Vector2.ZERO
var face := 1
var grounded := true
var jump_held := false
var cooldown := 0.0
var invincible := 0.0
var hearts := 3
var on_platform := false
var drop_time := 0.0
var crouching := false
var hurt_lock := 0.0
var lock_animation := "hit"
var shoot_time := 0.0
var shoot_diagonal := false
var aim_time := 0.0
var aim_up := false
var animation_time := 0.0
var player_animation := "idle"
var pop_count := 0
var power := ""
var power_time := 0.0
var _last_floor := 482.0
var _pre_grounded := true
var abilities = Abilities.new()
var movement_skills = MovementSkills.new()
## State that source stores on p (water, carried crate, support, bags, etc.).
## World adapters must move those fields here; shared world state stays shared.
var scene_state: Dictionary = {}
var ai := {"jump_cooldown": 0.0, "far_time": 0.0, "special_wait": 0.0}

func initialize(who: String, index: int, computer: bool, feet: Vector2, level_id: String, skills: Array = []) -> void:
	character = who
	slot = index
	cpu = computer
	player = feet
	checkpoint = feet
	_last_floor = feet.y
	abilities.reset(character, skills)
	movement_skills.reset(level_id, skills)

func is_alive() -> bool:
	return not down and not out and hearts > 0

func character_height() -> float:
	return float(Abilities.HEIGHTS.get(character, 180.0))

func participant() -> Dictionary:
	return {"slot": slot, "position": player, "alive": is_alive(),
		"height": character_height(), "crouching": crouching, "cpu": cpu}

func capture_native(host) -> void:
	for key in NATIVE_FIELDS: set(key, host.get(key))
	if hearts <= 0 and not down: mark_down()

func apply_native(host) -> void:
	for key in NATIVE_FIELDS: host.set(key, get(key))

func mark_down() -> void:
	hearts = 0
	down = true
	revive = 0
	hurt_lock = 0
	movement_skills.cancel_on_death()

func revive_nearby() -> void:
	down = false
	hearts = 2
	invincible = 2.2
	hurt_lock = 0.6
	lock_animation = "win"
	player_animation = "win"
	animation_time = 0
	revive = 0

func continue_in_place() -> void:
	down = false
	hearts = 3
	invincible = 2.5
	hurt_lock = 0
	lock_animation = "hit"
	revive = 0
	jump_held = true
