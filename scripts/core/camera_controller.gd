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

## Transition camera to new cover position
func transition_to_cover(cover: CoverPoint, side: String):
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

	# Cancel existing tween
	if active_tween and active_tween.is_running():
		active_tween.kill()

	# Camera starts moving immediately (no wait)
	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.set_ease(transition_ease)
	active_tween.set_trans(transition_trans)

	active_tween.tween_property(self, "global_position",
		target_position, transition_duration)
	active_tween.tween_property(self, "global_rotation",
		target_rotation, transition_duration)
	active_tween.tween_property(self, "fov",
		target_fov, transition_duration)

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
