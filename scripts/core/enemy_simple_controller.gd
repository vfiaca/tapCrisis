extends RigidBody3D
class_name EnemySimpleController

## Simple enemy with basic ragdoll physics using RigidBody3D

enum State {
	STANDING,
	RAGDOLL
}

@export_group("Physics")
@export var hit_force_multiplier: float = 10.0  ## Force multiplier for ragdoll reaction

# State
var current_state: State = State.STANDING

func _ready():
	add_to_group("enemy")

	# Start frozen (not affected by physics)
	freeze = true

	print("Simple enemy ready, state: ", State.keys()[current_state])

## Take damage from a hit
func take_damage(amount: int, hit_position: Vector3, force_direction: Vector3, hit_force: float = 1.0):
	print("Simple enemy taking damage: ", amount, " at ", hit_position)
	print("Simple enemy current state: ", State.keys()[current_state])

	if current_state == State.STANDING:
		print("Simple enemy: Switching to ragdoll...")
		_activate_ragdoll()

	# Apply force at hit position
	_apply_hit_force(hit_position, force_direction, hit_force)

## Activate ragdoll physics
func _activate_ragdoll():
	print("Simple enemy: _activate_ragdoll() called")
	current_state = State.RAGDOLL

	# Unfreeze the rigid body so physics takes over
	freeze = false

	print("Simple enemy: Ragdoll activated (unfrozen)")

## Apply force at hit position
func _apply_hit_force(hit_position: Vector3, force_direction: Vector3, hit_force: float):
	print("Simple enemy: _apply_hit_force() called")
	print("  Hit position: ", hit_position)
	print("  Force direction: ", force_direction)
	print("  Hit force: ", hit_force)
	print("  Body frozen: ", freeze)

	if current_state == State.RAGDOLL:
		# Use provided force direction (from player's gun to hit point)
		var impulse = force_direction * hit_force * hit_force_multiplier

		print("  Impulse: ", impulse)

		# Apply impulse at the hit position (creates torque)
		apply_impulse(impulse, hit_position - global_position)

		print("  Applied impulse to RigidBody3D")
	else:
		print("  Skipping impulse - not in ragdoll state yet")
