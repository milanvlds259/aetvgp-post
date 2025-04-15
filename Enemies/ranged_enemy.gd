extends RigidBody2D

@export var max_health = 80
@export var light_attack_damage = 15
@export var medium_attack_damage = 25
@export var heavy_attack_damage = 40
@export var special_attack_damage = 80
@export var light_attack_knockback = 400.0
@export var medium_attack_knockback = 800.0
@export var heavy_attack_knockback = 1200.0
@export var special_attack_knockback = 300.0
@export var dash_attack_damage = 80
@export var dash_attack_knockback = 50.0
@export var recovery_time = 0.5

@export var movement_speed = 60
@export var run_away_speed = 100
@export var projectile_damage = 15
@export var projectile_scene: PackedScene = preload("res://Enemies/enemy_projectile.tscn")

enum State {IDLE, CHASE, SHOOT, PANIC, ATTACK}
var current_state = State.IDLE

var current_health = 0
var being_hit = false
var knockback_timer = 0.0
var dying = false
var player = null
var can_shoot = true
var shoot_cooldown = 2.0  # Seconds between shots

signal hurt
signal death
signal shoot

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_health = max_health
	# Connect the hitbox detection
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)

	$PlayerDetection.body_entered.connect(_on_player_detected)
	$PlayerDetection.body_exited.connect(_on_player_exited)
	
	$ShootingZone.body_entered.connect(_on_shooting_zone_body_entered)
	$ShootingZone.body_exited.connect(_on_shooting_zone_body_exited)
	
	$PanicZone.body_entered.connect(_on_panic_zone_body_entered)
	$PanicZone.body_exited.connect(_on_panic_zone_body_exited)

	$AttackCooldown.timeout.connect(_on_attack_cooldown_timeout)
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	$AnimatedSprite2D.frame_changed.connect(_on_frame_changed)

	$AnimatedSprite2D.play("idle")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Handle recovery from knockback
	if being_hit:
		knockback_timer -= delta
		if knockback_timer <= 0:
			being_hit = false
			# Reset to normal physics mode after recovery
			linear_damp = 3.0
			update_state()
	elif !dying:
		match current_state:
			State.IDLE:
				if $AnimatedSprite2D.animation != "idle":
					$AnimatedSprite2D.play("idle")
				linear_velocity = Vector2.ZERO
				
			State.CHASE:
				# Chase the player
				if player != null:
					var direction = (player.global_position - global_position).normalized()
					update_facing_direction(direction)
					linear_velocity = direction * movement_speed
					if $AnimatedSprite2D.animation != "walk":
						$AnimatedSprite2D.play("walk")
						
			State.SHOOT:
				# Stand still and shoot at the player
				if player != null:
					var direction = (player.global_position - global_position).normalized()
					update_facing_direction(direction)
					linear_velocity = Vector2.ZERO
					
					# Shoot periodically
					if can_shoot and !$AnimatedSprite2D.animation == "attack":
						shoot_at_player()
						
			State.PANIC:
				# Run away from the player
				if player != null:
					var direction = (global_position - player.global_position).normalized()
					update_facing_direction(-direction)  # Flip the sprite in the moving direction
					linear_velocity = direction * run_away_speed
					if $AnimatedSprite2D.animation != "walk":
						$AnimatedSprite2D.play("walk")
			
			State.ATTACK:
				if $AnimatedSprite2D.animation != "attack":
					$AnimatedSprite2D.play("attack")
				linear_velocity = Vector2.ZERO

# Updates the enemy state based on player position
func update_state():
	if dying or being_hit:
		return
		
	# State priorities (from highest to lowest):
	# 1. Panic Zone
	# 2. Shooting Zone
	# 3. Detection Zone
	if player != null:
		if $PanicZone.overlaps_body(player):
			current_state = State.PANIC
		elif $ShootingZone.overlaps_body(player):
			current_state = State.SHOOT
		elif $PlayerDetection.overlaps_body(player):
			current_state = State.CHASE
		else:
			current_state = State.IDLE

func update_facing_direction(direction):
	if direction.x > 0:
		$AnimatedSprite2D.flip_h = true
	else:
		$AnimatedSprite2D.flip_h = false

func _on_player_detected(body):
	if body.name == "Player" and !dying and !being_hit:
		player = body
		if current_state == State.IDLE:  # Only change state if not in a higher priority state
			current_state = State.CHASE

func _on_player_exited(body):
	if body.name == "Player" and !dying:
		if !$ShootingZone.overlaps_body(body) and !$PanicZone.overlaps_body(body):
			player = null
			current_state = State.IDLE

func _on_shooting_zone_body_entered(body):
	if body.name == "Player" and !dying and !being_hit:
		player = body
		if current_state != State.PANIC:  # Only change if not in panic mode
			current_state = State.SHOOT

func _on_shooting_zone_body_exited(body):
	if body.name == "Player" and !dying:
		update_state()  # Reevaluate state based on player position

func _on_panic_zone_body_entered(body):
	if body.name == "Player" and !dying and !being_hit:
		player = body
		current_state = State.PANIC  # Highest priority state

func _on_panic_zone_body_exited(body):
	if body.name == "Player" and !dying:
		update_state()  # Reevaluate state based on player position

func _on_attack_cooldown_timeout():
	can_shoot = true

func _on_animation_finished():
	if $AnimatedSprite2D.animation == "attack" and !dying and !being_hit:
		update_state()
		
func _on_frame_changed():
	if $AnimatedSprite2D.animation == "attack":
		var frame = $AnimatedSprite2D.frame
		
		# Fire the projectile at a specific frame (adjust as needed for your animation)
		if frame == 8:  # Middle of the attack animation
			fire_projectile()

func shoot_at_player():
	can_shoot = false
	current_state = State.ATTACK
	$AttackCooldown.wait_time = shoot_cooldown
	$AttackCooldown.start()
	$AnimatedSprite2D.play("attack")
	await get_tree().create_timer(0.25).timeout
	shoot.emit()

func fire_projectile():
	if player == null or dying:
		return
		
	# Create projectile instance
	var projectile = projectile_scene.instantiate()
	
	# Position the projectile at the enemy
	var spawn_position = global_position
	# Offset the projectile position to appear from the enemy's front
	var direction = (player.global_position - global_position).normalized()
	spawn_position += direction * 20
	
	projectile.global_position = spawn_position
	
	# Add the projectile to the scene
	get_tree().get_root().add_child(projectile)
	
	# Setup projectile properties
	# We need to add a script to projectile.tscn to handle movement and collisions
	if projectile.has_method("initialize"):
		projectile.initialize(direction, projectile_damage, 300.0)  # direction, damage, speed
	
	# Play animation
	projectile.get_node("AnimatedSprite2D").play("default")
	
	# Play sound effect if you have one
	# $ShootSound.play()

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
		get_tree().create_timer(0.2).timeout.connect(reset_color)

func reset_color() -> void:
	$AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0)  # Reset to white

func take_damage(amount: int) -> void:
	hurt.emit()
	current_health -= amount
	
	$CPUParticles2D.emitting = true
	await get_tree().create_timer(0.1).timeout
	$CPUParticles2D.emitting = false
	
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
