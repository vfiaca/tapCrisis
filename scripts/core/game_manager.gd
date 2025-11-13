extends Node3D
class_name GameManager

## Main game manager - handles input and coordinates camera/player

@export var starting_cover: CoverPoint = null
@export var starting_side: String = "left"

# Swipe detection
var swipe_start_pos: Vector2 = Vector2.ZERO
var is_swiping: bool = false
const SWIPE_THRESHOLD: float = 50.0

# References
var player: PlayerController = null
var camera: CameraController = null
var covers: Array[CoverPoint] = []

func _ready():
	print("=== Game Manager Starting ===")

	# Find camera
	camera = get_node_or_null("CameraController")
	if not camera:
		push_error("CameraController not found!")
		return

	# Find player
	player = get_node_or_null("Player")
	if not player:
		push_error("Player not found!")
		return

	# Collect all covers
	_collect_covers(self)
	print("Found ", covers.size(), " covers")

	# Set camera reference to player
	camera.set_player(player)

	# Find starting cover if not set
	if not starting_cover and covers.size() > 0:
		starting_cover = covers[0]

	if starting_cover:
		# Move player to starting cover
		player.move_to_cover(starting_cover, starting_side)
		# Move camera to starting cover
		camera.transition_to_cover(starting_cover, starting_side)
		print("Started at cover: ", starting_cover.get_display_name())
	else:
		push_error("No starting cover set!")

func _collect_covers(node: Node):
	for child in node.get_children():
		if child is CoverPoint:
			covers.append(child)
		_collect_covers(child)

func _input(event):
	if not player or not camera:
		return

	# Handle touch/mouse for shooting and swiping
	if event is InputEventScreenTouch:
		if event.pressed:
			swipe_start_pos = event.position
			is_swiping = true
		else:
			if is_swiping:
				_handle_swipe(event.position)
			is_swiping = false

	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			swipe_start_pos = event.position
			is_swiping = true
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_swiping:
				_handle_swipe(event.position)
			is_swiping = false

	# Keyboard shortcuts for testing
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_A, KEY_LEFT:
				_handle_swipe_direction("left")
			KEY_D, KEY_RIGHT:
				_handle_swipe_direction("right")
			KEY_W, KEY_UP:
				_handle_swipe_direction("forward")
			KEY_S, KEY_DOWN:
				_handle_swipe_direction("back")

func _handle_swipe(end_pos: Vector2):
	var swipe_vector = end_pos - swipe_start_pos
	var swipe_length = swipe_vector.length()

	# If swipe is too short, treat as tap to shoot
	if swipe_length < SWIPE_THRESHOLD:
		_handle_tap(end_pos)
		return

	# Determine swipe direction
	var angle = swipe_vector.angle()

	# Horizontal swipe (left/right)
	if abs(cos(angle)) > 0.7:
		if swipe_vector.x > 0:
			_handle_swipe_direction("right")
		else:
			_handle_swipe_direction("left")
	# Vertical swipe (up/down)
	else:
		if swipe_vector.y < 0:
			_handle_swipe_direction("forward")
		else:
			_handle_swipe_direction("back")

func _handle_tap(screen_pos: Vector2):
	print("Tap at: ", screen_pos)

	# Trigger player shooting animation/timing
	var can_shoot = await player.handle_shoot_input()

	# Check if player can shoot (not on cooldown)
	if not can_shoot:
		print("Player can't shoot yet (cooldown)")
		return

	# Camera performs hit detection
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_direction = camera.project_ray_normal(screen_pos)
	var ray_end = ray_origin + ray_direction * 1000.0

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)

	if result.size() > 0:
		print("GameManager: Camera hit something")
		var hit_position = result.position
		var hit_normal = result.normal
		var collider = result.collider

		# Check if enemy
		var enemy = _find_enemy_controller(collider)
		if enemy:
			print("GameManager: Hit enemy!")
			# Calculate force direction from player's gun position
			var force_direction = (hit_position - player.shoot_origin.global_position).normalized()
			var hit_force = 5.0
			enemy.take_damage(1, hit_position, force_direction, hit_force)

		# Visualize from player's perspective
		player.visualize_shot(hit_position)
	else:
		print("GameManager: Camera missed")
		# Visualize miss
		player.visualize_shot(ray_end)

## Find enemy (EnemyController or EnemySimpleController) in node or parents
func _find_enemy_controller(node: Node):
	# Check if node itself is an enemy controller
	if node is EnemyController or node is EnemySimpleController:
		return node

	# If node is in enemy group, return it
	if node.is_in_group("enemy"):
		return node

	# Check parent hierarchy
	var current = node.get_parent()
	while current:
		if current is EnemyController or current is EnemySimpleController:
			return current
		if current.is_in_group("enemy"):
			return current
		current = current.get_parent()

	return null

func _handle_swipe_direction(direction: String):
	print("Swipe: ", direction)

	if not player.current_cover:
		return

	# Check if swiping to opposite side of same cover
	if direction == "left" and player.current_side == "right":
		if player.current_cover.has_left_side():
			# Camera leads, player follows after delay
			camera.transition_to_cover(player.current_cover, "left")
			await get_tree().create_timer(camera.transition_lead_time).timeout
			player.rotate_to_side("left")
			return
	elif direction == "right" and player.current_side == "left":
		if player.current_cover.has_right_side():
			# Camera leads, player follows after delay
			camera.transition_to_cover(player.current_cover, "right")
			await get_tree().create_timer(camera.transition_lead_time).timeout
			player.rotate_to_side("right")
			return

	# Otherwise, move to connected cover
	var next_cover = player.current_cover.get_connection(direction)

	if next_cover:
		# Determine which side to enter from
		var next_side = _determine_entry_side(next_cover, direction)

		# Camera leads, player follows after delay
		camera.transition_to_cover(next_cover, next_side)
		await get_tree().create_timer(camera.transition_lead_time).timeout
		player.move_to_cover(next_cover, next_side)
	else:
		print("No cover in direction: ", direction)

func _determine_entry_side(cover: CoverPoint, from_direction: String) -> String:
	# Determine entry side based on direction of movement
	# When moving left, enter from right side (you're coming from the right)
	# When moving right, enter from left side (you're coming from the left)

	var preferred_side = ""

	match from_direction:
		"left":
			# Coming from the right, enter right side
			preferred_side = "right"
		"right":
			# Coming from the left, enter left side
			preferred_side = "left"
		"forward", "back":
			# For forward/back movement, maintain current side if possible
			preferred_side = player.current_side

	# Check if preferred side exists, otherwise use the other side
	if preferred_side == "left" and cover.has_left_side():
		return "left"
	elif preferred_side == "right" and cover.has_right_side():
		return "right"
	elif cover.has_left_side():
		return "left"
	elif cover.has_right_side():
		return "right"

	# Fallback
	return "left"
