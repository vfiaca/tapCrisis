extends Camera3D
class_name CameraController

## Main game camera - handles input, shooting, and cover transitions

@export_group("Starting Position")
@export var start_anchor: Marker3D = null  ## Optional: Set camera to this anchor's transform at start

@export_group("Transition Settings")
@export var transition_lead_time: float = 0.3  ## Time before camera starts moving (seconds)
@export var transition_duration: float = 0.5   ## How long camera takes to reach new position
@export var transition_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var transition_trans: Tween.TransitionType = Tween.TRANS_CUBIC

# References
var player: Node3D = null
var current_cover: CoverPoint = null
var current_side: String = "left"

# Camera positioning
var target_position_cache: Vector3 = Vector3.ZERO

# Tween for smooth transitions
var active_tween: Tween = null

func _ready():
	# Make this the current camera
	make_current()

	# Set to starting anchor if provided
	if start_anchor:
		global_transform = start_anchor.global_transform
		print("Camera initialized at start anchor: ", start_anchor.name)

## Set the player reference
func set_player(p: Node3D):
	player = p

## Transition camera to new cover position (optionally following a custom path)
func transition_to_cover(cover: CoverPoint, side: String, custom_path: Path3D = null):
	if not cover:
		return

	current_cover = cover
	current_side = side

	# Get camera anchor for this side
	var cam_anchor = cover.get_camera_anchor(side)

	if not cam_anchor:
		push_warning("Cover missing camera anchor for side: " + side)
		return

	# Cache target position and rotation
	var target_position = cam_anchor.global_position
	var target_rotation = cam_anchor.global_rotation
	var target_fov = cover.get_fov(side)

	# Use CoverPoint's camera transition duration (overrides default)
	var duration = cover.camera_transition_duration if cover.camera_transition_duration > 0 else transition_duration
	var ease_type = cover.transition_ease_type if cover.transition_ease_type else transition_ease

	# Cancel existing tween
	if active_tween and active_tween.is_running():
		active_tween.kill()

	# If custom path is provided and has a valid curve, follow it
	if custom_path and custom_path.curve and custom_path.curve.point_count >= 2:
		_follow_path(custom_path, target_position, target_rotation, target_fov, duration, ease_type)
	else:
		# Default: linear interpolation
		_linear_transition(target_position, target_rotation, target_fov, duration, ease_type)

## Follow a Path3D curve to the destination
func _follow_path(path: Path3D, target_position: Vector3, target_rotation: Vector3, target_fov: float, duration: float = -1, ease: Tween.EaseType = -1):
	var curve = path.curve
	var curve_length = curve.get_baked_length()

	# Use provided duration or fall back to default
	var tween_duration = duration if duration > 0 else transition_duration
	var tween_ease = ease if ease >= 0 else transition_ease

	if curve_length <= 0:
		push_warning("Path curve has zero length, falling back to linear transition")
		_linear_transition(target_position, target_rotation, target_fov, duration, ease)
		return

	print("Following custom path: ", path.name, " (length: ", curve_length, ", duration: ", tween_duration, "s)")

	# Create tween for path following
	active_tween = create_tween()
	active_tween.set_ease(tween_ease)
	active_tween.set_trans(transition_trans)

	# Position follows curve
	active_tween.tween_method(
		func(t: float):
			# Sample position from curve
			var sampled_pos = curve.sample_baked(t * curve_length)
			# Convert from path's local space to world space
			global_position = path.to_global(sampled_pos)

			# Interpolate rotation separately (not from curve)
			global_rotation = global_rotation.lerp(target_rotation, t),
		0.0,
		1.0,
		tween_duration
	)

	# FOV tweens separately in parallel
	active_tween.parallel().tween_property(self, "fov", target_fov, tween_duration)

## Linear transition (no path)
func _linear_transition(target_position: Vector3, target_rotation: Vector3, target_fov: float, duration: float = -1, ease: Tween.EaseType = -1):
	# Use provided duration or fall back to default
	var tween_duration = duration if duration > 0 else transition_duration
	var tween_ease = ease if ease >= 0 else transition_ease

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.set_ease(tween_ease)
	active_tween.set_trans(transition_trans)

	active_tween.tween_property(self, "global_position",
		target_position, tween_duration)
	active_tween.tween_property(self, "global_rotation",
		target_rotation, tween_duration)
	active_tween.tween_property(self, "fov",
		target_fov, tween_duration)

## Handle tap/click - raycast from screen position
func handle_tap(screen_pos: Vector2) -> Dictionary:
	var from = project_ray_origin(screen_pos)
	var to = from + project_ray_normal(screen_pos) * 1000.0

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)

	return {
		"hit": result.size() > 0,
		"position": result.get("position", to),
		"normal": result.get("normal", Vector3.UP),
		"collider": result.get("collider", null)
	}

## Get direction from camera to screen position (for aiming)
func get_aim_direction(screen_pos: Vector2) -> Vector3:
	var from = project_ray_origin(screen_pos)
	var direction = project_ray_normal(screen_pos)
	return direction.normalized()
