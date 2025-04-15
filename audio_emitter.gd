extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var player = get_parent().get_node("Player")
	player.light_atk.connect(_on_light_atk)
	player.med_atk.connect(_on_med_atk)
	player.heavy_atk.connect(_on_heavy_atk)
	player.special_atk.connect(_on_special_atk)
	player.dash_atk.connect(_on_special_atk)
	
	for node: RigidBody2D in get_tree().get_nodes_in_group("enemy"):
		node.hurt.connect(_on_hurt)
		node.death.connect(_on_death)
		node.hit.connect(_on_attack)
	
	for node: RigidBody2D in get_tree().get_nodes_in_group("enemy2"):
		node.hurt.connect(_on_hurt)
		node.death.connect(_on_death2)
		node.shoot.connect(_on_shoot)

func _on_light_atk():
	$LightAtk.play()

func _on_med_atk():
	$MedAtk.play()

func _on_heavy_atk():
	$HeavyAtk.play()

func _on_special_atk():
	$SpecialAtk.play()

func _on_hurt():
	$EnemyHurt.play()

func _on_death():
	$EnemyDie.play()

func _on_attack():
	$EnemyHit.play()

func _on_death2():
	$Enemy2Die.play()

func _on_shoot():
	$EnemyShoot.play()

func splat():
	$Splat.play()
