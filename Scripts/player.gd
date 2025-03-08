extends CharacterBody2D

var speed = 200

func _ready():
	# play idle animation
	$AnimatedSprite2D.play("idle")

func _physics_process(delta):
	var input_vector = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
    )
    
	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
    
	velocity = input_vector * speed
	move_and_slide()