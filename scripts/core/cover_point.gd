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

@export_group("Connections")
@export var left_cover: CoverPoint = null
@export var right_cover: CoverPoint = null
@export var forward_cover: CoverPoint = null
@export var back_cover: CoverPoint = null

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

## Debug info
func get_display_name() -> String:
	if cover_name != "":
		return cover_name
	var height_str = "Med" if height == CoverHeight.MEDIUM else "Tall"
	var sides = []
	if has_left_side(): sides.append("L")
	if has_right_side(): sides.append("R")
	return height_str + "[" + ",".join(sides) + "]"
