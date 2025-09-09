extends RigidBody2D

@export var max_health = 100
@export var light_attack_damage = 20
@export var medium_attack_damage = 35
@export var heavy_attack_damage = 50
@export var special_attack_damage = 100
@export var light_attack_knockback = 400.0
@export var medium_attack_knockback = 800.0
@export var heavy_attack_knockback = 1200.0
@export var special_attack_knockback = 300.0
@export var dash_attack_damage = 80
@export var dash_attack_knockback = 50.0
@export var recovery_time = 0.5
@export var stun_time = 2.0

@export var movement_speed = 50
@export var enemy_attack_damage = 25

enum State {IDLE, CHASE, ATTACK, RETREATING, IN_SHELL, STUNNED}
var current_state = State.IDLE

var current_health = 0
var being_hit = false
var knockback_timer = 0.0
var dying = false
var player = null
var can_attack = true
var has_shell = true
var is_shell_breaking = false
var combo_count = 0
var stun_timer = 0.0

signal hurt
signal death
signal hit

var current_attack_hit = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_health = max_health
	# Connect the hitbox detection
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)

	$PlayerDetection.area_entered.connect(_on_player_detected)
	$PlayerDetection.area_exited.connect(_on_player_exited)

	$AttackRange.area_entered.connect(_on_attack_range_area_entered)
	$AttackRange.area_exited.connect(_on_attack_range_area_exited)

	$AttackCooldown.timeout.connect(_on_attack_cooldown_timeout)

	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	$AnimatedSprite2D.frame_changed.connect(_on_frame_changed)

	$AnimatedSprite2D.play("idle_shell")
	$AttackHitbox/CollisionShape2D.disabled = true

	$AttackHitbox.area_entered.connect(_on_attack_hitbox_area_entered)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Handle stun state
	if current_state == State.STUNNED:
		stun_timer -= delta
		if stun_timer <= 0:
			current_state = State.IDLE
			if player != null:
				current_state = State.CHASE

	# Handle recovery from knockback
	if being_hit:
		knockback_timer -= delta
		if knockback_timer <= 0:
			being_hit = false
			# Reset to normal physics mode after recovery
			linear_damp = 3.0
			if player != null:
				current_state = State.CHASE
			else:
				current_state = State.IDLE
				$AnimatedSprite2D.play(get_idle_anim())
	elif !dying:
		match current_state:
			State.IDLE:
				if $AnimatedSprite2D.animation != get_idle_anim():
					$AnimatedSprite2D.play(get_idle_anim())
				linear_velocity = Vector2.ZERO
			State.CHASE:
				# Chase the player
				if player != null:
					var direction = (player.global_position - global_position).normalized()

					if direction.x > 0:
						$AnimatedSprite2D.flip_h = true
						$AttackHitbox.scale.x = -1
						$AttackRange.scale.x = -1
					else:
						$AnimatedSprite2D.flip_h = false
						$AttackHitbox.scale.x = 1
						$AttackRange.scale.x = 1

					linear_velocity = direction * movement_speed
					$AnimatedSprite2D.play(get_walk_anim())

			State.ATTACK:
				linear_velocity = Vector2.ZERO

			State.RETREATING:
				linear_velocity = Vector2.ZERO

			State.IN_SHELL:
				linear_velocity = Vector2.ZERO

			State.STUNNED:
				linear_velocity = Vector2.ZERO
				$AnimatedSprite2D.play("stun_loop")

func get_idle_anim() -> String:
	return "idle_shell" if has_shell else "idle_noshell"

func get_attack_anim() -> String:
	return "attack_shell" if has_shell else "attack_noshell"

func get_walk_anim() -> String:
	return "walk_shell" if has_shell else "walk_noshell"

func _on_player_detected(area):
	if area.name == "PlayerHitbox" and !dying and !being_hit:
		player = area.get_parent()
		current_state = State.CHASE

func _on_player_exited(body):
	if body.name == "PlayerHitbox" and !dying:
		player = null
		current_state = State.IDLE

func _on_attack_range_area_entered(area):
	if area.name == "PlayerHitbox" and !dying and !being_hit and current_state not in [State.RETREATING, State.IN_SHELL, State.STUNNED]:
		# Only change to attack state if we can attack and aren't already attacking
		if can_attack and current_state != State.ATTACK:
			current_state = State.ATTACK
			attack_player()

func _on_attack_range_area_exited(area):
	if area.name == "PlayerHitbox" and !dying and !being_hit:
		# If we're in attack state, remain there until animation finishes
		# The animation finished signal will handle the state transition back to CHASE
		pass

func _on_attack_cooldown_timeout():
	can_attack = true

func _on_animation_finished():
	var current_anim = $AnimatedSprite2D.animation
	
	if current_anim == get_attack_anim() and !dying and !being_hit:
		$AttackHitbox/CollisionShape2D.disabled = true

		if player != null and current_state != State.RETREATING and current_state != State.IN_SHELL and current_state != State.STUNNED:
			current_state = State.CHASE
			$AnimatedSprite2D.play(get_walk_anim())
		else:
			current_state = State.IDLE
			$AnimatedSprite2D.play(get_idle_anim())
	
	elif current_anim == "retreat_toshell":
		current_state = State.IN_SHELL
		# Keep showing the last frame of retreat animation
		$AnimatedSprite2D.pause()
		combo_count = 0 # Reset combo counter
	
	elif current_anim == "shell_break":
		has_shell = false
		current_state = State.STUNNED
		stun_timer = stun_time
		$AnimatedSprite2D.play("stun_loop")

func _on_frame_changed():
	if $AnimatedSprite2D.animation == get_attack_anim():
		var frame = $AnimatedSprite2D.frame
		
		# Handle flipping the hitbox based on direction
		$AttackHitbox.scale = Vector2(1, 1)
		if $AnimatedSprite2D.flip_h:
			$AttackHitbox.scale.x = -1
			
		# Enable/disable hitbox during specific attack frames
		if frame >= 5 and frame <= 7:
			$AttackHitbox/CollisionShape2D.disabled = false
			
			# Check if player is already in hitbox when it activates AND this attack hasn't hit yet
			if player != null and $AttackHitbox.overlaps_body(player) and player.has_method("take_damage") and !current_attack_hit:
				player.take_damage(enemy_attack_damage, global_position)
				current_attack_hit = true
		else:
			$AttackHitbox/CollisionShape2D.disabled = true

func attack_player():
	can_attack = false
	current_attack_hit = false
	$AttackCooldown.start()
	$AnimatedSprite2D.play(get_attack_anim())
	hit.emit()


func _on_attack_hitbox_area_entered(area):
	pass
	#if area.name == "PlayerHitbox":
		#player = area.get_parent()
		#player.take_damage(enemy_attack_damage, global_position)
		#current_attack_hit = true  # Mark this attack as having hit
		# No need to temporarily disable the hitbox, we're tracking hits instead

func _on_hitbox_area_entered(area: Area2D) -> void:
	if dying:
		return

	# Check if the area is the player's attack hitbox
	if area.get_parent().name == "Player" and area.name == "AttackHitbox":
		# Get the player node
		player = area.get_parent()
		
		# Determine attack type by checking player's current animation
		var attack_type = "light_attack"
		var knockback_force = light_attack_knockback
		var damage = light_attack_damage
		
		#Allow The player to immediately cancel the attack
		player.canAttack = true

		if player.get_node("AnimatedSprite2D").animation == "medium_attack":
			attack_type = "medium_attack"
			knockback_force = medium_attack_knockback
			damage = medium_attack_damage
		elif player.get_node("AnimatedSprite2D").animation == "heavy_attack":
			attack_type = "heavy_attack"
			knockback_force = heavy_attack_knockback
			damage = heavy_attack_damage
		elif player.get_node("AnimatedSprite2D").animation == "special_attack":
			attack_type = "special_attack"
			knockback_force = special_attack_knockback
			damage = special_attack_damage
		elif player.get_node("AnimatedSprite2D").animation == "dash_attack":
			attack_type = "dash_attack"
			knockback_force = dash_attack_knockback
			damage = dash_attack_damage

		#shell mechanic logic
		if current_state == State.IN_SHELL:
			# only special or dash attacks can break the shell
			if attack_type == "special_attack" or attack_type == "dash_attack":
				player.register_hit(attack_type)
				is_shell_breaking = true
				$AnimatedSprite2D.play("shell_break")
			else:
				# visual feedback & light knockback
				player.register_hit(attack_type)
				$AnimatedSprite2D.modulate = Color(1,0.5,0.5)
				get_tree().create_timer(0.2).timeout.connect(reset_color)
				var dir = (global_position - player.global_position).normalized()
				linear_velocity = dir * (knockback_force * 0.3)
				hurt.emit()
			return

		elif has_shell and current_state != State.IN_SHELL:
			player.register_hit(attack_type)

			#enter shell
			current_state = State.RETREATING
			$AnimatedSprite2D.play("retreat_toshell")
			linear_velocity = Vector2.ZERO
			$AnimatedSprite2D.modulate = Color(1.0, 0.5, 0.5)  # Red tint
			get_tree().create_timer(0.2).timeout.connect(reset_color)
			return

		take_damage(damage)
		
		# Register successful hit
		player.register_hit(attack_type)

		# Calculate knockback direction (away from player)
		var knockback_direction = (global_position - player.global_position).normalized()
		
		# Apply the knockback force
		linear_velocity = knockback_direction * knockback_force
		
		# Set higher damping during knockback to slow down gradually
		linear_damp = 5.0
		
		# Start recovery timer
		being_hit = true
		knockback_timer = recovery_time
		
		$AnimatedSprite2D.modulate = Color(1.0, 0.5, 0.5)  # Red tint
		# Schedule returning to normal color
		get_tree().create_timer(0.2).timeout.connect(reset_color)

func reset_color() -> void:
	$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0)  # Reset to white

func take_damage(amount: int) -> void:
	hurt.emit()
	current_health -= amount
	
	$CPUParticles2D.emitting = true
	await get_tree().create_timer(0.1).timeout
	$CPUParticles2D.emitting = false
	
	# Optional: Print health for debugging
	print("Enemy took " + str(amount) + " damage. Health: " + str(current_health) + "/" + str(max_health))
	
	# Check if enemy should die
	if current_health <= 0:
		die()

func die() -> void:
	# Prevent multiple death processes
	if dying:
		return
	
	dying = true
	death.emit()
	
	# Disable collisions
	$CollisionShape2D.set_deferred("disabled", true)
	$Hitbox/CollisionShape2D.set_deferred("disabled", true)
	
	# Visual feedback - fade out
	var tween = create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate", Color(1, 0, 0, 0), 0.5)
	tween.tween_callback(queue_free)
	
	# You can also play a death sound here
	# $DeathSound.play()
