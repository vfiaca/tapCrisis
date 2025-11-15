@tool
extends EditorPlugin

## Simple path creation tool for Tap Crisis
## Creates Path3D nodes between any two selected nodes

var dock_panel: Control

func _enter_tree():
	# Create and add bottom panel
	dock_panel = PathCreatorPanel.new(get_editor_interface())
	add_control_to_bottom_panel(dock_panel, "Path Creator")
	print("Path Creator plugin enabled")

func _exit_tree():
	# Clean up
	if dock_panel:
		remove_control_from_bottom_panel(dock_panel)
		dock_panel.queue_free()
	print("Path Creator plugin disabled")

## Main control panel for path creation
class PathCreatorPanel extends VBoxContainer:
	var editor_interface: EditorInterface

	# UI Elements
	var origin_field: LineEdit
	var origin_node: Node3D = null
	var destination_field: LineEdit
	var destination_node: Node3D = null
	var direction_option: OptionButton
	var type_option: OptionButton
	var create_button: Button
	var status_label: Label

	# Cover point reference
	var current_cover: CoverPoint = null

	func _init(editor: EditorInterface):
		editor_interface = editor
		custom_minimum_size = Vector2(0, 250)
		_build_ui()

		# Connect to selection changes
		editor_interface.get_selection().selection_changed.connect(_on_selection_changed)

	func _on_selection_changed():
		# Check if a CoverPoint is selected
		var selected = editor_interface.get_selection().get_selected_nodes()
		if selected.size() > 0 and selected[0] is CoverPoint:
			current_cover = selected[0]
			_update_status("Selected cover: " + current_cover.name, Color.CYAN)

	func _build_ui():
		# Title
		var title = Label.new()
		title.text = "Path Creator"
		title.add_theme_font_size_override("font_size", 14)
		add_child(title)

		add_child(HSeparator.new())

		# Cover setup section
		var setup_label = Label.new()
		setup_label.text = "Cover Setup:"
		setup_label.add_theme_font_size_override("font_size", 12)
		add_child(setup_label)

		var setup_btn = Button.new()
		setup_btn.text = "🔧 Setup Cover Anchors"
		setup_btn.pressed.connect(_on_setup_anchors)
		add_child(setup_btn)

		var setup_info = Label.new()
		setup_info.text = "Creates/positions all player & camera anchors"
		setup_info.add_theme_font_size_override("font_size", 9)
		setup_info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		add_child(setup_info)

		add_child(HSeparator.new())

		# Origin Node
		var origin_label = Label.new()
		origin_label.text = "Origin Node:"
		add_child(origin_label)

		var origin_container = HBoxContainer.new()

		origin_field = LineEdit.new()
		origin_field.placeholder_text = "Drag node here or click Pick"
		origin_field.editable = false
		origin_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		origin_container.add_child(origin_field)

		var origin_pick_btn = Button.new()
		origin_pick_btn.text = "Pick"
		origin_pick_btn.pressed.connect(_on_pick_origin)
		origin_container.add_child(origin_pick_btn)

		var origin_clear_btn = Button.new()
		origin_clear_btn.text = "X"
		origin_clear_btn.pressed.connect(_on_clear_origin)
		origin_container.add_child(origin_clear_btn)

		add_child(origin_container)

		# Destination Node
		var dest_label = Label.new()
		dest_label.text = "Destination Node:"
		add_child(dest_label)

		var dest_container = HBoxContainer.new()

		destination_field = LineEdit.new()
		destination_field.placeholder_text = "Drag node here or click Pick"
		destination_field.editable = false
		destination_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dest_container.add_child(destination_field)

		var dest_pick_btn = Button.new()
		dest_pick_btn.text = "Pick"
		dest_pick_btn.pressed.connect(_on_pick_destination)
		dest_container.add_child(dest_pick_btn)

		var dest_clear_btn = Button.new()
		dest_clear_btn.text = "X"
		dest_clear_btn.pressed.connect(_on_clear_destination)
		dest_container.add_child(dest_clear_btn)

		add_child(dest_container)

		add_child(HSeparator.new())

		# Direction and Type in a grid
		var options_grid = GridContainer.new()
		options_grid.columns = 2

		# Direction
		var dir_label = Label.new()
		dir_label.text = "Direction:"
		options_grid.add_child(dir_label)

		direction_option = OptionButton.new()
		direction_option.add_item("Left", 0)
		direction_option.add_item("Right", 1)
		direction_option.add_item("Forward", 2)
		direction_option.add_item("Back", 3)
		direction_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options_grid.add_child(direction_option)

		# Type
		var type_label = Label.new()
		type_label.text = "Type:"
		options_grid.add_child(type_label)

		type_option = OptionButton.new()
		type_option.add_item("Camera", 0)
		type_option.add_item("Player", 1)
		type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options_grid.add_child(type_option)

		add_child(options_grid)

		add_child(HSeparator.new())

		# Create button
		create_button = Button.new()
		create_button.text = "Create Path"
		create_button.custom_minimum_size = Vector2(0, 32)
		create_button.pressed.connect(_on_create_path)
		add_child(create_button)

		# Status label
		status_label = Label.new()
		status_label.text = "Select node in scene tree, then click Pick button"
		status_label.add_theme_font_size_override("font_size", 9)
		status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		add_child(status_label)

		# Instructions
		add_child(HSeparator.new())
		var instructions = Label.new()
		instructions.text = "💡 Workflow: Select CoverPoint → Setup Anchors → Pick Origin → Pick Destination → Create Path"
		instructions.add_theme_font_size_override("font_size", 9)
		instructions.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
		instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(instructions)

	func _on_setup_anchors():
		if not current_cover:
			_update_status("Please select a CoverPoint first", Color.ORANGE)
			return

		print("=== Setting up cover: ", current_cover.name, " ===")
		current_cover.setup_cover_anchors()

		# Refresh the inspector to show new child nodes
		editor_interface.get_inspector().refresh()

		_update_status("Cover anchors created successfully!", Color.GREEN)
		print("=== Setup complete! You can now create paths. ===")

	func _on_pick_origin():
		var selection = editor_interface.get_selection().get_selected_nodes()
		if selection.size() > 0:
			var node = selection[0]
			if node is Node3D:
				origin_node = node
				origin_field.text = node.name + " (" + node.get_class() + ")"
				_update_status("Origin set: " + node.name, Color.GREEN)
			else:
				_update_status("Selected node must be Node3D", Color.ORANGE)
		else:
			_update_status("Please select a node in the scene tree first", Color.ORANGE)

	func _on_pick_destination():
		var selection = editor_interface.get_selection().get_selected_nodes()
		if selection.size() > 0:
			var node = selection[0]
			if node is Node3D:
				destination_node = node
				destination_field.text = node.name + " (" + node.get_class() + ")"
				_update_status("Destination set: " + node.name, Color.GREEN)
			else:
				_update_status("Selected node must be Node3D", Color.ORANGE)
		else:
			_update_status("Please select a node in the scene tree first", Color.ORANGE)

	func _on_clear_origin():
		origin_node = null
		origin_field.text = ""
		_update_status("Origin cleared", Color.GRAY)

	func _on_clear_destination():
		destination_node = null
		destination_field.text = ""
		_update_status("Destination cleared", Color.GRAY)

	func _on_create_path():
		# Validate inputs
		if not origin_node:
			_update_status("Error: Origin node not set", Color.RED)
			return

		if not destination_node:
			_update_status("Error: Destination node not set", Color.RED)
			return

		# Get scene root
		var scene_root = editor_interface.get_edited_scene_root()
		if not scene_root:
			_update_status("Error: No scene is currently open", Color.RED)
			return

		# Get direction and type
		var direction_names = ["Left", "Right", "Forward", "Back"]
		var direction = direction_names[direction_option.selected]

		var type_names = ["Camera", "Player"]
		var path_type = type_names[type_option.selected]

		# Create path name
		var path_name = "Path_" + direction + "_" + path_type

		# Check if path already exists as child of origin
		var existing_path = origin_node.get_node_or_null(path_name)
		if existing_path:
			_update_status("Warning: Path already exists. Delete it first: " + path_name, Color.ORANGE)
			# Select it for user to see/delete
			editor_interface.get_selection().clear()
			editor_interface.get_selection().add_node(existing_path)
			return

		# Create the Path3D node
		var path_node = Path3D.new()
		path_node.name = path_name

		# Add as child of origin node
		origin_node.add_child(path_node)
		path_node.owner = scene_root

		# Create curve
		var curve = Curve3D.new()

		# Calculate positions in path's local space
		var start_pos = path_node.to_local(origin_node.global_position)
		var end_pos = path_node.to_local(destination_node.global_position)

		# Calculate distance for control points
		var distance = start_pos.distance_to(end_pos)

		# Different curve styles based on type
		var height_offset = 0.0
		var depth_offset = 0.0

		if path_type == "Camera":
			# Dramatic overhead arcs for camera
			height_offset = min(distance * 0.3, 3.0)
			depth_offset = distance * 0.2
		else:  # Player
			# Low ground-level paths for player
			height_offset = 0.5
			depth_offset = distance * 0.15

		# Create gentle arc with control points
		var cp1 = Vector3(0, height_offset, -depth_offset)
		var cp2 = Vector3(0, height_offset, depth_offset)

		# Add curve points
		curve.add_point(start_pos, Vector3.ZERO, cp1)
		curve.add_point(end_pos, cp2, Vector3.ZERO)

		path_node.curve = curve

		# Select the new path for editing
		editor_interface.get_selection().clear()
		editor_interface.get_selection().add_node(path_node)

		# Success!
		var msg = "Created: %s (%.1f units)" % [path_name, curve.get_baked_length()]
		_update_status(msg, Color.GREEN)

		print("=== Path Created ===")
		print("  Name: ", path_name)
		print("  Origin: ", origin_node.name)
		print("  Destination: ", destination_node.name)
		print("  Length: ", curve.get_baked_length(), " units")

	func _update_status(message: String, color: Color):
		status_label.text = message
		status_label.add_theme_color_override("font_color", color)
