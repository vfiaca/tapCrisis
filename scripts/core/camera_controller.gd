extends Camera3D
class_name CameraController

## Main game camera - handles input, shooting, and cover transitions

@export_group("Starting Position")
@export var start_anchor: Marker3D = null  ## Optional: Set camera to this anchor's transform at start

# Default transition settings (used when cover doesn't specify)
const DEFAULT_TRANSITION_DURATION: float = 0.5
const DEFAULT_TRANSITION_EASE: Tween.EaseType = Tween.EASE_IN_OUT
const DEFAULT_TRANSITION_TRANS: Tween.TransitionType = Tween.TRANS_CUBIC

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

	# Use CoverPoint's settings, or fall back to camera defaults (>= 0 means user set explicit value, -1 means use default)
	var duration = cover.camera_transition_duration if cover.camera_transition_duration >= 0 else DEFAULT_TRANSITION_DURATION
	var ease_type = cover.transition_ease_type if cover.transition_ease_type else DEFAULT_TRANSITION_EASE

	print("Camera transition - Cover: ", cover.name)
	print("  Duration: ", duration, " (cover setting: ", cover.camera_transition_duration, ", default: ", DEFAULT_TRANSITION_DURATION, ")")
	print("  Ease type: ", ease_type)
	print("  Force linear: ", cover.force_linear_transition)

	# Cancel existing tween
	if active_tween and active_tween.is_running():
		active_tween.kill()

	# Check if we should use path or linear transition
	# Force linear if cover.force_linear_transition is true, OR if no valid path provided
	var use_path = not cover.force_linear_transition and custom_path and custom_path.curve and custom_path.curve.point_count >= 2

	if use_path:
		_follow_path(custom_path, target_position, target_rotation, target_fov, duration, ease_type)
	else:
		# Linear interpolation (either forced or no path available)
		_linear_transition(target_position, target_rotation, target_fov, duration, ease_type)

## Follow a Path3D curve to the destination
func _follow_path(path: Path3D, target_position: Vector3, target_rotation: Vector3, target_fov: float, duration: float = -1, ease: Tween.EaseType = -1):
	var curve = path.curve
	var curve_length = curve.get_baked_length()

	# Use provided duration or fall back to default (>= 0 means explicit value, -1 means use default)
	var tween_duration = duration if duration >= 0 else DEFAULT_TRANSITION_DURATION
	var tween_ease = ease if ease >= 0 else DEFAULT_TRANSITION_EASE

	if curve_length <= 0:
		push_warning("Path curve has zero length, falling back to linear transition")
		_linear_transition(target_position, target_rotation, target_fov, duration, ease)
		return

	print("Following custom path: ", path.name, " (length: ", curve_length, ", duration: ", tween_duration, "s)")

	# Convert rotations to quaternions for smooth interpolation
	var start_quat = Quaternion(global_transform.basis)
	var target_quat = Quaternion(Basis.from_euler(target_rotation))

	# Create tween for path following
	active_tween = create_tween()
	active_tween.set_ease(tween_ease)
	active_tween.set_trans(DEFAULT_TRANSITION_TRANS)

	# Position follows curve, rotation interpolates via quaternion
	active_tween.tween_method(
		func(t: float):
			# Sample position from curve
			var sampled_pos = curve.sample_baked(t * curve_length)
			# Convert from path's local space to world space
			global_position = path.to_global(sampled_pos)

			# Interpolate rotation using quaternion slerp (prevents 360 spin)
			var interpolated_quat = start_quat.slerp(target_quat, t)
			global_transform.basis = Basis(interpolated_quat),
		0.0,
		1.0,
		tween_duration
	)

	# FOV tweens separately in parallel
	active_tween.parallel().tween_property(self, "fov", target_fov, tween_duration)

## Linear transition (no path)
func _linear_transition(target_position: Vector3, target_rotation: Vector3, target_fov: float, duration: float = -1, ease: Tween.EaseType = -1):
	# Use provided duration or fall back to default (>= 0 means explicit value, -1 means use default)
	var tween_duration = duration if duration >= 0 else DEFAULT_TRANSITION_DURATION
	var tween_ease = ease if ease >= 0 else DEFAULT_TRANSITION_EASE

	# Cache starting values
	var start_position = global_position
	var start_quat = Quaternion(global_transform.basis)
	var target_quat = Quaternion(Basis.from_euler(target_rotation))

	active_tween = create_tween()
	active_tween.set_ease(tween_ease)
	active_tween.set_trans(DEFAULT_TRANSITION_TRANS)

	# Tween position and rotation together using quaternions
	active_tween.tween_method(
		func(t: float):
			# Interpolate position from start to target
			global_position = start_position.lerp(target_position, t)
			# Interpolate rotation using quaternion slerp (prevents 360 spin)
			var interpolated_quat = start_quat.slerp(target_quat, t)
			global_transform.basis = Basis(interpolated_quat),
		0.0,
		1.0,
		tween_duration
	)

	# FOV tweens in parallel
	active_tween.parallel().tween_property(self, "fov", target_fov, tween_duration)

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
