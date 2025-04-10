extends Area2D

var direction = Vector2.RIGHT
@export var speed = 300.0
@export var damage = 15

func _ready():
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	# Start auto-destroy timer (in case it never hits anything)
	get_tree().create_timer(5.0).timeout.connect(queue_free)

func _process(delta):
	# Move in the specified direction
	position += direction * speed * delta

func initialize(dir: Vector2, dmg: int, spd: float):
	direction = dir.normalized()
	damage = dmg
	speed = spd
		
	# Rotate the sprite to face the direction of travel
	rotation = direction.angle() + PI  # Adjust for sprite facing direction

	# Optional: Set the scale based on the direction

func _on_body_entered(body):
	# Check if we hit the player
	if body.name == "Player" and body.has_method("take_damage"):
		body.take_damage(damage)
		# Create hit effect if desired
		# var hit_effect = hit_effect_scene.instantiate()
		# hit_effect.global_position = global_position
		# get_tree().current_scene.add_child(hit_effect)
		
	# Destroy the projectile on impact with any body
		queue_free()
