## InventoryManager.gd – Autoload singleton
## Manages all items: keys, batteries (14 with 85% nightly drain), salt, herbs.

extends Node

signal inventory_changed
signal battery_depleted
signal flashlight_dead

# ── Item catalogue ─────────────────────────────────────────────────────────────
# Keys
var key_ring: Array[String] = []   # holds "key0".."key3"

# Flashlight batteries
const BATTERY_MAX       := 14
const BATTERY_DRAIN_PCT := 0.85   # 85 % of one night
var batteries_remaining : int   = BATTERY_MAX
var battery_charge      : float = 1.0  # 0.0–1.0 (current battery level)
var flashlight_on       : bool  = false

# General item slots (ItemData resources)
var items: Array = []   # Array[ItemData]

# Salt
var salt_charges        : int = 0

# Herbs (one per demon type, 4 total)
var herbs: Dictionary = {
	"sage":     0,
	"rosemary": 0,
	"juniper":  0,
	"lavender": 0,
}

# Other quest items
var has_camera          : bool = false
var has_crucifix        : bool = false
var has_castiron_bar    : bool = false
var has_spray_bottle    : bool = false
var has_blessed_water   : bool = false
var book_of_damned      : bool = false

# ── Public API ────────────────────────────────────────────────────────────────

func add_item(item) -> void:
	if not item:
		return
	var id: String = item.get("item_id") if item is Dictionary else item.item_id
	match id:
		"key0","key1","key2","key3":
			if id not in key_ring:
				key_ring.append(id)
		"battery":
			batteries_remaining = min(batteries_remaining + 1, BATTERY_MAX)
			if battery_charge == 0.0:
				_load_next_battery()
		"salt":
			salt_charges += 1
		"herb_sage":      herbs["sage"]     += 1
		"herb_rosemary":  herbs["rosemary"] += 1
		"herb_juniper":   herbs["juniper"]  += 1
		"herb_lavender":  herbs["lavender"] += 1
		"camera":         has_camera        = true
		"crucifix":       has_crucifix      = true
		"castiron_bar":   has_castiron_bar  = true
		"spray_bottle":   has_spray_bottle  = true
		"blessed_water":  has_blessed_water = true
		"book_of_damned": book_of_damned    = true
		_:
			if item not in items:
				items.append(item)
	inventory_changed.emit()

func has_key(key_id: String) -> bool:
	return key_id in key_ring

func use_salt() -> bool:
	if salt_charges > 0:
		salt_charges -= 1
		inventory_changed.emit()
		return true
	return false

func use_herb(herb_name: String) -> bool:
	if herbs.get(herb_name, 0) > 0:
		herbs[herb_name] -= 1
		inventory_changed.emit()
		return true
	return false

# ── Flashlight ────────────────────────────────────────────────────────────────

func toggle_flashlight() -> void:
	if battery_charge <= 0.0 and batteries_remaining == 0:
		return  # No power at all
	flashlight_on = !flashlight_on

## Call every _process frame when flashlight is on.
## night_duration: total length of one night in seconds (from DayNightCycle).
func drain_flashlight(delta: float, night_duration: float) -> void:
	if not flashlight_on or battery_charge <= 0.0:
		return
	var drain_per_sec = BATTERY_DRAIN_PCT / max(night_duration, 1.0)
	battery_charge -= drain_per_sec * delta
	if battery_charge <= 0.0:
		battery_charge = 0.0
		battery_depleted.emit()
		if batteries_remaining > 0:
			batteries_remaining -= 1
			if batteries_remaining > 0:
				_load_next_battery()
			else:
				flashlight_on = false
				flashlight_dead.emit()
		else:
			flashlight_on = false
			flashlight_dead.emit()
	inventory_changed.emit()

func _load_next_battery() -> void:
	battery_charge = 1.0

# ── Save / Load helpers ───────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	return {
		"key_ring":            key_ring,
		"batteries_remaining": batteries_remaining,
		"battery_charge":      battery_charge,
		"salt_charges":        salt_charges,
		"herbs":               herbs,
		"has_camera":          has_camera,
		"has_crucifix":        has_crucifix,
		"has_castiron_bar":    has_castiron_bar,
		"has_spray_bottle":    has_spray_bottle,
		"has_blessed_water":   has_blessed_water,
		"book_of_damned":      book_of_damned,
	}

func load_save_data(d: Dictionary) -> void:
	key_ring            = d.get("key_ring",            [])
	batteries_remaining = d.get("batteries_remaining", BATTERY_MAX)
	battery_charge      = d.get("battery_charge",      1.0)
	salt_charges        = d.get("salt_charges",        0)
	herbs               = d.get("herbs",               herbs)
	has_camera          = d.get("has_camera",          false)
	has_crucifix        = d.get("has_crucifix",        false)
	has_castiron_bar    = d.get("has_castiron_bar",    false)
	has_spray_bottle    = d.get("has_spray_bottle",    false)
	has_blessed_water   = d.get("has_blessed_water",   false)
	book_of_damned      = d.get("book_of_damned",      false)
	inventory_changed.emit()
