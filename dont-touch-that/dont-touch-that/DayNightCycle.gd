## DayNightCycle.gd – Autoload singleton
## Manages a 2-week (14 night) survival timeline, sun/moon rotation,
## midnight event triggers, and environment lighting.

extends Node

# ── Signals ────────────────────────────────────────────────────────────────────
signal day_started(day: int)
signal night_started(night: int)
signal midnight_event                    # 3:07 AM – triggers first night event
signal dawn                              # Each sunrise

# ── Config ─────────────────────────────────────────────────────────────────────
## Real-time seconds for one full in-game day (day + night combined)
@export var full_day_duration : float = 600.0  # 10 min = 1 game day
@export var night_fraction    : float = 0.5    # 50% of day = night

var day_duration  : float
var night_duration: float

# ── State ──────────────────────────────────────────────────────────────────────
var current_day   : int   = 1
var time_of_day   : float = 0.25  # 0.0-1.0; 0.0=midnight, 0.25=sunrise, 0.75=sunset
var is_night      : bool  = false
var midnight_fired: bool  = false  # Per-night flag for 3:07 AM

# Node refs (set by level_builder / scene)
var sun   : DirectionalLight3D = null
var moon  : DirectionalLight3D = null
var env   : WorldEnvironment   = null

func _ready() -> void:
	_recalculate_durations()

func _recalculate_durations() -> void:
	day_duration   = full_day_duration * (1.0 - night_fraction)
	night_duration = full_day_duration * night_fraction

# ── Main tick ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# Drain flashlight if on
	if InventoryManager.flashlight_on:
		InventoryManager.drain_flashlight(delta, night_duration)

	# Advance time
	time_of_day = fmod(time_of_day + delta / full_day_duration, 1.0)

	var was_night = is_night
	is_night = time_of_day >= night_fraction * 0.5 and time_of_day < (1.0 - night_fraction * 0.5)

	# Day/night transitions
	if was_night and not is_night:
		_on_dawn()
	elif not was_night and is_night:
		_on_dusk()

	# 3:07 AM event on Night 1 only (Part 1): fires at ~30% through night
	if is_night and not midnight_fired and time_of_day > night_fraction * 0.5 + night_fraction * 0.3:
		midnight_fired = true
		midnight_event.emit()
		if current_day == 1:
			QuestManager.complete_objective("wake_307am")

	_update_lighting()

func _on_dawn() -> void:
	midnight_fired = false
	current_day += 1
	QuestManager.on_night_passed()
	day_started.emit(current_day)
	dawn.emit()

func _on_dusk() -> void:
	night_started.emit(current_day)

# ── Lighting ───────────────────────────────────────────────────────────────────
func _update_lighting() -> void:
	# Convert time_of_day to sun angle: 0.25=sunrise(east), 0.75=sunset(west)
	var sun_angle = (time_of_day - 0.25) * 360.0   # degrees
	var elevation = sin(deg_to_rad(sun_angle)) * 90.0

	if sun:
		sun.rotation_degrees = Vector3(-elevation, 30.0, 0.0)
		var t = clampf((elevation + 10.0) / 30.0, 0.0, 1.0)
		sun.light_energy     = lerp(0.0, 1.2, t)
		sun.light_color      = lerp(Color(1.0, 0.4, 0.1), Color(1.0, 0.97, 0.9), t)

	if moon:
		moon.rotation_degrees = Vector3(elevation - 90.0, 30.0, 0.0)
		var night_t = clampf(-elevation / 90.0, 0.0, 1.0)
		moon.light_energy     = lerp(0.0, 0.12, night_t)
		moon.light_color      = Color(0.3, 0.4, 0.6)

	if env and env.environment:
		# Blend sky brightness
		var sky_energy = clampf((elevation + 5.0) / 25.0, 0.05, 1.0)
		env.environment.ambient_light_energy = lerp(0.08, 0.45, sky_energy)

# ── Public helpers ─────────────────────────────────────────────────────────────

func register_sun(node: DirectionalLight3D) -> void:
	sun = node

func register_moon(node: DirectionalLight3D) -> void:
	moon = node

func register_environment(node: WorldEnvironment) -> void:
	env = node

func get_game_time_string() -> String:
	# Maps time_of_day to a 12-hour clock string for UI
	var hours   = fmod(time_of_day * 24.0 + 6.0, 24.0)
	var minutes = int(fmod(hours, 1.0) * 60.0)
	var h       = int(hours) % 12
	if h == 0: h = 12
	var ampm    = "AM" if int(hours) < 12 else "PM"
	return "%d:%02d %s" % [h, minutes, ampm]

func get_days_survived() -> int:
	return current_day - 1
