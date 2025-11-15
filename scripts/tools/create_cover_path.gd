@tool
extends Node

## Tool for creating custom curve paths between cover points
##
## RECOMMENDED WORKFLOW (use the Editor Plugin instead):
## 1. Enable "Cover Path Tools" plugin in Project Settings → Plugins
## 2. Select a CoverPoint node
## 3. Use the "Path Creation Tools" buttons in the Inspector
##
## ALTERNATIVE - Manual Tool Script:
## 1. Add this script as a child node in your scene
## 2. Configure from_cover, to_cover, and direction
## 3. Click "Create Path" button in Inspector (appears in editor)
## 4. Adjust curve settings if needed
## 5. Click "Create Path" again to update
##
## OR FULLY MANUAL:
## - Create a Path3D node as child of the FROM cover
## - Name it appropriately (e.g., "Path_Forward")
## - Assign it to the cover's path export variable
## - Edit the curve in the 3D editor

@export_group("Path Configuration")
@export var from_cover: CoverPoint  ## Starting cover point
@export var to_cover: CoverPoint  ## Destination cover point
@export_enum("left", "right", "forward", "back") var direction: String = "forward"

@export_group("Curve Settings")
@export var control_point_1_offset: Vector3 = Vector3(0, 3, -3)  ## First bezier control (from start)
@export var control_point_2_offset: Vector3 = Vector3(0, 3, 3)  ## Second bezier control (from end)

@export_group("Advanced")
@export var auto_calculate_offsets: bool = true  ## Calculate offsets based on distance
@export var path_style: PathStyle = PathStyle.GENTLE_ARC  ## Predefined path styles
@export var create_on_ready: bool = false  ## DEPRECATED: Use editor plugin instead

enum PathStyle {
	GENTLE_ARC,       ## Gentle overhead arc (default)
	LOW_TACTICAL,     ## Stay low and close
	DRAMATIC_SWEEP,   ## High cinematic sweep
	CUSTOM            ## Use manual control_point offsets
}

func _ready():
	if Engine.is_editor_hint() and create_on_ready:
		push_warning("create_on_ready is deprecated. Use the Cover Path Tools plugin or click 'Create Path' button instead.")
		create_path()

## Get property list for editor buttons
func _get_property_list():
	var properties = []

	# Add button to create/update path in editor
	if Engine.is_editor_hint():
		properties.append({
			"name": "create_or_update_path",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "Create Path"
		})

	return properties

## Handle property changes (button clicks)
func _set(property: StringName, value) -> bool:
	if property == "create_or_update_path" and value:
		create_path()
		return true
	return false

## Create the custom path between covers
func create_path():
	if not from_cover or not to_cover:
		push_error("CoverPathCreator: Both from_cover and to_cover must be set!")
		return null

	if direction not in ["left", "right", "forward", "back"]:
		push_error("CoverPathCreator: Invalid direction. Must be: left, right, forward, or back")
		return null

	print("Creating custom path from ", from_cover.name, " to ", to_cover.name, " (direction: ", direction, ")")

	# Calculate offsets based on style
	var final_cp1_offset = control_point_1_offset
	var final_cp2_offset = control_point_2_offset

	if auto_calculate_offsets and path_style != PathStyle.CUSTOM:
		var offsets = _calculate_style_offsets()
		final_cp1_offset = offsets[0]
		final_cp2_offset = offsets[1]
		print("  Using ", PathStyle.keys()[path_style], " style offsets")

	# Get or create Path3D node
	var path_name = "Path_" + direction.capitalize()
	var path_node: Path3D = from_cover.get_node_or_null(path_name)

	if path_node:
		print("  Found existing path: ", path_name, " - updating curve")
	else:
		print("  Creating new path: ", path_name)
		path_node = Path3D.new()
		path_node.name = path_name
		from_cover.add_child(path_node)

		# Set owner for scene saving
		if Engine.is_editor_hint():
			path_node.owner = get_tree().edited_scene_root

	# Create curve
	var curve = Curve3D.new()

	# Calculate positions (world space → local to path_node)
	var start_world = from_cover.global_position
	var end_world = to_cover.global_position

	var start_local = path_node.to_local(start_world)
	var end_local = path_node.to_local(end_world)

	# Control points (offsets are in world space)
	var cp1_world = start_world + final_cp1_offset
	var cp2_world = end_world + final_cp2_offset

	var cp1_local = path_node.to_local(cp1_world)
	var cp2_local = path_node.to_local(cp2_world)

	# Add curve points
	# First point: start position, with out-control towards cp1
	curve.add_point(start_local, Vector3.ZERO, cp1_local - start_local)

	# Second point: end position, with in-control from cp2
	curve.add_point(end_local, cp2_local - end_local, Vector3.ZERO)

	# Assign curve
	path_node.curve = curve

	# Link path to cover
	match direction:
		"left": from_cover.left_path = path_node
		"right": from_cover.right_path = path_node
		"forward": from_cover.forward_path = path_node
		"back": from_cover.back_path = path_node

	print("✓ Path created successfully!")
	print("  Start (local): ", start_local)
	print("  End (local): ", end_local)
	print("  Curve length: ", curve.get_baked_length())

	return path_node

## Calculate control point offsets based on path style
func _calculate_style_offsets() -> Array:
	var distance = from_cover.global_position.distance_to(to_cover.global_position)

	var cp1: Vector3
	var cp2: Vector3

	match path_style:
		PathStyle.GENTLE_ARC:
			# Gentle overhead arc
			var height = min(distance * 0.3, 3.0)
			var depth = distance * 0.2
			cp1 = Vector3(0, height, -depth)
			cp2 = Vector3(0, height, depth)

		PathStyle.LOW_TACTICAL:
			# Stay low and close
			var height = 0.5
			var depth = distance * 0.15
			cp1 = Vector3(0, height, -depth)
			cp2 = Vector3(0, height, depth)

		PathStyle.DRAMATIC_SWEEP:
			# High cinematic sweep
			var height = min(distance * 0.5, 6.0)
			var depth = distance * 0.3
			var side = distance * 0.2
			cp1 = Vector3(-side, height, -depth)
			cp2 = Vector3(side, height, depth)

		PathStyle.CUSTOM:
			# Use manual offsets
			cp1 = control_point_1_offset
			cp2 = control_point_2_offset

	return [cp1, cp2]
