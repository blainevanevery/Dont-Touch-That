## SearchableContainer.gd
## Extends Interactable: cupboards, drawers, footlockers.
## Supports open/close animations (rotation or slide), search timer, loot drops.

class_name SearchableContainer
extends Interactable

# ── Signals ────────────────────────────────────────────────────────────────────
signal search_started
signal search_finished(loot: Array)
signal opened
signal closed

# ── Config ─────────────────────────────────────────────────────────────────────
@export var search_time          : float  = 2.0   # seconds to complete a search
@export var open_rotation_offset : Vector3 = Vector3(0, 90, 0)
@export var slide_offset         : Vector3 = Vector3.ZERO
@export var loot_table           : Array  = []    # Array of item_id strings or ItemData

enum Mode { ROTATION, SLIDE }
@export var open_mode: Mode = Mode.ROTATION

# ── State ─────────────────────────────────────────────────────────────────────
var is_open      : bool = false
var is_searching : bool = false
var _loot_given  : bool = false
var _origin_rot  : Vector3
var _origin_pos  : Vector3

func _ready() -> void:
	super._ready()
	_origin_rot = rotation_degrees
	_origin_pos = position
	set_prompt("Search")

# ── Interaction entry ──────────────────────────────────────────────────────────
func interact(player: Node3D) -> void:
	if not interaction_enabled or is_searching:
		return
	if requires_key != "" and not InventoryManager.has_key(requires_key):
		prompt_updated.emit("Locked – need " + requires_key)
		return
	if is_open:
		_close()
	else:
		_start_search(player)

# ── Search ────────────────────────────────────────────────────────────────────
func _start_search(player: Node3D) -> void:
	is_searching = true
	set_prompt("Searching…")
	search_started.emit()
	await get_tree().create_timer(search_time).timeout
	is_searching = false
	_open()
	_give_loot()
	search_finished.emit(loot_table)
	interacted.emit(player)

func _give_loot() -> void:
	if _loot_given:
		return
	_loot_given = true
	for entry in loot_table:
		if entry is String:
			InventoryManager.add_item({"item_id": entry})
		else:
			InventoryManager.add_item(entry)

# ── Open / Close animations ───────────────────────────────────────────────────
func _open() -> void:
	is_open = true
	var tw = create_tween().set_parallel(true)
	match open_mode:
		Mode.ROTATION:
			tw.tween_property(self, "rotation_degrees",
							  _origin_rot + open_rotation_offset, 0.45)
		Mode.SLIDE:
			tw.tween_property(self, "position",
							  _origin_pos + slide_offset, 0.35)
	set_prompt("Close")
	opened.emit()

func _close() -> void:
	is_open = false
	var tw = create_tween().set_parallel(true)
	match open_mode:
		Mode.ROTATION:
			tw.tween_property(self, "rotation_degrees", _origin_rot, 0.35)
		Mode.SLIDE:
			tw.tween_property(self, "position", _origin_pos, 0.25)
	set_prompt("Search")
	closed.emit()

# ── Restock (for quest resets) ────────────────────────────────────────────────
func restock(new_loot: Array) -> void:
	loot_table  = new_loot
	_loot_given = false
