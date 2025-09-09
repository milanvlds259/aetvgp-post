extends Node2D

@export var next_scene_path : String = "res://title_sc.tscn"

func _ready():
	# Connect the button's pressed signal to the start_game function
	#$CanvasLayer/RestartButton.pressed.connect(restart_game)
	# will keep it in case i want to use it later
	
	# Optional: Add a subtle animation to the title
	var title_tween = create_tween()
	title_tween.tween_property($CanvasLayer/YouDiedSprite, "scale", $CanvasLayer/YouDiedSprite.scale * 1.05, 1.0)
	title_tween.tween_property($CanvasLayer/YouDiedSprite, "scale", $CanvasLayer/YouDiedSprite.scale, 1.0)
	title_tween.set_loops()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_SPACE:
			restart_game()

func restart_game():
	# Optional: Add a transition effect
	var transition_rect = ColorRect.new()
	transition_rect.color = Color(0, 0, 0, 0)
	transition_rect.size = get_viewport_rect().size
	$CanvasLayer.add_child(transition_rect)
	
	var tween = create_tween()
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 1), 0.5)
	tween.tween_callback(change_scene)

func change_scene():
	# Load the main scene
	get_tree().change_scene_to_file(next_scene_path)
