## Interactable.gd
## Base class for all interactive 3D world objects.
## Attach this script (or a subclass) to an Area3D node.
## PlayerInteractionRay detects it on collision layer 3 (bitmask 4).

class_name Interactable
extends Area3D

# ── Signals ────────────────────────────────────────────────────────────────────
signal interacted(player: Node3D)
signal prompt_updated(text: String)

# ── Config ─────────────────────────────────────────────────────────────────────
@export var prompt_message    : String = "Interact [E]"
@export var requires_key      : String = ""          # e.g. "key1" — empty = no lock
@export var interaction_enabled: bool  = true

func _ready() -> void:
	collision_layer = 4   # Layer 3 in Godot's 1-indexed display
	collision_mask  = 0
	monitoring      = true
	monitorable     = true

## Override in subclasses. Call super.interact(player) for base behaviour.
func interact(player: Node3D) -> void:
	if not interaction_enabled:
		return
	if requires_key != "" and not InventoryManager.has_key(requires_key):
		prompt_updated.emit("Locked – need " + requires_key)
		return
	interacted.emit(player)

func set_prompt(text: String) -> void:
	prompt_message = text
	prompt_updated.emit(text)

func enable() -> void:
	interaction_enabled = true
	prompt_updated.emit(prompt_message)

func disable() -> void:
	interaction_enabled = false
	prompt_updated.emit("")
