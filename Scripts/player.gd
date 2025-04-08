extends CharacterBody2D

@export var speed = 200
@export var max_hp = 100
@export var meter = 10

var hp: int
var attacking: bool = false
var canAttack: bool = true
@onready var progress_meter = $"../CanvasLayer/Meter"


signal light_atk
signal med_atk
signal heavy_atk
signal special_atk

# Combo system variables
@export var combo_timeout = 2.0  # Time window to land the next hit in seconds
var current_combo = []  # Track the sequence of successful attacks
var combo_timer = 0.0   # Timer to track time since last successful hit
var combo_active = false  # Is a combo currently in progress?
var last_hit_time = 0.0
var meter_increase = 1.0
# Define available combos (can be expanded later)
var available_combos = {
	"special_attack": ["light_attack", "medium_attack", "heavy_attack"]
}


func _ready():
	# play idle animation
	$AnimatedSprite2D.play("idle")
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	$AnimatedSprite2D.frame_changed.connect(_on_frame_changed)
	$AttackHitbox/CollisionShape2D.disabled = true
	hp = max_hp
	progress_meter.max_value = meter
	progress_meter.value = meter

	$CanvasLayer/HPBar.max_value = max_hp
	$CanvasLayer/HPBar.value = hp

func _physics_process(delta):
	# Update combo timer if a combo is in progress
	if combo_active:
		combo_timer -= delta
		if combo_timer <= 0:
			# Combo timed out
			reset_combo()
			print("Combo timed out!")

	#Handle attacks
	if Input.is_action_just_pressed("light_attack") && canAttack && meter >= 1:
		attacking = true
		canAttack = false
		meter -= 1
		progress_meter.value = meter
		$AnimatedSprite2D.play("light_attack")
		return

	if Input.is_action_just_pressed("medium_attack") && canAttack && meter >= 2:
		attacking = true
		canAttack = false
		meter -= 2
		progress_meter.value = meter
		$AnimatedSprite2D.play("medium_attack")
		return

	if Input.is_action_just_pressed("heavy_attack") && canAttack && meter >= 3:
		attacking = true
		canAttack = false
		meter -= 3
		progress_meter.value = meter
		$AnimatedSprite2D.play("heavy_attack")
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
		meter_increase -= delta * 1.5
		if meter_increase <= 0:
			if meter < progress_meter.max_value:
				meter += 1
			progress_meter.value = meter
			meter_increase = 1.0
		velocity = input_vector * speed
		move_and_slide()
		
func take_damage(damage: int):
	hp -= damage
	$CanvasLayer/HPBar.value = hp
	if hp <= 0:
		die()

func heal(heal_amount: int):
	hp += heal_amount
	if hp > max_hp:
		hp = max_hp
	$CanvasLayer/HPBar.value = hp

func die():
	# reset current scene
	get_tree().reload_current_scene()



func _on_animation_finished():
	if $AnimatedSprite2D.animation in ["light_attack", "medium_attack", "heavy_attack", "special_attack"]:
		attacking = false
		canAttack = true
		$AnimatedSprite2D.play("idle")
		$AttackHitbox/CollisionShape2D.disabled = true

func _on_frame_changed():
	if $AnimatedSprite2D.animation == "light_attack":
		var frame = $AnimatedSprite2D.frame
		$AttackHitbox.scale = Vector2(1, 1)
		if $AnimatedSprite2D.flip_h:
			$AttackHitbox.scale.x = -1
		$AttackHitbox/CollisionShape2D.disabled = !(frame == 2 or frame == 3)
		#Shouldn't change variable UNLESS frame >= 4
		if frame >= 4:
			canAttack = true 

	if $AnimatedSprite2D.animation == "medium_attack":
		var frame = $AnimatedSprite2D.frame
		$AttackHitbox.scale = Vector2(1.1, 1.3)
		if $AnimatedSprite2D.flip_h:
			$AttackHitbox.scale.x = -1
		$AttackHitbox/CollisionShape2D.disabled = !(frame == 2 or frame == 3)
		#Shouldn't change variable UNLESS frame >= 4
		if frame >= 5:
			canAttack = true

	if $AnimatedSprite2D.animation == "heavy_attack":
		var frame = $AnimatedSprite2D.frame
		$AttackHitbox.scale = Vector2(1.4, 1.4)
		if $AnimatedSprite2D.flip_h:
			$AttackHitbox.scale.x = -1
		$AttackHitbox/CollisionShape2D.disabled = !(frame == 4 or frame == 5)
		#Shouldn't change variable UNLESS frame >= 6
		if frame >= 6:
			canAttack = true

	if $AnimatedSprite2D.animation == "special_attack":
		var frame = $AnimatedSprite2D.frame
		$AttackHitbox.scale = Vector2(1.4, 1.4)
		if $AnimatedSprite2D.flip_h:
			$AttackHitbox.scale.x = -1
		$AttackHitbox/CollisionShape2D.disabled = !(frame in [5, 6, 7])
		#Shouldn't change variable UNLESS frame >= 6
		if frame >= 9:
			canAttack = true

func _on_animated_sprite_2d_animation_changed() -> void:
	if $AnimatedSprite2D.animation == "light_attack":
		await get_tree().create_timer(0.1).timeout
		light_atk.emit()
	elif $AnimatedSprite2D.animation == "medium_attack":
		await get_tree().create_timer(0.15).timeout
		med_atk.emit()
	elif $AnimatedSprite2D.animation == "heavy_attack":
		await get_tree().create_timer(0.1).timeout
		heavy_atk.emit()
	elif $AnimatedSprite2D.animation == "special_attack":
		await get_tree().create_timer(0.5).timeout
		special_atk.emit()


func on_successful_hit(attack_type):
	# Record the successful hit in our combo sequence
	if attack_type not in available_combos:
		current_combo.append(attack_type)
		combo_active = true
		combo_timer = combo_timeout  # Reset the combo timer
	
	# Check if we've completed a valid combo
	check_for_combo()
	
	# Debug print current combo
	print("Current combo: ", current_combo)

func check_for_combo():
	for combo_name in available_combos:
		var combo_sequence = available_combos[combo_name]
		
		# Check if current combo matches the beginning of this combo sequence
		var is_match = true
		if current_combo.size() <= combo_sequence.size():
			for i in range(current_combo.size()):
				if current_combo[i] != combo_sequence[i]:
					is_match = false
					break
		else:
			is_match = false
		
		# If we've completed the full combo
		if is_match and current_combo.size() == combo_sequence.size():
			execute_combo(combo_name)
			return

func reset_combo():
	current_combo.clear()
	combo_active = false
	combo_timer = 0.0

func execute_combo(combo_name):
	print("Executing combo: ", combo_name)
	
	# Example: special_attack combo execution
	if combo_name == "special_attack":
		# You would play a special animation here
		# For now, we'll just print success and reset
		print("SPECIAL ATTACK UNLEASHED!")
		
		# Add visual effects, sounds, or whatever you want for the special attack
		$AnimatedSprite2D.play("special_attack")

		# Reset combo after execution
		reset_combo()

func register_hit(attack_type):
	var current_time = Time.get_ticks_msec()
	if current_time - last_hit_time < 100:  # 100ms buffer
		return
	last_hit_time = current_time
	# Called from enemy.gd when a hit is successfully landed
	on_successful_hit(attack_type)
