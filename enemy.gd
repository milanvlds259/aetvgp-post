extends RigidBody2D

@export var max_health = 100
@export var light_attack_damage = 20
@export var medium_attack_damage = 35
@export var heavy_attack_damage = 50
@export var light_attack_knockback = 400.0
@export var medium_attack_knockback = 800.0
@export var heavy_attack_knockback = 1200.0
@export var recovery_time = 0.5

var current_health = 0
var being_hit = false
var knockback_timer = 0.0
var dying = false

signal hurt
signal death


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_health = max_health
	# Connect the hitbox detection
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Handle recovery from knockback
	if being_hit:
		knockback_timer -= delta
		if knockback_timer <= 0:
			being_hit = false
			# Reset to normal physics mode after recovery
			linear_damp = 3.0

func _on_hitbox_area_entered(area: Area2D) -> void:
	if dying:
		return

	# Check if the area is the player's attack hitbox
	if area.get_parent().name == "Player" and area.name == "AttackHitbox":
		# Get the player node
		var player = area.get_parent()
		
		# Determine attack type by checking player's current animation
		var knockback_force = light_attack_knockback
		var damage = light_attack_damage
		
		#Allow The player to immediately cancel the attack
		player.canAttack = true

		if player.get_node("AnimatedSprite2D").animation == "medium_attack":
			knockback_force = medium_attack_knockback
			damage = medium_attack_damage
		elif player.get_node("AnimatedSprite2D").animation == "heavy_attack":
			knockback_force = heavy_attack_knockback
			damage = heavy_attack_damage

		take_damage(damage)
		
		# Calculate knockback direction (away from player)
		var knockback_direction = (global_position - player.global_position).normalized()
		
		# Apply the knockback force
		linear_velocity = knockback_direction * knockback_force
		
		# Set higher damping during knockback to slow down gradually
		linear_damp = 5.0
		
		# Start recovery timer
		being_hit = true
		knockback_timer = recovery_time
		
		# Optional: Add visual feedback for being hit
		$Sprite2D.modulate = Color(1.0, 0.5, 0.5)  # Red tint
		# Schedule returning to normal color
		get_tree().create_timer(0.2).timeout.connect(reset_color)

func reset_color() -> void:
	$Sprite2D.modulate = Color(1.0, 1.0, 1.0)  # Reset to white

func take_damage(amount: int) -> void:
	hurt.emit()
	current_health -= amount
	
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
	tween.tween_property($Sprite2D, "modulate", Color(1, 0, 0, 0), 0.5)
	tween.tween_callback(queue_free)
	
	# You can also play a death sound here
	# $DeathSound.play()
