## PlayerInteractionRay.gd
## Attach to the player's Camera3D as a child.
## Fires a RayCast3D forward, detects Interactable nodes, emits prompt UI signals.

class_name PlayerInteractionRay
extends RayCast3D

# ── Signals ────────────────────────────────────────────────────────────────────
signal prompt_show(text: String)
signal prompt_hide

# ── Config ─────────────────────────────────────────────────────────────────────
@export var reach : float = 3.0

var _current : Interactable = null

func _ready() -> void:
	target_position      = Vector3(0, 0, -reach)
	collision_mask       = 4   # Layer 3
	collide_with_areas   = true
	collide_with_bodies  = false
	enabled              = true

func _physics_process(_delta: float) -> void:
	force_raycast_update()
	if is_colliding():
		var col = get_collider()
		if col is Interactable:
			if col != _current:
				_detach_current()
				_current = col
				_current.prompt_updated.connect(_on_prompt_updated)
				prompt_show.emit(_current.prompt_message)
			return
	_detach_current()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current:
		_current.interact(owner)

func _detach_current() -> void:
	if _current:
		if _current.prompt_updated.is_connected(_on_prompt_updated):
			_current.prompt_updated.disconnect(_on_prompt_updated)
		_current = null
		prompt_hide.emit()

func _on_prompt_updated(text: String) -> void:
	if text.is_empty():
		prompt_hide.emit()
	else:
		prompt_show.emit(text)
