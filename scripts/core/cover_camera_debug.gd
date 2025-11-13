@tool
extends Camera3D
class_name CoverCameraDebugTool

## Debug tool for positioning cover cameras in the editor
## Move this camera to desired position, then click "Apply to Anchor" to save

enum TargetSide { LEFT, RIGHT }

@export_group("Debug Tool")
@export var target_side: TargetSide = TargetSide.LEFT:
	set(value):
		target_side = value
		_update_from_anchor()

@export var apply_to_anchor: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_apply_to_anchor()

@export var load_from_anchor: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_update_from_anchor()

var cover_point: CoverPoint = null

func _ready():
	if Engine.is_editor_hint():
		# Find parent CoverPoint
		cover_point = _find_cover_point(get_parent())
		_update_from_anchor()

func _find_cover_point(node: Node) -> CoverPoint:
	if node is CoverPoint:
		return node
	if node.get_parent():
		return _find_cover_point(node.get_parent())
	return null

## Apply current camera transform to the target anchor
func _apply_to_anchor():
	if not cover_point:
		cover_point = _find_cover_point(get_parent())

	if not cover_point:
		push_error("CoverCameraDebugTool: Cannot find parent CoverPoint!")
		return

	var anchor_name = "CameraAnchor_Left" if target_side == TargetSide.LEFT else "CameraAnchor_Right"
	var anchor = cover_point.get_node_or_null(anchor_name)

	if not anchor:
		push_error("CoverCameraDebugTool: Cannot find anchor: " + anchor_name)
		return

	# Copy this camera's transform to the anchor
	anchor.global_transform = global_transform

	print("✓ Applied camera transform to ", anchor_name)
	print("  Position: ", global_position)
	print("  Rotation: ", global_rotation_degrees)

## Load anchor transform to this camera
func _update_from_anchor():
	if not Engine.is_editor_hint():
		return

	if not cover_point:
		cover_point = _find_cover_point(get_parent())

	if not cover_point:
		return

	var anchor_name = "CameraAnchor_Left" if target_side == TargetSide.LEFT else "CameraAnchor_Right"
	var anchor = cover_point.get_node_or_null(anchor_name)

	if anchor:
		global_transform = anchor.global_transform
		print("↻ Loaded transform from ", anchor_name)
