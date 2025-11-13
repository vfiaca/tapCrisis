extends CharacterBody3D
class_name Enemy

@export var max_health: int = 3
var current_health: int = max_health

func _ready():
	add_to_group("enemy")
	current_health = max_health

func take_damage(amount: int):
	current_health -= amount
	print(name, " took ", amount, " damage. Health: ", current_health)
	
	# Visual feedback (flash)
	flash_damage()
	
	if current_health <= 0:
		die()

func flash_damage():
	# Simple color flash
	var mesh = $EnemyMesh as MeshInstance3D
	if mesh:
		var mat = mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if mat:
			# Flash white briefly
			mat.albedo_color = Color.WHITE
			await get_tree().create_timer(0.1).timeout
			mat.albedo_color = Color.RED

func die():
	print(name, " died!")
	queue_free()
