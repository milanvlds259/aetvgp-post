extends Area2D

# Path to the next level scene you want to load
@export var next_scene_path: PackedScene

var _can_continue = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_process_input(false)

func _on_body_entered(body: Node) -> void:
	if body.name != "Player":
		return

	# find the "Enemies" container in the current scene
	var root = get_tree().get_current_scene()
	if not root.has_node("Enemies"):
		return
	var enemies = root.get_node("Enemies")
	if enemies.get_child_count() == 0:
		# no enemies left → show prompt
		var prompt = body.get_node("ContinuePrompt")
		prompt.visible = true
		_can_continue = true
		set_process_input(true)

func _input(event: InputEvent) -> void:
	if not _can_continue:
		return
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_E:
		get_tree().change_scene_to_packed(next_scene_path)
