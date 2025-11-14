@tool
extends EditorPlugin

## Editor plugin for creating custom curve paths between cover points

var dock: Control

func _enter_tree():
	# Load the dock scene
	dock = preload("res://addons/cover_path_tool/cover_path_dock.tscn").instantiate()

	# Connect signals
	dock.get_node("VBoxContainer/CreatePathButton").pressed.connect(_on_create_path_pressed)

	# Add the dock to the editor
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)

func _exit_tree():
	# Clean up
	remove_control_from_docks(dock)
	if dock:
		dock.queue_free()

func _on_create_path_pressed():
	var from_cover: CoverPoint = dock.get_node("VBoxContainer/FromCover").get_selected_node()
	var to_cover: CoverPoint = dock.get_node("VBoxContainer/ToCover").get_selected_node()
	var direction: String = dock.get_node("VBoxContainer/Direction").text
	var cp1_offset: Vector3 = dock.get_node("VBoxContainer/ControlPoint1").get_vector()
	var cp2_offset: Vector3 = dock.get_node("VBoxContainer/ControlPoint2").get_vector()

	if not from_cover or not to_cover:
		push_error("Please select both From and To cover points")
		return

	if direction not in ["left", "right", "forward", "back"]:
		push_error("Direction must be: left, right, forward, or back")
		return

	# Create the path
	create_custom_path(from_cover, to_cover, direction, cp1_offset, cp2_offset)

func create_custom_path(from: CoverPoint, to: CoverPoint, dir: String, cp1_offset: Vector3, cp2_offset: Vector3):
	var undo_redo = get_undo_redo()

	# Get or create Path3D node
	var path_node: Path3D = null
	var path_name = "Path_" + dir.capitalize()

	# Check if path already exists
	path_node = from.get_node_or_null(path_name)

	if not path_node:
		path_node = Path3D.new()
		path_node.name = path_name

		undo_redo.create_action("Create Custom Path")
		undo_redo.add_do_method(from, "add_child", path_node, true)
		undo_redo.add_do_property(path_node, "owner", get_editor_interface().get_edited_scene_root())
		undo_redo.add_undo_method(from, "remove_child", path_node)
		undo_redo.commit_action()

	# Create curve
	var curve = Curve3D.new()

	# Calculate positions
	var start_pos = from.global_position
	var end_pos = to.global_position
	var local_start = path_node.to_local(start_pos)
	var local_end = path_node.to_local(end_pos)
	var control_1 = path_node.to_local(start_pos + cp1_offset)
	var control_2 = path_node.to_local(end_pos + cp2_offset)

	# Add points
	curve.add_point(local_start, Vector3.ZERO, control_1 - local_start)
	curve.add_point(local_end, control_2 - local_end, Vector3.ZERO)

	# Apply curve
	undo_redo.create_action("Set Path Curve")
	undo_redo.add_do_property(path_node, "curve", curve)
	undo_redo.add_undo_property(path_node, "curve", path_node.curve)
	undo_redo.commit_action()

	# Set reference on cover
	undo_redo.create_action("Link Path to Cover")
	match dir:
		"left":
			undo_redo.add_do_property(from, "left_path", path_node)
			undo_redo.add_undo_property(from, "left_path", from.left_path)
		"right":
			undo_redo.add_do_property(from, "right_path", path_node)
			undo_redo.add_undo_property(from, "right_path", from.right_path)
		"forward":
			undo_redo.add_do_property(from, "forward_path", path_node)
			undo_redo.add_undo_property(from, "forward_path", from.forward_path)
		"back":
			undo_redo.add_do_property(from, "back_path", path_node)
			undo_redo.add_undo_property(from, "back_path", from.back_path)
	undo_redo.commit_action()

	print("✓ Created custom path from ", from.name, " to ", to.name, " (", dir, ")")
