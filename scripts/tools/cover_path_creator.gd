@tool
extends EditorScript

## Editor tool to create custom curve paths between cover points
## Usage:
## 1. Select this script in the FileSystem
## 2. Go to File > Run
## 3. Configure the exported variables below
## 4. The script will create a Path3D with a Curve3D between the two covers

@export var from_cover: CoverPoint  ## Starting cover point
@export var to_cover: CoverPoint  ## Destination cover point
@export var direction: String = "forward"  ## Direction: left, right, forward, back
@export var control_point_1_offset: Vector3 = Vector3(0, 2, -2)  ## First bezier control offset from start
@export var control_point_2_offset: Vector3 = Vector3(0, 2, 2)  ## Second bezier control offset from end
@export var num_points: int = 20  ## Number of intermediate points to calculate

func _run():
	if not from_cover or not to_cover:
		print("ERROR: Both from_cover and to_cover must be set!")
		return

	if direction not in ["left", "right", "forward", "back"]:
		print("ERROR: Direction must be one of: left, right, forward, back")
		return

	# Create the path
	create_custom_path(from_cover, to_cover, direction)
	print("✓ Custom path created from ", from_cover.name, " to ", to_cover.name, " (direction: ", direction, ")")

func create_custom_path(from: CoverPoint, to: CoverPoint, dir: String):
	# Get or create Path3D node
	var path_node: Path3D = null
	var path_name = "Path_" + dir.capitalize()

	# Check if path already exists as child of from_cover
	path_node = from.get_node_or_null(path_name)

	if path_node:
		print("Found existing path node: ", path_name, " - updating it")
	else:
		print("Creating new path node: ", path_name)
		path_node = Path3D.new()
		path_node.name = path_name
		from.add_child(path_node)
		path_node.owner = get_scene().get_tree().get_edited_scene_root()

	# Create or get curve
	var curve = Curve3D.new() if not path_node.curve else path_node.curve
	curve.clear_points()

	# Start and end positions (in world space)
	var start_pos = from.global_position
	var end_pos = to.global_position

	# Convert to local space of path_node (which is child of from_cover)
	var local_start = path_node.to_local(start_pos)
	var local_end = path_node.to_local(end_pos)

	# Control points for bezier curve (offsets in world space, then converted to local)
	var control_1 = path_node.to_local(start_pos + control_point_1_offset)
	var control_2 = path_node.to_local(end_pos + control_point_2_offset)

	# Add start point with out-control
	curve.add_point(local_start, Vector3.ZERO, control_1 - local_start)

	# Add end point with in-control
	curve.add_point(local_end, control_2 - local_end, Vector3.ZERO)

	# Assign curve to path
	path_node.curve = curve

	# Set the path reference on the from_cover
	match dir:
		"left": from.left_path = path_node
		"right": from.right_path = path_node
		"forward": from.forward_path = path_node
		"back": from.back_path = path_node

	print("  Start: ", local_start)
	print("  End: ", local_end)
	print("  Control 1 offset: ", control_1 - local_start)
	print("  Control 2 offset: ", control_2 - local_end)
	print("  Path node: ", path_node.get_path())
