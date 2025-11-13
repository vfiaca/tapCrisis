extends Node3D
class_name EnemyController

## Enemy character with ragdoll physics that reacts to hits

enum State {
	STANDING,
	RAGDOLL
}

@export_group("Physics")
@export var hit_force_multiplier: float = 10.0  ## Force multiplier for ragdoll reaction

# State
var current_state: State = State.STANDING

# References to physical bones (will be set up in scene)
var physical_bones: Array[PhysicalBone3D] = []
var skeleton: Skeleton3D = null
var visual_body: Node3D = null

func _ready():
	add_to_group("enemy")

	# Find skeleton and physical bones
	skeleton = _find_skeleton(self)
	if skeleton:
		physical_bones = _collect_physical_bones(skeleton)
		print("Enemy found skeleton: ", skeleton.name)
		print("Enemy found ", physical_bones.size(), " physical bones")
		for bone in physical_bones:
			print("  - ", bone.name)

		# Find and attach visual body to physical bones
		visual_body = skeleton.get_node_or_null("VisualBody")
		if visual_body:
			_attach_visuals_to_bones()
		else:
			push_warning("Enemy: No VisualBody found")
	else:
		push_error("Enemy: No skeleton found!")

	# Start in standing state (physical bones disabled)
	_set_ragdoll_enabled(false)
	print("Enemy ready, state: ", State.keys()[current_state])

## Find skeleton in children
func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result:
			return result
	return null

## Collect all PhysicalBone3D nodes
func _collect_physical_bones(node: Node) -> Array[PhysicalBone3D]:
	var bones: Array[PhysicalBone3D] = []
	if node is PhysicalBone3D:
		bones.append(node)
	for child in node.get_children():
		bones.append_array(_collect_physical_bones(child))
	return bones

## Attach visual meshes to their corresponding physical bones
func _attach_visuals_to_bones():
	if not visual_body:
		return

	print("Enemy: Attaching visual meshes to physical bones")

	# Map mesh names to bone names
	var mesh_to_bone = {
		"LowerMesh": "PhysicalBone_Lower",
		"MiddleMesh": "PhysicalBone_Middle",
		"UpperMesh": "PhysicalBone_Upper",
		"HeadMesh": "PhysicalBone_Head"
	}

	# Reparent each mesh to its corresponding physical bone
	for mesh_name in mesh_to_bone:
		var mesh_node = visual_body.get_node_or_null(mesh_name)
		var bone_name = mesh_to_bone[mesh_name]

		if mesh_node:
			# Find the corresponding physical bone
			var phys_bone = _find_physical_bone_by_name(bone_name)
			if phys_bone:
				print("  Attaching ", mesh_name, " to ", bone_name)

				# Store global transform before reparenting
				var global_trans = mesh_node.global_transform

				# Reparent to physical bone
				mesh_node.reparent(phys_bone)

				# Restore global transform (so mesh stays in same world position)
				mesh_node.global_transform = global_trans

				print("    Success!")
			else:
				push_warning("  Could not find physical bone: ", bone_name)
		else:
			push_warning("  Could not find mesh: ", mesh_name)

## Find a physical bone by name
func _find_physical_bone_by_name(bone_name: String) -> PhysicalBone3D:
	for bone in physical_bones:
		if bone.name == bone_name:
			return bone
	return null

## Enable or disable ragdoll physics
func _set_ragdoll_enabled(enabled: bool):
	if not skeleton:
		push_error("Enemy: Cannot set ragdoll - no skeleton!")
		return

	print("Enemy: Setting ragdoll enabled = ", enabled)

	if enabled:
		# Start physics simulation on all physical bones
		skeleton.physical_bones_start_simulation()
		print("Enemy: Called physical_bones_start_simulation()")
	else:
		# Stop physics simulation
		skeleton.physical_bones_stop_simulation()
		print("Enemy: Called physical_bones_stop_simulation()")

## Take damage from a hit
func take_damage(amount: int, hit_position: Vector3, force_direction: Vector3, hit_force: float = 1.0):
	print("Enemy taking damage: ", amount, " at ", hit_position)
	print("Enemy current state: ", State.keys()[current_state])

	if current_state == State.STANDING:
		print("Enemy: Switching to ragdoll...")
		# Switch to ragdoll
		_activate_ragdoll()
	else:
		print("Enemy: Already in ragdoll state")

	# Apply force to the closest physical bone
	_apply_hit_force(hit_position, force_direction, hit_force)

## Activate ragdoll physics
func _activate_ragdoll():
	print("Enemy: _activate_ragdoll() called")
	current_state = State.RAGDOLL
	print("Enemy: State changed to RAGDOLL")
	_set_ragdoll_enabled(true)
	print("Enemy ragdoll activated")

## Apply force to physical bones near hit position
func _apply_hit_force(hit_position: Vector3, force_direction: Vector3, hit_force: float):
	print("Enemy: _apply_hit_force() called")
	print("  Hit position: ", hit_position)
	print("  Force direction: ", force_direction)
	print("  Hit force: ", hit_force)
	print("  Physical bones count: ", physical_bones.size())

	if physical_bones.is_empty():
		push_error("Enemy: No physical bones to apply force to!")
		return

	# Find closest physical bone to hit position
	var closest_bone: PhysicalBone3D = null
	var closest_distance: float = INF

	for bone in physical_bones:
		var distance = bone.global_position.distance_to(hit_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_bone = bone

	# Apply impulse to closest bone
	if closest_bone:
		print("  Closest bone: ", closest_bone.name, " at distance: ", closest_distance)
		# Use provided force direction (from player's gun to hit point)
		var impulse = force_direction * hit_force * hit_force_multiplier

		print("  Impulse: ", impulse)

		# Apply central impulse
		closest_bone.apply_central_impulse(impulse)

		print("  Applied impulse to ", closest_bone.name)
	else:
		push_error("Enemy: Could not find closest bone!")
