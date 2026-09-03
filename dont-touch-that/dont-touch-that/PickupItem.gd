class_name PickupItem
extends Interactable

@export var item_data: ItemData

func _ready():
	super._ready()
	if item_data:
		prompt_message = "Pick up " + item_data.display_name
		# If mesh exists, load it dynamically
		if item_data.mesh_path != "":
			var mesh_scene = load(item_data.mesh_path)
			if mesh_scene:
				var mesh_instance = mesh_scene.instantiate()
				add_child(mesh_instance)

func interact(player):
	if item_data:
		InventoryManager.add_item(item_data)
		queue_free()
