## AiDemon.gd
## NavigationAgent3D-based demon state machine.
## States: IDLE → WANDER → HAUNT → DISRUPT_SALT → ATTACK
## Difficulty: EASY / MEDIUM / HARD — damage and activity scale per night.

class_name AiDemon
extends CharacterBody3D

# ── Signals ────────────────────────────────────────────────────────────────────
signal attacked_player(damage: float)
signal salt_disrupted(position: Vector3)
signal state_changed(new_state: int)

# ── Enums ─────────────────────────────────────────────────────────────────────
enum State   { IDLE, WANDER, HAUNT, DISRUPT_SALT, ATTACK }
enum Difficulty { EASY, MEDIUM, HARD }

# ── Exports ───────────────────────────────────────────────────────────────────
@export var difficulty    : Difficulty = Difficulty.MEDIUM
@export var demon_index   : int = 0          # 0-3 matches AiDemon0-3
@export var move_speed    : float = 2.8
@export var attack_range  : float = 1.6      # metres
@export var attack_cooldown: float = 4.0

# ── State ─────────────────────────────────────────────────────────────────────
var state          : State = State.IDLE
var night_count    : int   = 0               # synced from QuestManager
var player         : CharacterBody3D = null
var salt_lines     : Array = []              # Array[Node3D] — registered externally

@onready var nav   : NavigationAgent3D = $NavigationAgent3D
var _attack_timer  : float = 0.0
var _state_timer   : float = 0.0
var _wander_target : Vector3 = Vector3.ZERO

# ── Difficulty tables (from game_design.md) ───────────────────────────────────
# Base hit-chance and per-night increase
const HIT_CHANCE_BASE := { Difficulty.EASY: 0.15, Difficulty.MEDIUM: 0.30, Difficulty.HARD: 0.30 }
const HIT_CHANCE_NIGHTLY := { Difficulty.EASY: 0.055, Difficulty.MEDIUM: 0.05, Difficulty.HARD: 0.05 }
const BASE_DAMAGE := 30.0
const MAX_ATTACKS_IN_ROW_EASY   := 2
const MAX_ATTACKS_IN_ROW_MEDIUM := 3

var _consecutive_attacks: int = 0

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	DayNightCycle.night_started.connect(_on_night_started)
	_set_state(State.IDLE)

func _physics_process(delta: float) -> void:
	night_count = QuestManager.night_count

	# Daytime restriction
	if not DayNightCycle.is_night:
		if difficulty == Difficulty.EASY or difficulty == Difficulty.MEDIUM:
			velocity = Vector3.ZERO
			return
		# HARD: after 3 nights, can act in daytime but at half damage
		if difficulty == Difficulty.HARD and night_count <= 3:
			velocity = Vector3.ZERO
			return

	_attack_timer  = max(_attack_timer - delta, 0.0)
	_state_timer  -= delta

	match state:
		State.IDLE:        _tick_idle(delta)
		State.WANDER:      _tick_wander(delta)
		State.HAUNT:       _tick_haunt(delta)
		State.DISRUPT_SALT:_tick_disrupt(delta)
		State.ATTACK:      _tick_attack(delta)

	move_and_slide()

# ── State ticks ────────────────────────────────────────────────────────────────
func _tick_idle(_delta: float) -> void:
	if _state_timer <= 0.0:
		var roll = randf()
		# HARD: can trick (mimic another demon / haunt)
		if difficulty == Difficulty.HARD and roll < 0.25:
			_set_state(State.HAUNT)
		elif roll < 0.5:
			_set_state(State.WANDER)
		else:
			_state_timer = randf_range(5.0, 15.0)

func _tick_wander(_delta: float) -> void:
	if nav.is_navigation_finished() or _state_timer <= 0.0:
		if randf() < 0.3 and player:
			_set_state(State.ATTACK)
			return
		# Pick a new random destination
		var offset = Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
		_wander_target = global_position + offset
		nav.target_position = _wander_target
		_state_timer = randf_range(8.0, 20.0)
	_move_toward_nav()

func _tick_haunt(_delta: float) -> void:
	# HARD only – disturb salt if nearby
	for salt in salt_lines:
		if is_instance_valid(salt) and global_position.distance_to(salt.global_position) < 3.0:
			_set_state(State.DISRUPT_SALT)
			return
	if _state_timer <= 0.0:
		_set_state(State.WANDER)

func _tick_disrupt(_delta: float) -> void:
	if not salt_lines.is_empty():
		var closest = _closest_salt()
		if closest and global_position.distance_to(closest.global_position) < 1.2:
			closest.queue_free()
			salt_lines.erase(closest)
			salt_disrupted.emit(closest.global_position)
			_set_state(State.IDLE)
			return
		nav.target_position = closest.global_position if closest else global_position
		_move_toward_nav()
	else:
		_set_state(State.IDLE)

func _tick_attack(_delta: float) -> void:
	if not player:
		_set_state(State.IDLE)
		return
	nav.target_position = player.global_position
	_move_toward_nav()
	var dist = global_position.distance_to(player.global_position)
	if dist <= attack_range and _attack_timer <= 0.0:
		_do_attack()

# ── Attack logic ───────────────────────────────────────────────────────────────
func _do_attack() -> void:
	var max_row = MAX_ATTACKS_IN_ROW_EASY if difficulty == Difficulty.EASY else MAX_ATTACKS_IN_ROW_MEDIUM
	if _consecutive_attacks >= max_row:
		_consecutive_attacks = 0
		_set_state(State.WANDER)
		return

	var hit_chance = HIT_CHANCE_BASE[difficulty] + HIT_CHANCE_NIGHTLY[difficulty] * night_count
	hit_chance     = clampf(hit_chance, 0.0, 0.95)

	if randf() < hit_chance:
		var dmg = BASE_DAMAGE
		# HARD daytime = half damage after 3 nights
		if difficulty == Difficulty.HARD and not DayNightCycle.is_night and night_count > 3:
			dmg *= 0.5
		# MEDIUM daytime = half damage
		if difficulty == Difficulty.MEDIUM and not DayNightCycle.is_night:
			dmg *= 0.5
		attacked_player.emit(dmg)
		_consecutive_attacks += 1
	else:
		_consecutive_attacks = 0

	_attack_timer = attack_cooldown

# ── Helpers ────────────────────────────────────────────────────────────────────
func _move_toward_nav() -> void:
	if nav.is_navigation_finished():
		velocity = Vector3.ZERO
		return
	var next = nav.get_next_path_position()
	var dir  = (next - global_position).normalized()
	velocity = dir * move_speed
	# Face movement direction
	if dir.length() > 0.01:
		var look_target = global_position + dir
		look_at(look_target, Vector3.UP)

func _set_state(new_state: State) -> void:
	state         = new_state
	_state_timer  = randf_range(6.0, 18.0)
	state_changed.emit(new_state)

func _closest_salt() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for s in salt_lines:
		if is_instance_valid(s):
			var d = global_position.distance_to(s.global_position)
			if d < best_d:
				best_d = d
				best = s
	return best

func _on_night_started(_night: int) -> void:
	_consecutive_attacks = 0
	_set_state(State.WANDER)

# ── External API ───────────────────────────────────────────────────────────────
func register_player(p: CharacterBody3D) -> void:
	player = p

func register_salt_line(node: Node3D) -> void:
	if node not in salt_lines:
		salt_lines.append(node)

func set_night(n: int) -> void:
	night_count = n
