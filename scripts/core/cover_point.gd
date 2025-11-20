@tool
extends Node3D
class_name CoverPoint

## Cover point for player positioning and camera placement
## Supports left/right sides with individual camera anchors

enum CoverHeight { MEDIUM, TALL }

@export_group("Cover Properties")
@export var height: CoverHeight = CoverHeight.MEDIUM
@export_flags("Left:1", "Right:2") var active_sides: int = 3  # Both sides by default
@export var cover_name: String = ""  # For debugging

@export_group("Camera Settings")
@export var left_fov: float = 75.0  ## FOV for left camera anchor
@export var right_fov: float = 75.0  ## FOV for right camera anchor

@export_group("Movement Timing")
@export var camera_start_delay: float = 0  ## Delay before camera follows when LEAVING this cover (seconds). -1 = use game default (0.3s)
@export var camera_transition_duration: float = 0  ## Camera transition speed when LEAVING this cover. -1 = use camera default (0.5s)
@export var player_movement_duration: float = 0  ## Player movement speed when LEAVING this cover. -1 = use default (0.8s)
@export var transition_ease_type: Tween.EaseType = Tween.EASE_IN_OUT  ## Easing for transitions when leaving this cover
@export var force_linear_transition: bool = false  ## Force linear camera transition when leaving (ignore custom paths)

@export_group("Connections")
@export var left_cover: CoverPoint = null
@export var right_cover: CoverPoint = null
@export var forward_cover: CoverPoint = null
@export var back_cover: CoverPoint = null

@export_group("Camera Paths (Optional)")
@export var left_camera_path: Path3D = null  ## Camera curve path to left cover
@export var right_camera_path: Path3D = null  ## Camera curve path to right cover
@export var forward_camera_path: Path3D = null  ## Camera curve path to forward cover
@export var back_camera_path: Path3D = null  ## Camera curve path to back cover

@export_group("Player Paths (Optional)")
@export var left_player_path: Path3D = null  ## Player movement path to left cover
@export var right_player_path: Path3D = null  ## Player movement path to right cover
@export var forward_player_path: Path3D = null  ## Player movement path to forward cover
@export var back_player_path: Path3D = null  ## Player movement path to back cover

@export_group("Anchor Setup Options")
@export var create_player_left: bool = true  ## Create/update PlayerAnchor_Left
@export var create_player_right: bool = true  ## Create/update PlayerAnchor_Right
@export var create_camera_left: bool = true  ## Create/update CameraAnchor_Left
@export var create_camera_right: bool = true  ## Create/update CameraAnchor_Right
@export var create_debug_camera: bool = true  ## Create/update DebugCamera for editor preview

# Child nodes (set in _ready)
var player_anchor_left: Marker3D
var player_anchor_right: Marker3D
var camera_anchor_left: Marker3D
var camera_anchor_right: Marker3D

func _ready():
	if not Engine.is_editor_hint():
		_cache_child_nodes()

func _cache_child_nodes():
	player_anchor_left = get_node_or_null("PlayerAnchor_Left")
	player_anchor_right = get_node_or_null("PlayerAnchor_Right")
	camera_anchor_left = get_node_or_null("CameraAnchor_Left")
	camera_anchor_right = get_node_or_null("CameraAnchor_Right")

## EDITOR TOOL: Setup cover with auto-generated anchors
## Call this from the editor to automatically create selected anchor nodes
func setup_cover_anchors():
	if not Engine.is_editor_hint():
		return

	print("Setting up cover: ", name)

	# Define which anchors to process based on toggles
	var anchor_config = {
		"PlayerAnchor_Left": create_player_left,
		"PlayerAnchor_Right": create_player_right,
		"CameraAnchor_Left": create_camera_left,
		"CameraAnchor_Right": create_camera_right
	}

	var anchors = {}

	# Get or create only selected anchors
	for anchor_name in anchor_config.keys():
		if not anchor_config[anchor_name]:
			print("  Skipping: ", anchor_name, " (disabled)")
			continue

		var existing = get_node_or_null(anchor_name)
		if existing:
			anchors[anchor_name] = existing
			print("  Found existing: ", anchor_name)
		else:
			var new_anchor = Marker3D.new()
			new_anchor.name = anchor_name
			add_child(new_anchor)
			new_anchor.owner = get_tree().edited_scene_root
			anchors[anchor_name] = new_anchor
			print("  Created: ", anchor_name)

	# Position selected anchors based on cover height
	if anchors.size() > 0:
		_position_anchors_by_height(anchors)

	# Create debug camera if requested
	if create_debug_camera:
		_setup_debug_camera(anchors)

	if anchors.size() > 0 or create_debug_camera:
		print("✓ Cover setup complete!")
	else:
		print("⚠ No anchors or debug camera selected to create")

## Position anchors based on cover height preset
func _position_anchors_by_height(anchors: Dictionary):
	var side_offset: float = 1.0  # Distance from center (2 units apart total)

	# Player anchors: Ground-level markers only (y=0)
	# These are just position markers - height comes from animation
	var player_anchors_created = []
	if anchors.has("PlayerAnchor_Left"):
		anchors["PlayerAnchor_Left"].position = Vector3(-side_offset, 0, 0)
		player_anchors_created.append("Left")
	if anchors.has("PlayerAnchor_Right"):
		anchors["PlayerAnchor_Right"].position = Vector3(side_offset, 0, 0)
		player_anchors_created.append("Right")

	if player_anchors_created.size() > 0:
		print("  Player anchors (", ", ".join(player_anchors_created), ") at ground level (y=0)")
		print("  → Manually adjust positions as needed")
		print("  → Height controlled by animation (crouch/stand)")

	# Position camera anchors (at ground level, no rotation, 2 units apart)
	var camera_anchors_created = []
	if anchors.has("CameraAnchor_Left"):
		var cam_left = anchors["CameraAnchor_Left"]
		cam_left.position = Vector3(-side_offset, 0, 0)
		cam_left.rotation = Vector3.ZERO  # No rotation
		camera_anchors_created.append("Left")

	if anchors.has("CameraAnchor_Right"):
		var cam_right = anchors["CameraAnchor_Right"]
		cam_right.position = Vector3(side_offset, 0, 0)
		cam_right.rotation = Vector3.ZERO  # No rotation
		camera_anchors_created.append("Right")

	if camera_anchors_created.size() > 0:
		print("  Camera anchors (", ", ".join(camera_anchors_created), ") at y=0, no rotation")
		print("  → 2 units apart (±", side_offset, " from center)")

## Setup debug camera for editor preview
func _setup_debug_camera(anchors: Dictionary):
	# Check if DebugCamera already exists
	var debug_cam = get_node_or_null("DebugCamera")

	if debug_cam:
		print("  Found existing: DebugCamera")
	else:
		# Create new Camera3D
		debug_cam = Camera3D.new()
		debug_cam.name = "DebugCamera"

		# Load and attach the debug camera script
		var script_path = "res://scripts/core/cover_camera_debug.gd"
		var script = load(script_path)
		if script:
			debug_cam.set_script(script)
		else:
			push_warning("Could not load cover_camera_debug.gd script")

		add_child(debug_cam)
		debug_cam.owner = get_tree().edited_scene_root
		print("  Created: DebugCamera")

	# Position at left camera anchor if it exists, otherwise use calculated position
	if anchors.has("CameraAnchor_Left"):
		debug_cam.global_transform = anchors["CameraAnchor_Left"].global_transform
		print("  → Positioned at CameraAnchor_Left")
	elif anchors.has("CameraAnchor_Right"):
		debug_cam.global_transform = anchors["CameraAnchor_Right"].global_transform
		print("  → Positioned at CameraAnchor_Right")
	else:
		# Use default positioning (left side, y=0, no rotation)
		debug_cam.position = Vector3(-1.0, 0, 0)
		debug_cam.rotation = Vector3.ZERO
		print("  → Positioned at default location")

	# Set keep_aspect to width (same as in cover_point.tscn)
	debug_cam.keep_aspect = Camera3D.KEEP_WIDTH

## Check if left side is active
func has_left_side() -> bool:
	return (active_sides & 1) != 0

## Check if right side is active
func has_right_side() -> bool:
	return (active_sides & 2) != 0

## Get player anchor for specified side
func get_player_anchor(side: String) -> Marker3D:
	match side:
		"left": return player_anchor_left
		"right": return player_anchor_right
	return null

## Get camera anchor for specified side
func get_camera_anchor(side: String) -> Marker3D:
	match side:
		"left": return camera_anchor_left
		"right": return camera_anchor_right
	return null

## Get FOV for specified side
func get_fov(side: String) -> float:
	match side:
		"left": return left_fov
		"right": return right_fov
	return 75.0  # Default fallback

## Get animation ID for this cover configuration
func get_animation_id(side: String) -> String:
	var height_str = "Medium" if height == CoverHeight.MEDIUM else "Tall"
	var side_str = side.capitalize()
	return height_str + "_" + side_str

## Get connection in specified direction
func get_connection(direction: String) -> CoverPoint:
	match direction:
		"left": return left_cover
		"right": return right_cover
		"forward": return forward_cover
		"back": return back_cover
	return null

## Get custom camera path in specified direction (optional)
func get_camera_path(direction: String) -> Path3D:
	match direction:
		"left": return left_camera_path
		"right": return right_camera_path
		"forward": return forward_camera_path
		"back": return back_camera_path
	return null

## Get custom player path in specified direction (optional)
func get_player_path(direction: String) -> Path3D:
	match direction:
		"left": return left_player_path
		"right": return right_player_path
		"forward": return forward_player_path
		"back": return back_player_path
	return null

## DEPRECATED: Use get_camera_path() or get_player_path() instead
func get_custom_path(direction: String) -> Path3D:
	push_warning("get_custom_path() is deprecated. Use get_camera_path() or get_player_path() instead.")
	return get_camera_path(direction)

## Debug info
func get_display_name() -> String:
	if cover_name != "":
		return cover_name
	var height_str = "Med" if height == CoverHeight.MEDIUM else "Tall"
	var sides = []
	if has_left_side(): sides.append("L")
	if has_right_side(): sides.append("R")
	return height_str + "[" + ",".join(sides) + "]"
