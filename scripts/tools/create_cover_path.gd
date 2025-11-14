@tool
extends Node

## Tool for creating custom curve paths between cover points
##
## HOW TO USE:
## 1. Add this script as a child node in your scene
## 2. Configure the settings in the Inspector
## 3. Call create_path() from the debugger or add a button in editor
##
## OR simply:
## - Create a Path3D node as child of the FROM cover
## - Name it appropriately (e.g., "Path_Forward")
## - Assign it to the cover's path export variable (e.g., forward_path)
## - Edit the curve in the 3D editor

@export_group("Path Configuration")
@export var from_cover: CoverPoint  ## Starting cover point
@export var to_cover: CoverPoint  ## Destination cover point
@export_enum("left", "right", "forward", "back") var direction: String = "forward"

@export_group("Curve Settings")
@export var control_point_1_offset: Vector3 = Vector3(0, 3, -3)  ## First bezier control (from start)
@export var control_point_2_offset: Vector3 = Vector3(0, 3, 3)  ## Second bezier control (from end)
@export var create_on_ready: bool = false  ## Auto-create path when node enters tree

func _ready():
	if Engine.is_editor_hint() and create_on_ready:
		create_path()

## Create the custom path between covers
func create_path():
	if not from_cover or not to_cover:
		push_error("CoverPathCreator: Both from_cover and to_cover must be set!")
		return null

	if direction not in ["left", "right", "forward", "back"]:
		push_error("CoverPathCreator: Invalid direction. Must be: left, right, forward, or back")
		return null

	print("Creating custom path from ", from_cover.name, " to ", to_cover.name, " (direction: ", direction, ")")

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
	var cp1_world = start_world + control_point_1_offset
	var cp2_world = end_world + control_point_2_offset

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
