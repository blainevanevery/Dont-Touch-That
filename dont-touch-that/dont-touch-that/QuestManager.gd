## QuestManager.gd – Autoload singleton
## Tracks all 4 game-design parts and individual objectives.

extends Node

# ── Signals ───────────────────────────────────────────────────────────────────
signal part_changed(part: int, label: String)
signal objective_completed(obj_id: String)
signal jumpscare_triggered
signal game_over(reason: String)   # "exorcised" | "survived" | "died"

# ── Game Design Parts ─────────────────────────────────────────────────────────
enum Part {
	PROLOGUE  = 0,
	PART_1    = 1,   # Cleaning / Setup
	PART_2    = 2,   # Investigation
	PART_3    = 3,   # Preparation / Identify demon
	PART_4    = 4    # Exorcise or Survive
}

const PART_LABELS := {
	Part.PROLOGUE: "Prologue",
	Part.PART_1:   "Part 1 – Cleaning",
	Part.PART_2:   "Part 2 – Investigation",
	Part.PART_3:   "Part 3 – Preparation",
	Part.PART_4:   "Part 4 – Endgame"
}

var current_part: int = Part.PROLOGUE
var night_count:  int = 0
var demon_identified: bool = false
var demon_type:   int = -1   # 0-3 matching AiDemon0-3

# Tracks which objectives are done (key = obj_id string)
var completed: Dictionary = {}

# ── Objective registry ────────────────────────────────────────────────────────
# Each objective: { "id", "part", "label", "auto_advance" }
const OBJECTIVES := [
	# PROLOGUE
	{ "id": "meet_neighbors",  "part": Part.PROLOGUE, "label": "Answer the door and get the key",          "auto_advance": false },
	# PART 1
	{ "id": "clean_own_apt",   "part": Part.PART_1,   "label": "Vacuum, do dishes, take out garbage",      "auto_advance": false },
	{ "id": "clean_upstairs",  "part": Part.PART_1,   "label": "Clean upstairs apartment",                 "auto_advance": false },
	{ "id": "make_dinner",     "part": Part.PART_1,   "label": "Make dinner and get ready for bed",        "auto_advance": false },
	{ "id": "wake_307am",      "part": Part.PART_1,   "label": "3:07 AM – Hear doors slam",               "auto_advance": true  },
	{ "id": "chase_footsteps", "part": Part.PART_1,   "label": "Follow the footsteps upstairs",            "auto_advance": false },
	# PART 2
	{ "id": "fetch_key",       "part": Part.PART_2,   "label": "Retrieve key from nightstand",             "auto_advance": false },
	{ "id": "explore_upstairs","part": Part.PART_2,   "label": "Explore upstairs apartment",               "auto_advance": false },
	{ "id": "find_journals",   "part": Part.PART_2,   "label": "Find neighbor journals",                   "auto_advance": false },
	{ "id": "find_footlocker", "part": Part.PART_2,   "label": "Find and open the footlocker",             "auto_advance": false },
	{ "id": "jumpscare",       "part": Part.PART_2,   "label": "Dont Touch That! (jumpscare)",             "auto_advance": true  },
	# PART 3
	{ "id": "read_book",       "part": Part.PART_3,   "label": "Read Book of the Damned",                  "auto_advance": false },
	{ "id": "setup_protections","part":Part.PART_3,   "label": "Set up salt lines and wards",              "auto_advance": false },
	{ "id": "identify_demon",  "part": Part.PART_3,   "label": "Identify the demon (3–10 nights)",        "auto_advance": false },
	# PART 4
	{ "id": "gather_exorcism", "part": Part.PART_4,   "label": "Collect exorcism ingredients",             "auto_advance": false },
	{ "id": "perform_exorcism","part": Part.PART_4,   "label": "Perform the exorcism ritual",              "auto_advance": false },
]

# Quick lookup
var _obj_by_id: Dictionary = {}

func _ready() -> void:
	for o in OBJECTIVES:
		_obj_by_id[o["id"]] = o

func complete_objective(obj_id: String) -> void:
	if completed.has(obj_id):
		return
	if not _obj_by_id.has(obj_id):
		push_warning("QuestManager: unknown objective '%s'" % obj_id)
		return
	completed[obj_id] = true
	var obj = _obj_by_id[obj_id]
	objective_completed.emit(obj_id)

	# Trigger one-shot events
	match obj_id:
		"wake_307am":
			_trigger_307am_event()
		"jumpscare":
			jumpscare_triggered.emit()
		"identify_demon":
			demon_identified = true

	# Check auto-advance or part completion
	if obj.get("auto_advance", false):
		_try_advance_to(obj["part"] + 1)
	else:
		_check_part_complete(obj["part"])

func _check_part_complete(part: int) -> void:
	for o in OBJECTIVES:
		if o["part"] == part and not completed.has(o["id"]):
			return   # Still objectives remaining in this part
	_try_advance_to(part + 1)

func _try_advance_to(next: int) -> void:
	if next > current_part and next <= Part.PART_4:
		current_part = next
		part_changed.emit(current_part, PART_LABELS.get(current_part, ""))

func _trigger_307am_event() -> void:
	# Called at 3:07 AM on night 1 – DayNightCycle emits the signal
	pass   # Audio / light flicker handled by DayNightCycle

func on_night_passed() -> void:
	night_count += 1
	# Survival win: 14 nights without exorcism
	if night_count >= 14 and current_part == Part.PART_4 and not demon_identified:
		game_over.emit("survived")

func on_player_died() -> void:
	game_over.emit("died")

func on_exorcism_complete() -> void:
	game_over.emit("exorcised")

func get_active_objectives() -> Array:
	var active := []
	for o in OBJECTIVES:
		if o["part"] == current_part and not completed.has(o["id"]):
			active.append(o)
	return active
