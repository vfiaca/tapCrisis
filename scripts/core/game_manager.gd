extends Node3D
class_name GameManager

## Main game manager - handles input and coordinates camera/player

@export var starting_cover: CoverPoint = null
@export var starting_side: String = "left"

# Swipe detection
var swipe_start_pos: Vector2 = Vector2.ZERO
var is_swiping: bool = false
const SWIPE_THRESHOLD: float = 50.0

# Timing defaults
const DEFAULT_CAMERA_START_DELAY: float = 0.3  ## Default delay before camera follows player

# References
var player: PlayerController = null
var camera: CameraController = null
var covers: Array[CoverPoint] = []

# Input state
var is_transitioning: bool = false  ## Block input during camera/player transitions

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

	# Ensure starting_side has a valid value
	if not starting_side or starting_side == "":
		starting_side = "left"
		print("Warning: starting_side was not set, defaulting to 'left'")

	if starting_cover:
		# Move player to starting cover
		player.move_to_cover(starting_cover, starting_side)
		# Move camera to starting cover
		camera.transition_to_cover(starting_cover, starting_side)
		print("Started at cover: ", starting_cover.get_display_name(), " (side: ", starting_side, ")")
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

	# Block input during transitions
	if is_transitioning:
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
	print("=== Swipe Debug ===")
	print("  Direction: ", direction)
	print("  Current cover: ", player.current_cover.get_display_name() if player.current_cover else "None")
	print("  Current side: ", player.current_side)
	print("  Has left side: ", player.current_cover.has_left_side() if player.current_cover else "N/A")
	print("  Has right side: ", player.current_cover.has_right_side() if player.current_cover else "N/A")

	if not player.current_cover:
		return

	# Block further input during transition
	is_transitioning = true

	# Check if swiping to opposite side of same cover
	# Only attempt rotation if current cover has BOTH sides active
	if direction == "left" and player.current_side == "right":
		# Only rotate if the target side exists AND we're currently on the opposite side
		if player.current_cover.has_left_side() and player.current_cover.has_right_side():
			# No custom path for same-cover side switches
			# Player starts rotating first
			player.rotate_to_side("left")
			var delay = player.current_cover.camera_start_delay if player.current_cover.camera_start_delay >= 0 else DEFAULT_CAMERA_START_DELAY
			print("Player started rotating, waiting ", delay, "s before camera follows")
			await get_tree().create_timer(delay).timeout
			# Camera follows after delay
			print("Camera starting transition now")
			await camera.transition_to_cover(player.current_cover, "left", null)
			is_transitioning = false
			return
	elif direction == "right" and player.current_side == "left":
		# Only rotate if the target side exists AND we're currently on the opposite side
		if player.current_cover.has_right_side() and player.current_cover.has_left_side():
			# No custom path for same-cover side switches
			# Player starts rotating first
			player.rotate_to_side("right")
			var delay = player.current_cover.camera_start_delay if player.current_cover.camera_start_delay >= 0 else DEFAULT_CAMERA_START_DELAY
			print("Player started rotating, waiting ", delay, "s before camera follows")
			await get_tree().create_timer(delay).timeout
			# Camera follows after delay
			print("Camera starting transition now")
			await camera.transition_to_cover(player.current_cover, "right", null)
			is_transitioning = false
			return

	# Otherwise, move to connected cover
	var next_cover = player.current_cover.get_connection(direction)

	if next_cover:
		# Determine which side to enter from
		var next_side = _determine_entry_side(next_cover, direction)

		# Save SOURCE cover reference before player state changes
		var source_cover = player.current_cover

		# Check for custom paths for this direction
		# For forward/back, look for side-specific paths first
		var camera_path = _get_path_for_direction(source_cover, direction, "camera", player.current_side)
		var player_path = _get_path_for_direction(source_cover, direction, "player", player.current_side)

		# Respect source cover's force_linear_transition setting
		if source_cover.force_linear_transition:
			camera_path = null
			print("Source cover has force_linear_transition = true, using linear camera movement")

		if camera_path:
			print("Using custom camera path for ", direction, ": ", camera_path.name)
		else:
			print("No camera path - using linear camera transition")

		if player_path:
			print("Using custom player path for ", direction, ": ", player_path.name)
		else:
			print("No player path - player will snap to position")

		# Use SOURCE cover's timing (where we're leaving FROM, not going TO)
		var delay = source_cover.camera_start_delay if source_cover.camera_start_delay >= 0 else DEFAULT_CAMERA_START_DELAY

		# Player starts moving first
		player.move_to_cover(next_cover, next_side, player_path)
		print("Player started moving, waiting ", delay, "s before camera follows")
		await get_tree().create_timer(delay).timeout
		# Camera follows after delay
		print("Camera starting transition now")
		await camera.transition_to_cover(next_cover, next_side, camera_path)
		is_transitioning = false
	else:
		print("No cover in direction: ", direction)
		is_transitioning = false

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

## Get path for a direction, checking for side-specific paths first
func _get_path_for_direction(cover: CoverPoint, direction: String, path_type: String, current_side: String) -> Path3D:
	# For all movements, check for side-specific path first
	# e.g., "Path_Forward_Camera_Left", "Path_Right_Player_Right", etc.
	var side_specific_name = "Path_" + direction.capitalize() + "_" + path_type.capitalize() + "_" + current_side.capitalize()
	var side_specific_path = cover.get_node_or_null(side_specific_name)

	if side_specific_path and side_specific_path is Path3D:
		return side_specific_path

	# Fall back to generic path (from export properties or generic child node)
	# First try the export property
	var generic_path = null
	if path_type == "camera":
		generic_path = cover.get_camera_path(direction)
	else:
		generic_path = cover.get_player_path(direction)

	if generic_path:
		return generic_path

	# Finally, try finding a generic path node
	var generic_name = "Path_" + direction.capitalize() + "_" + path_type.capitalize()
	var generic_node = cover.get_node_or_null(generic_name)
	if generic_node and generic_node is Path3D:
		return generic_node

	return null
