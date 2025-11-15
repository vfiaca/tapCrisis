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
@export var camera_transition_duration: float = 1.5  ## Duration of camera movement to this cover
@export var player_movement_duration: float = 0.8  ## Duration of player movement to this cover
@export var transition_ease_type: Tween.EaseType = Tween.EASE_IN_OUT  ## Easing for transitions

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
## Call this from the editor to automatically create all anchor nodes
func setup_cover_anchors():
	if not Engine.is_editor_hint():
		return

	print("Setting up cover: ", name)

	# Get or create anchors
	var anchors = {
		"PlayerAnchor_Left": null,
		"PlayerAnchor_Right": null,
		"CameraAnchor_Left": null,
		"CameraAnchor_Right": null
	}

	for anchor_name in anchors.keys():
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

	# Position anchors based on cover height
	_position_anchors_by_height(anchors)

	print("✓ Cover setup complete!")

## Position anchors based on cover height preset
func _position_anchors_by_height(anchors: Dictionary):
	var camera_height: float
	var camera_distance: float
	var side_offset: float = 0.5  # Distance from center

	# Set camera positioning based on cover type
	# Player height is handled by animations (crouch for MEDIUM, stand for TALL)
	match height:
		CoverHeight.MEDIUM:
			camera_height = 1.2  # Camera slightly above cover
			camera_distance = 0.8  # Camera pulls back slightly
		CoverHeight.TALL:
			camera_height = 1.6  # Camera at head height
			camera_distance = 1.0  # Camera pulls back more

	# Player anchors: Ground-level markers only (y=0)
	# These are just position markers - height comes from animation
	if anchors.has("PlayerAnchor_Left"):
		anchors["PlayerAnchor_Left"].position = Vector3(-side_offset, 0, 0)
	if anchors.has("PlayerAnchor_Right"):
		anchors["PlayerAnchor_Right"].position = Vector3(side_offset, 0, 0)

	print("  Note: Player anchors created at ground level (y=0)")
	print("  → Manually adjust their positions as needed")
	print("  → Player height controlled by animation (crouch/stand)")

	# Position camera anchors (left/right, slightly back and up)
	if anchors.has("CameraAnchor_Left"):
		var cam_left = anchors["CameraAnchor_Left"]
		cam_left.position = Vector3(-side_offset, camera_height, -camera_distance)
		# Rotate to look forward and slightly down
		cam_left.rotation_degrees = Vector3(-10, 0, 0)

	if anchors.has("CameraAnchor_Right"):
		var cam_right = anchors["CameraAnchor_Right"]
		cam_right.position = Vector3(side_offset, camera_height, -camera_distance)
		# Rotate to look forward and slightly down
		cam_right.rotation_degrees = Vector3(-10, 0, 0)

	print("  Positioned camera anchors for ", CoverHeight.keys()[height], " cover")
	print("    Camera height: ", camera_height)

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
