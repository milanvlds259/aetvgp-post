extends Area2D

var direction = Vector2.RIGHT
@export var speed = 300.0
@export var damage = 15

var sfx

func _ready():
	# Connect signals
	area_entered.connect(_on_area_entered)
	
	# Start auto-destroy timer (in case it never hits anything)
	get_tree().create_timer(5.0).timeout.connect(queue_free)
	
	sfx = get_tree().root.get_node("Node2D").get_node("AudioEmitter")

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

func _on_area_entered(area):
	if area.name == "PlayerHitbox":
		var player = area.get_parent()
		player.take_damage(damage, global_position)
		sfx.splat()
		queue_free()
