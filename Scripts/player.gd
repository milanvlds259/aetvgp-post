extends CharacterBody2D

@export var speed = 200
var attacking: bool = false

func _ready():
	# play idle animation
	$AnimatedSprite2D.play("idle")
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	$AnimatedSprite2D.frame_changed.connect(_on_frame_changed)
	$AttackHitbox/CollisionShape2D.disabled = true

func _physics_process(delta):

	#Handle attacks
	if Input.is_action_just_pressed("light_attack"):
		attacking = true
		$AnimatedSprite2D.play("light_attack")
		return

	if Input.is_action_just_pressed("medium_attack"):
		attacking = true
		$AnimatedSprite2D.play("medium_attack")
		return

	if not attacking:
		var input_vector = Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		)
		
		if input_vector != Vector2.ZERO:
			input_vector = input_vector.normalized()
			if $AnimatedSprite2D.animation != "walk":
				$AnimatedSprite2D.play("walk")

			if input_vector.x < 0:
				$AnimatedSprite2D.flip_h = true
				$AttackHitbox.scale.x = -1
			elif input_vector.x > 0:
				$AnimatedSprite2D.flip_h = false
				$AttackHitbox.scale.x = 1				
		else:
			if $AnimatedSprite2D.animation != "idle":
				$AnimatedSprite2D.play("idle")
		
		velocity = input_vector * speed
		move_and_slide()

func _on_animation_finished():
	if $AnimatedSprite2D.animation == "light_attack" or $AnimatedSprite2D.animation == "medium_attack":
		attacking = false
		$AnimatedSprite2D.play("idle")
		$AttackHitbox/CollisionShape2D.disabled = true

func _on_frame_changed():
	if $AnimatedSprite2D.animation == "light_attack":
		var frame = $AnimatedSprite2D.frame
		$AttackHitbox/CollisionShape2D.disabled = !(frame == 2 or frame == 3)

	if $AnimatedSprite2D.animation == "medium_attack":
		var frame = $AnimatedSprite2D.frame
		$AttackHitbox/CollisionShape2D.disabled = !(frame == 1 or frame == 3)