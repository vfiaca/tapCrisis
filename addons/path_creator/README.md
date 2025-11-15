# Path Creator - Simple Path3D Tool

A streamlined tool for creating Path3D nodes between any two nodes in your Godot scene.

## Features

- **Inspector-Based Interface** - Appears when you select a CoverPoint
- **Node Picker Buttons** - Select origin and destination with one click
- **Anchor Setup** - One-click cover anchor generation
- **Direction Control** - Choose Left, Right, Forward, or Back
- **Type Selection** - Camera (cinematic arcs) or Player (ground-level paths)
- **One-Click Creation** - Generate paths with smart default curves
- **Automatic Naming** - Paths named based on direction and type

## Installation

1. The plugin is located in `addons/path_creator/`
2. Go to **Project → Project Settings → Plugins**
3. Find "Path Creator" in the list
4. Enable the plugin
5. The "Path Creator" panel will appear in the Inspector when you select a CoverPoint

## How to Use

### Basic Workflow

1. **Select a CoverPoint** in your scene tree
   - The "Path Creator" panel appears in the Inspector

2. **(Optional) Setup Anchors:**
   - Click **"🔧 Setup Cover Anchors"** to auto-generate camera and player anchors
   - Only needed once per cover

3. **Set Origin Node:**
   - Select a node in the scene tree (e.g., `CameraAnchor_Left`)
   - Click **"Pick"** button next to Origin Node
   - The node name and type will appear in the field

4. **Set Destination Node:**
   - Select another node in the scene tree (e.g., `Cover_Exit/CameraAnchor_Left`)
   - Click **"Pick"** button next to Destination Node
   - The node name and type will appear in the field

5. **Choose Direction:**
   - Select: Left, Right, Forward, or Back
   - This determines the path name and helps organize your paths

6. **Choose Type:**
   - **Camera** - Creates dramatic overhead arcs (cinematic)
   - **Player** - Creates low ground-level paths (realistic movement)

7. **Click "Create Path"**
   - Path3D node is created as child of origin node
   - Named automatically (e.g., `Path_Forward_Camera`)
   - Curve generated with smart defaults
   - Path selected for immediate editing

### Path Naming

Paths are automatically named: `Path_[Direction]_[Type]`

Examples:
- `Path_Forward_Camera`
- `Path_Left_Player`
- `Path_Back_Camera`

### Curve Defaults

**Camera Paths:**
- High arcs up to 3m elevation
- Sweeping cinematic movement
- Good for dramatic transitions

**Player Paths:**
- Low 0.5m elevation
- Stays close to ground
- Good for running animations

## Tips

- **Use "Pick" buttons** - Easiest way to set nodes without typing paths
- **Select in scene tree first** - Then click Pick to grab that node
- **Paths are editable** - After creation, adjust curves in 3D viewport
- **Organize by direction** - Consistent naming helps manage complex levels

## Example Usage

### Creating a Forward Camera Path

1. Select `Cover_Start` CoverPoint in scene tree
2. In Inspector, scroll to "Path Creator" panel
3. Select `Cover_Start/CameraAnchor_Left` in scene tree → Click "Pick" for Origin
4. Select `Cover_Exit/CameraAnchor_Left` in scene tree → Click "Pick" for Destination
5. Set Direction: **Forward**
6. Set Type: **Camera**
7. Click "Create Path"
8. Result: `Path_Forward_Camera` created under `Cover_Start/CameraAnchor_Left`

### Creating a Player Movement Path

1. Select `Cover_Start` CoverPoint in scene tree
2. In Inspector, scroll to "Path Creator" panel
3. Select `Cover_Start/PlayerAnchor_Right` in scene tree → Click "Pick" for Origin
4. Select `Cover_Exit/PlayerAnchor_Right` in scene tree → Click "Pick" for Destination
5. Set Direction: **Forward**
6. Set Type: **Player**
7. Click "Create Path"
8. Result: `Path_Forward_Player` created under `Cover_Start/PlayerAnchor_Right`

## Workflow Integration

This tool integrates with Tap Crisis's cover system:

1. **Setup covers** - Create CoverPoint nodes with anchors
2. **Create paths** - Use Path Creator to link anchors
3. **Game uses paths** - GameManager finds and follows paths automatically

Path lookup in code checks for:
- `Path_[Direction]_[Type]` nodes as children of cover points

## Troubleshooting

**"Origin node not found"**
- Check the node path is correct (relative to scene root)
- Use the "Pick" button instead of typing manually

**"Path already exists"**
- A path with that name already exists
- Delete the existing path first, or rename it
- The tool will select the existing path for you

**"Node must be Node3D"**
- Both origin and destination must be spatial nodes (Node3D)
- Anchors (Marker3D) are Node3D and work perfectly

**Panel not visible**
- Make sure plugin is enabled in Project Settings
- Select a CoverPoint node to see the "Path Creator" panel in Inspector
- Restart Godot if needed

## Advantages Over Old System

- **No complex setup** - Just pick two nodes and go
- **Works with any nodes** - Not limited to CoverPoint structure
- **Clear workflow** - Linear process from start to finish
- **No auto-detection** - You control everything
- **Faster iteration** - Create paths in seconds

## Files

- `plugin.gd` - Main plugin script with UI and path creation logic
- `plugin.cfg` - Plugin configuration
- `README.md` - This file
