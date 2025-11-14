# Custom Path System for Cover Points

The custom path system allows you to create cinematic, curved camera movements between cover points instead of linear interpolation.

## Quick Start

### Method 1: Manual Path Creation (Recommended)

1. **Create Path Node**
   - Select the FROM cover point in the scene tree
   - Add a child node: `Path3D`
   - Name it descriptively (e.g., `Path_Forward`, `Path_Left`)

2. **Edit the Curve**
   - Select the Path3D node
   - In the 3D editor, click "Add Point" in the toolbar
   - Click in the 3D view to place curve points
   - Drag the control handles to shape the curve
   - The curve should start at the FROM cover and end at the TO cover

3. **Link to Cover**
   - Select the FROM cover point
   - In the Inspector, find "Custom Paths (Optional)"
   - Drag the Path3D node to the appropriate slot:
     - `forward_path` for forward movement
     - `back_path` for backward movement
     - `left_path` for left movement
     - `right_path` for right movement

### Method 2: Tool Script (Auto-Generation)

1. **Add Tool Node**
   - In your scene, add a new Node
   - Attach the script: `res://scripts/tools/create_cover_path.gd`
   - Name it descriptively (e.g., "PathCreator_Start_To_Middle")

2. **Configure**
   - `from_cover`: Select the starting cover point
   - `to_cover`: Select the destination cover point
   - `direction`: Choose the movement direction
   - `control_point_1_offset`: Adjust the first bezier control point
   - `control_point_2_offset`: Adjust the second bezier control point

3. **Generate**
   - Option A: Enable `create_on_ready` and reload the scene
   - Option B: Call `create_path()` from the debugger/console

4. **Fine-Tune**
   - The generated Path3D will appear as a child of FROM cover
   - Select it and manually adjust the curve points in the 3D editor

## Best Practices

### Camera Cinematics
- Use gentle curves for natural-feeling camera movement
- Higher control point offsets (Y-axis) create dramatic sweeping shots
- Asymmetric control points create interesting S-curves

### Path Direction
- **Forward/Back**: Camera moves along the combat line
  - Use these for advancing/retreating through cover
- **Left/Right**: Camera pans sideways
  - Use these for corner peeking or side transitions

### Control Points
- **Control Point 1** (from start): Affects the initial curve direction
  - Positive Y: Camera rises from start
  - Negative Z: Camera pulls back from start
- **Control Point 2** (from end): Affects the final approach
  - Positive Y: Camera descends to end
  - Positive Z: Camera approaches from behind

## Example Configurations

### Dramatic Overhead Sweep
```
control_point_1_offset: Vector3(0, 5, -2)
control_point_2_offset: Vector3(0, 5, 2)
```
Camera rises up and sweeps overhead between covers.

### Low Tactical Advance
```
control_point_1_offset: Vector3(0, 0.5, -1)
control_point_2_offset: Vector3(0, 0.5, 1)
```
Camera stays low and close, tactical shooter feel.

### Wide Cinematic Pan
```
control_point_1_offset: Vector3(-3, 2, -2)
control_point_2_offset: Vector3(3, 2, 2)
```
Camera pans wide left, then right.

## Integration

The system is already integrated with the game manager. When a custom path is defined:
- The path will be used automatically during cover transitions
- If no custom path exists, the system falls back to linear interpolation
- Paths are direction-specific (forward path ≠ back path)

## Tips

- **Test in Editor**: Use the DebugCamera nodes at each cover to preview the view
- **Visualize**: Path curves are visible in the editor (yellow/orange lines)
- **Iterate**: Create the path, test in game, adjust, repeat
- **Performance**: Curves are efficient; don't worry about having many custom paths
- **Reuse**: You can copy/paste Path3D nodes to similar cover transitions

## Troubleshooting

**Path not working?**
- Check that the path is assigned to the correct cover direction property
- Verify the path starts near the FROM cover and ends near the TO cover
- Ensure the Path3D has at least 2 curve points

**Jerky movement?**
- Increase curve bake interval in Path3D settings
- Smooth out sharp control point angles

**Wrong camera angle?**
- Remember: camera position comes from the curve
- Camera rotation comes from the CameraAnchor nodes at each cover
- For cinematic rotation changes, also adjust the CameraAnchor transforms
