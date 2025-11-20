extends CharacterBody3D
class_name PlayerController

## Player character - animation puppet controlled by camera/input

enum State {
	IDLE,
	IN_COVER,
	SHOOTING,
	TRANSITIONING
}

@export_group("Starting Position")
@export var start_anchor: Marker3D = null  ## Optional: Set player to this anchor's position at start

@export_group("Settings")
@export var movement_duration: float = 0.4  ## How long it takes to move between covers
@export var rotation_duration: float = 0.25  ## How long it takes to rotate to opposite side

@export_group("Shooting Timing")
@export var step_out_speed: float = 1.0  ## Speed multiplier for step-out animation
@export var shoot_cooldown: float = 0.2  ## Time between shots while shooting
@export var last_shot_delay: float = 0.3  ## Time after last shot before stepping back in
@export var step_in_speed: float = 1.0  ## Speed multiplier for step-in animation

# State
var current_state: State = State.IN_COVER
var current_cover: CoverPoint = null
var current_side: String = "left"

# Shooting state
var is_stepped_out: bool = false  ## True when player has stepped out of cover
var can_shoot: bool = true
var shoot_timer: float = 0.0
var last_shot_timer: float = 0.0  ## Time since last shot (for auto step-in)

# Movement
var is_moving: bool = false
var move_start_pos: Vector3 = Vector3.ZERO
var move_target_pos: Vector3 = Vector3.ZERO
var move_progress: float = 0.0

# References
@onready var model: Node3D = $Model
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var animation_tree: AnimationTree = $AnimationTree if has_node("AnimationTree") else null
@onready var shoot_origin: Node3D = $Model/ShootOrigin

# Debug visualization
var debug_line: MeshInstance3D = null
var debug_hit_point: MeshInstance3D = null

func _ready():
	add_to_group("player")

	# Initialize animation to neutral position
	if animation_tree:
		animation_tree.active = true
		animation_tree.set("parameters/step/blend_position", 0.0)
		print("Player: Animation initialized to neutral position (blend_position = 0.0)")

	# Set to starting anchor if provided
	if start_anchor:
		global_position = start_anchor.global_position
		print("Player initialized at start anchor: ", start_anchor.name)

	# Create debug visualization meshes
	_create_debug_visuals()

func _process(delta: float):
	# Update shoot cooldown timer
	if shoot_timer > 0:
		shoot_timer -= delta
		if shoot_timer <= 0:
			can_shoot = true

	# Update last shot timer for auto step-in
	if is_stepped_out and last_shot_timer > 0:
		last_shot_timer -= delta
		if last_shot_timer <= 0:
			# Time to step back in
			_step_back_in()

	# Handle movement interpolation
	if is_moving:
		move_progress += delta
		var t = clamp(move_progress, 0.0, 1.0)
		# Use ease-in-out for smooth movement
		t = ease(t, -2.0)  # Cubic ease in-out
		global_position = move_start_pos.lerp(move_target_pos, t)

		if move_progress >= 1.0:
			is_moving = false
			global_position = move_target_pos  # Snap to final position

## Move to a new cover (optionally following a custom path)
func move_to_cover(target_cover: CoverPoint, target_side: String, custom_path: Path3D = null):
	if not target_cover:
		return

	current_state = State.TRANSITIONING

	# Save old state for animation transition
	var old_cover = current_cover
	var old_side = current_side

	# Update state immediately (before movement starts)
	current_cover = target_cover
	current_side = target_side

	# Determine transition animation
	var from_id = ""
	var to_id = target_cover.get_animation_id(target_side)

	if old_cover:
		from_id = old_cover.get_animation_id(old_side)

	print("Transitioning: ", from_id, " → ", to_id)

	# Use CoverPoint's player movement duration (overrides default)
	var duration = target_cover.player_movement_duration if target_cover.player_movement_duration > 0 else movement_duration

	# Get target position
	var anchor = target_cover.get_player_anchor(target_side)
	if anchor:
		var target_pos = anchor.global_position

		# If custom path is provided and has a valid curve, follow it
		if custom_path and custom_path.curve and custom_path.curve.point_count >= 2:
			await _follow_path(custom_path, target_pos, duration)
		else:
			# Default: smooth linear movement
			move_start_pos = global_position
			move_target_pos = target_pos
			move_progress = 0.0
			is_moving = true

			# Wait for movement to complete
			await get_tree().create_timer(duration).timeout

	# Movement complete, return to cover state
	current_state = State.IN_COVER

## Follow a Path3D curve to the destination
func _follow_path(path: Path3D, target_position: Vector3, duration: float = -1):
	var curve = path.curve
	var curve_length = curve.get_baked_length()

	# Use provided duration or fall back to default
	var move_duration = duration if duration > 0 else movement_duration

	if curve_length <= 0:
		push_warning("Player path curve has zero length, using linear movement")
		# Fallback to linear
		move_start_pos = global_position
		move_target_pos = target_position
		move_progress = 0.0
		is_moving = true
		await get_tree().create_timer(move_duration).timeout
		return

	print("Player following custom path: ", path.name, " (length: ", curve_length, ", duration: ", move_duration, "s)")

	# Disable lerp-based movement, we'll move manually along path
	is_moving = false

	# Sample along the curve over time
	var elapsed = 0.0
	while elapsed < move_duration:
		var t = elapsed / move_duration
		# Apply easing
		t = ease(t, -2.0)  # Cubic ease in-out

		# Sample position from curve
		var sampled_pos = curve.sample_baked(t * curve_length)
		# Convert from path's local space to world space
		global_position = path.to_global(sampled_pos)

		# Wait one frame
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	# Snap to final position
	global_position = target_position

## Rotate to opposite side of same cover
func rotate_to_side(new_side: String):
	if not current_cover:
		return

	if new_side == current_side:
		return

	print("Rotating to ", new_side, " side")

	current_state = State.TRANSITIONING

	# Update side immediately (before rotation starts)
	current_side = new_side

	# Get target position
	var anchor = current_cover.get_player_anchor(new_side)
	if anchor:
		# Start smooth rotation movement
		move_start_pos = global_position
		move_target_pos = anchor.global_position
		move_progress = 0.0
		is_moving = true

		# Wait for rotation to complete (faster than cover-to-cover movement)
		await get_tree().create_timer(rotation_duration).timeout

	# Rotation complete, return to cover state
	current_state = State.IN_COVER

## Handle shoot input - manages animation and timing only
## Returns true if shot was fired, false if on cooldown
func handle_shoot_input() -> bool:
	# Check if can shoot based on cooldown
	if not can_shoot:
		return false

	# IF IN COVER: Need to step out first
	if not is_stepped_out:
		current_state = State.SHOOTING
		await _step_out()

		# Mark as stepped out and start last shot timer
		is_stepped_out = true
		last_shot_timer = last_shot_delay

		# Start shoot cooldown for next shot
		can_shoot = false
		shoot_timer = shoot_cooldown

	# ELSE (OUT OF COVER): Shoot immediately
	else:
		# Reset last shot timer (delays stepping back in)
		last_shot_timer = last_shot_delay

		# Start shoot cooldown for next shot
		can_shoot = false
		shoot_timer = shoot_cooldown

	return true

## Step out from cover
func _step_out():
	if not animation_tree or not animation_player:
		return

	print("Player: Stepping out")

	# Determine which direction to step based on current side
	# Left side of cover → step RIGHT (out from left)
	# Right side of cover → step LEFT (out from right)
	var blend_position = 1 if current_side == "left" else -1

	animation_tree.active = true
	animation_player.speed_scale = step_out_speed

	# Calculate step out duration based on animation length and speed
	var step_out_duration = 0.15 / step_out_speed

	# Start step out animation
	animation_tree.set("parameters/step/blend_position", blend_position)

	# Wait for step out animation to complete
	await get_tree().create_timer(step_out_duration).timeout
	print("Player: Step out complete")

## Step back into cover
func _step_back_in():
	if not is_stepped_out:
		return

	if not animation_tree or not animation_player:
		is_stepped_out = false
		current_state = State.IN_COVER
		return

	print("Player: Stepping back in")

	# Set step in animation speed
	animation_player.speed_scale = step_in_speed

	# Calculate step in duration
	var step_in_duration = 0.15 / step_in_speed

	# Play step-in animation (blend back to center)
	animation_tree.set("parameters/step/blend_position", 0.0)

	# Wait for step in to complete
	await get_tree().create_timer(step_in_duration).timeout

	# Reset state
	animation_player.speed_scale = 1.0
	is_stepped_out = false
	current_state = State.IN_COVER
	print("Player: Step in complete")

## Get which direction a world position is relative to current cover
func get_relative_direction(world_pos: Vector3) -> String:
	if not current_cover:
		return "forward"

	var to_target = (world_pos - current_cover.global_position).normalized()

	# Determine if it's left, right, forward, or back
	var dot_right = to_target.dot(Vector3.RIGHT)
	var dot_forward = to_target.dot(Vector3.FORWARD)

	if abs(dot_right) > abs(dot_forward):
		return "right" if dot_right > 0 else "left"
	else:
		return "forward" if dot_forward > 0 else "back"

## Create debug visualization meshes
func _create_debug_visuals():
	# Create debug line mesh
	debug_line = MeshInstance3D.new()
	debug_line.name = "DebugLine"
	add_child(debug_line)

	# Create debug hit point sphere
	debug_hit_point = MeshInstance3D.new()
	debug_hit_point.name = "DebugHitPoint"
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.1
	sphere_mesh.height = 0.1
	debug_hit_point.mesh = sphere_mesh

	# Create material for hit point
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.8)  # Red with transparency
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_hit_point.material_override = mat

	add_child(debug_hit_point)
	debug_hit_point.visible = false

## Visualize shot from shoot origin to target position
func visualize_shot(target_pos: Vector3):
	if not shoot_origin or not debug_line or not debug_hit_point:
		return

	var start_pos = shoot_origin.global_position
	var direction = (target_pos - start_pos).normalized()
	var distance = start_pos.distance_to(target_pos)

	# Create line mesh using ImmediateMesh
	# Vertices need to be in local space of debug_line (child of Player)
	var immediate_mesh = ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# Convert world positions to local space of debug_line
	var local_start = debug_line.to_local(start_pos)
	var local_end = debug_line.to_local(target_pos)

	# Line from shoot origin to hit point
	immediate_mesh.surface_add_vertex(local_start)
	immediate_mesh.surface_add_vertex(local_end)

	immediate_mesh.surface_end()

	# Set the mesh
	debug_line.mesh = immediate_mesh

	# Create material for line
	var line_mat = StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0, 0.5, 1, 1)  # Blue
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_line.material_override = line_mat

	# Show hit point at target
	debug_hit_point.global_position = target_pos
	debug_hit_point.visible = true

	# Fade out after a short time
	await get_tree().create_timer(0.5).timeout
	if debug_hit_point:
		debug_hit_point.visible = false
	if debug_line and debug_line.mesh:
		debug_line.mesh = null
