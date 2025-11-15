@tool
extends MeshInstance3D

## Visualizes a Path3D curve in the 3D viewport (editor and runtime)
## Add this as a child of a CoverPoint to visualize its custom paths

@export var target_path: Path3D = null:
	set(value):
		target_path = value
		_update_visualization()

@export_group("Visualization Settings")
@export var show_in_game: bool = false  ## Show during gameplay (useful for debugging)
@export var line_color: Color = Color(1.0, 0.8, 0.2, 0.8)  ## Path line color
@export var line_width: float = 0.05  ## Width of the path line
@export var segments: int = 64  ## Number of segments (higher = smoother)

@export_group("Auto-Detect")
@export_enum("left", "right", "forward", "back", "none") var auto_direction: String = "none":
	set(value):
		auto_direction = value
		if auto_direction != "none":
			_auto_detect_path()

var current_mesh: ArrayMesh = null

func _ready():
	if not Engine.is_editor_hint() and not show_in_game:
		visible = false
		return

	_update_visualization()

func _process(_delta):
	if Engine.is_editor_hint():
		# Update visualization in editor if path changed
		if target_path and target_path.curve:
			_update_visualization()

func _auto_detect_path():
	var parent = get_parent()
	if parent is CoverPoint:
		target_path = parent.get_custom_path(auto_direction)
		_update_visualization()

func _update_visualization():
	if not target_path or not target_path.curve:
		# Clear mesh if no path
		mesh = null
		return

	var curve = target_path.curve
	if curve.point_count < 2:
		mesh = null
		return

	# Create tube mesh following the curve
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var curve_length = curve.get_baked_length()
	var step = curve_length / float(segments)

	# Generate tube geometry
	for i in range(segments + 1):
		var offset = i * step
		var pos_local = curve.sample_baked(offset)
		var pos_world = target_path.to_global(pos_local)
		var pos_relative = to_local(pos_world)

		# Get tangent for tube orientation
		var tangent_local = curve.sample_baked_up_vector(offset)

		# Create circle cross-section
		var circle_segments = 8
		for j in range(circle_segments + 1):
			var angle = (j / float(circle_segments)) * TAU
			var up = Vector3.UP if i == 0 else tangent_local
			var right = up.cross(Vector3.FORWARD).normalized()
			if right.length() < 0.1:
				right = up.cross(Vector3.RIGHT).normalized()
			var forward = right.cross(up).normalized()

			var circle_pos = pos_relative + (right * cos(angle) + forward * sin(angle)) * line_width

			surface_tool.set_color(line_color)
			surface_tool.add_vertex(circle_pos)

	# Generate indices for tube
	for i in range(segments):
		var circle_segments = 8
		for j in range(circle_segments):
			var current = i * (circle_segments + 1) + j
			var next = current + 1
			var current_next_ring = (i + 1) * (circle_segments + 1) + j
			var next_next_ring = current_next_ring + 1

			# Two triangles per quad
			surface_tool.add_index(current)
			surface_tool.add_index(current_next_ring)
			surface_tool.add_index(next)

			surface_tool.add_index(next)
			surface_tool.add_index(current_next_ring)
			surface_tool.add_index(next_next_ring)

	# Create material
	var material = StandardMaterial3D.new()
	material.albedo_color = line_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	surface_tool.set_material(material)

	# Generate and assign mesh
	mesh = surface_tool.commit()
