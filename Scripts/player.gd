extends CharacterBody2D

@export var speed = 200
@export var max_hp = 100
@export var meter = 10
@export var recovery_time = 0.2  # Time for knockback recovery
@export var knockback_force = 50  # Force of knockback when hit
@export var invincibility_time = 0.2  # Time during which the player is invincible after being hit

var hp: int
var attacking: bool = false
var canAttack: bool = true
var being_hit = false  # Track if player is currently in hit recovery
var knockback_timer = 0.0  # Timer for knockback recovery
var invincible = false  # Track if player is invincible after being hit


signal light_atk
signal med_atk
signal heavy_atk
signal special_atk
signal dash_atk

# Combo system variables
@export var combo_timeout = 2.0  # Time window to land the next hit in seconds
@export var special_meter_restore: int = 4
@export var dash_meter_restore: int = 5
var current_combo = []  # Track the sequence of successful attacks
var combo_timer = 0.0   # Timer to track time since last successful hit
var combo_active = false  # Is a combo currently in progress?
var last_hit_time = 0.0
var meter_increase = 1.0
# Define available combos (can be expanded later)
var available_combos = {
	"special_attack": ["light_attack", "medium_attack", "heavy_attack"],
	"dash_attack": ["light_attack", "medium_attack", "light_attack", "medium_attack"],
}
@onready var progress_meter = $CanvasLayer/Meter


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
	invincible = false

	$PlayerHitbox.area_entered.connect(_on_player_hitbox_area_entered)
	$PlayerHitbox.body_entered.connect(_on_player_hitbox_body_entered)

# Handle attacks from enemy areas
func _on_player_hitbox_area_entered(area):
	# Only process if the area is an attack hitbox from enemies
	if area.get_parent().is_in_group("enemy") and "AttackHitbox" in area.name:
		var enemy = area.get_parent()
		if "enemy_attack_damage" in enemy:
			take_damage(enemy.enemy_attack_damage, enemy.global_position)
	
	# Handle enemy projectiles
	elif "enemy_projectile" in area.get_groups():
		if "damage" in area:
			take_damage(area.damage, area.global_position)
			# Remove the projectile after hit
			area.queue_free()

# Handle attacks from enemy bodies
func _on_player_hitbox_body_entered(body):
	if body.is_in_group("enemy"):
		if "enemy_attack_damage" in body:
			take_damage(body.enemy_attack_damage, body.global_position)
	
	elif "enemy_projectile" in body.get_groups():
		if "damage" in body:
			take_damage(body.damage, body.global_position)
			# Remove the projectile after hit
			body.queue_free()

func _physics_process(delta):
	# Handle knockback recovery
	if being_hit:
		knockback_timer -= delta
		if knockback_timer <= 0:
			being_hit = false
			$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0)  # Reset color
		move_and_slide()  # Allow knockback to move player
		return  # Skip regular movement while being hit

	# Update combo timer if a combo is in progress
	if combo_active:
		combo_timer -= delta
		if combo_timer <= 0:
			# Combo timed out
			reset_combo()
			print("Combo timed out!")

	# Handle attacks
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
		
func take_damage(damage: int, attacker_position = null):
	if invincible:
		return  # Ignore damage if invincible

	hp -= damage
	$CanvasLayer/HPBar.value = hp
	
	# Apply hit feedback
	$AnimatedSprite2D.modulate = Color(1.0, 0.3, 0.3)  # Red tint
	
	# Apply knockback if attacker position is provided
	if attacker_position:
		# Calculate knockback direction (away from attacker)
		var knockback_direction = (global_position - attacker_position).normalized()
		velocity = knockback_direction * knockback_force
		
		# Start recovery timer
		being_hit = true
		knockback_timer = recovery_time

		start_invincibility()
		
		# Create a timer to reset color if knockback lasts too long
		get_tree().create_timer(0.2).timeout.connect(reset_color)
	
	if hp <= 0:
		die()

func start_invincibility():
	invincible = true
	
	#visual feedback
	var blink_tween = create_tween()
	blink_tween.tween_property($AnimatedSprite2D, "modulate:a", 0.5, 0.05)
	blink_tween.tween_property($AnimatedSprite2D, "modulate:a", 1.0, 0.05)
	blink_tween.set_loops(5)

	await get_tree().create_timer(invincibility_time).timeout
	invincible = false  # Reset invincibility after the duration
	# Reset color to normal
	$AnimatedSprite2D.modulate.a = 1.0 # Reset to white
	

# Reset color after a brief flash
func reset_color():
	if hp > 0 and !invincible:  # Only reset if still alive
		$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0)

func heal(heal_amount: int):
	hp += heal_amount
	if hp > max_hp:
		hp = max_hp
	$CanvasLayer/HPBar.value = hp

func die():
	# reset current scene
	get_tree().change_scene_to_file("res://death_sc.tscn")



func _on_animation_finished():
	if $AnimatedSprite2D.animation in ["light_attack", "medium_attack", "heavy_attack", "special_attack", "dash_attack"]:
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
		$AttackHitbox/CollisionShape2D.disabled = !(frame == 1 or frame == 2)
		#Shouldn't change variable UNLESS frame >= 4
		if frame >= 3:
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
		#Shouldn't change variable UNLESS frame >= 9
		if frame >= 9:
			canAttack = true
		else:
			canAttack = false

	if $AnimatedSprite2D.animation == "dash_attack":
		var frame = $AnimatedSprite2D.frame
		$AttackHitbox.scale = Vector2(1.5, 1.3)
		if $AnimatedSprite2D.flip_h:
			$AttackHitbox.scale.x = -1
		$AttackHitbox/CollisionShape2D.disabled = !(frame in [2, 5])
		#Shouldn't change variable UNLESS frame >= 9
		if frame >= 8:
			canAttack = true
		else:
			canAttack = false


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
	elif $AnimatedSprite2D.animation == "dash_attack":
		await get_tree().create_timer(0.3).timeout
		dash_atk.emit()


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
	var detected_combos = []
	var longest_combo_length = 0
	var longest_combo_name = ""
	
	# First pass: find all valid combos in the current sequence
	for combo_name in available_combos:
		var combo_sequence = available_combos[combo_name]
		
		# Check if the current combo contains this combo sequence
		if is_subsequence(current_combo, combo_sequence):
			detected_combos.append(combo_name)
			
			# Track the longest combo
			if combo_sequence.size() > longest_combo_length:
				longest_combo_length = combo_sequence.size()
				longest_combo_name = combo_name
	
	# If we found any valid combos, execute the longest one
	if detected_combos.size() > 0:
		print("Detected combos: ", detected_combos)
		print("Executing longest combo: ", longest_combo_name)
		execute_combo(longest_combo_name)
		return

# Helper function to check if one array contains another as a subsequence
func is_subsequence(main_sequence, sub_sequence):
	var main_size = main_sequence.size()
	var sub_size = sub_sequence.size()
	
	# If the subsequence is longer than the main sequence, it can't be contained
	if sub_size > main_size:
		return false
	
	# Check for the subsequence at each possible starting position
	for start_pos in range(main_size - sub_size + 1):
		var match_found = true
		
		# Check if this position starts a match
		for i in range(sub_size):
			if main_sequence[start_pos + i] != sub_sequence[i]:
				match_found = false
				break
		
		# If we found a complete match starting at this position
		if match_found:
			return true
	
	# No match found
	return false

func reset_combo():
	current_combo.clear()
	combo_active = false
	combo_timer = 0.0

func execute_combo(combo_name):
	print("Executing combo: ", combo_name)
	

	if combo_name == "special_attack":

		print("SPECIAL ATTACK UNLEASHED!")
		
		# Add visual effects, sounds, or whatever you want for the special attack
		$AnimatedSprite2D.play("special_attack")
		canAttack = false

		# Reset combo after execution
		reset_combo()

	elif combo_name == "dash_attack":

		print("DASH ATTACK UNLEASHED!")
		
		# Add visual effects, sounds, or whatever you want for the dash attack
		$AnimatedSprite2D.play("dash_attack")
		canAttack = false

		# Reset combo after execution
		reset_combo()

func register_hit(attack_type):
	var current_time = Time.get_ticks_msec()
	if current_time - last_hit_time < 100:  # 100ms buffer
		return
	last_hit_time = current_time
	# Called from enemy.gd when a hit is successfully landed
	on_successful_hit(attack_type)
	if attack_type in ["special_attack", "dash_attack"]:
		# Restore special meter for successful hits
		restore_meter(special_meter_restore)

func restore_meter(amount: int):
	meter += amount
	if meter > progress_meter.max_value:
		meter = progress_meter.max_value
	progress_meter.value = meter
	print("Meter restored by: ", amount)
