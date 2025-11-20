# Tap Crisis - Development Reference

## Project Overview
A hybrid mobile on-rails shooter built in Godot 4.2+ with Time Crisis-style cover mechanics. Players move between cover points with swipe gestures, step out to shoot, and use tactical cover positioning.

## Architecture Overview

### Core Systems
1. **Cover System** - Manages cover points and player positioning
2. **Camera Controller** - Handles camera movement and targeting
3. **Player Controller** - Controls player animations and shooting
4. **Game Manager** - Orchestrates game flow and level progression

---

## Cover System

### CoverPoint (`scripts/core/cover_point.gd`)

**Purpose:** Defines positions where the player can take cover, with left/right side support and automatic anchor generation.

**Key Properties:**
```gdscript
@export var height: CoverHeight = CoverHeight.MEDIUM  # MEDIUM or TALL
@export_flags("Left:1", "Right:2") var active_sides: int = 3  # Both sides by default
@export var cover_name: String = ""  # For debugging

# Camera settings
@export var left_fov: float = 75.0
@export var right_fov: float = 75.0

# Movement timing (applies when LEAVING this cover)
@export var camera_start_delay: float = -1.0  # Delay before camera follows when leaving. -1 = use default (0.3s)
@export var camera_transition_duration: float = -1.0  # Camera transition speed when leaving. -1 = use default (0.5s)
@export var player_movement_duration: float = -1.0  # Player movement speed when leaving. -1 = use default (0.8s)
@export var transition_ease_type: Tween.EaseType = Tween.EASE_IN_OUT  # Easing when leaving
@export var force_linear_transition: bool = false  # Force linear camera movement when leaving
```

**Timing Design:** All timing settings apply when the player LEAVES this cover, not when arriving. This means you configure each cover once, and those settings are used whenever you depart from it.

**Timing Values:** All timing values use `-1` as a sentinel meaning "use system default". Set to `0` or any positive value to override with explicit timing. This allows intentional zero-delay transitions (e.g., `camera_start_delay = 0.0` for instant camera follow).

**Automated Anchor System:**
Each cover automatically generates 4 anchor points:
- **PlayerAnchor_Left** - Ground-level position marker for left side (manually adjustable)
- **PlayerAnchor_Right** - Ground-level position marker for right side (manually adjustable)
- **CameraAnchor_Left** - Camera position for left side view (auto-positioned by height)
- **CameraAnchor_Right** - Camera position for right side view (auto-positioned by height)

**Cover Height & Animations:**
- **MEDIUM**: Player uses crouch animation, camera at 1.2m
- **TALL**: Player uses standing animation, camera at 1.6m
- **Player anchors** are created at ground level (y=0) as position markers only
- **Player height** is controlled by animation, not anchor position
- **Camera anchors** are automatically positioned based on cover height

**Node Structure:**
```
CoverPoint (Node3D)
├── PlayerAnchor_Left (Marker3D) - Auto-generated
├── PlayerAnchor_Right (Marker3D) - Auto-generated
├── CameraAnchor_Left (Marker3D) - Auto-generated
├── CameraAnchor_Right (Marker3D) - Auto-generated
├── Path_Left_Camera (Path3D) - Optional custom paths
├── Path_Left_Player (Path3D) - Optional custom paths
└── (... more paths)
```

**Simplified Workflow:**
1. **Place CoverPoint** - Add CoverPoint node to your scene
2. **Set Height** - Choose MEDIUM or TALL in Inspector
3. **Click "Setup Cover Anchors"** - Creates all 4 anchors (camera auto-positioned, player at ground level)
4. **Position Player Anchors** - Manually adjust PlayerAnchor_Left and PlayerAnchor_Right positions as needed
5. **Connect Covers** - Set left_cover, right_cover, forward_cover, back_cover references
6. **Create Paths** - Use the path creation buttons to connect anchors with custom paths

**Note:** Camera anchors are automatically positioned based on cover height. Player anchors are created at ground level (y=0) for you to position manually where the player should stand.

---

## Camera Controller

### CameraController (`scripts/core/camera_controller.gd`)

**Purpose:** Manages camera movement between cover points and handles touch/mouse input for aiming.

**Key Properties:**
```gdscript
@export var start_anchor: Marker3D = null  ## Optional: Set camera to this anchor's transform at start

# Internal defaults (not exported - configure timing per cover instead)
const DEFAULT_TRANSITION_DURATION: float = 0.5
const DEFAULT_TRANSITION_EASE: Tween.EaseType = Tween.EASE_IN_OUT
const DEFAULT_TRANSITION_TRANS: Tween.TransitionType = Tween.TRANS_CUBIC
```

**Note:** Camera timing is configured per-cover via [CoverPoint](scripts/core/cover_point.gd#L20-L24) exports, not on the camera itself. The camera's defaults are only used when a cover doesn't specify timing (value = -1).

**Architecture - Camera as Controller:**
The camera IS the player controller. This is different from traditional FPS:
- Camera processes all input (touch, swipe, tap)
- Camera tells GameManager to move player between covers
- Camera raycasts from its position to determine shooting targets
- No separate "player input controller"

**Node Structure:**
```
CameraController (Camera3D)
└── (No children needed)
```

**Input Handling:**
- **Tap/Click**: Shoots at world position under cursor
- **Swipe**: Moves between cover points (detected via drag start/end)
- **Drag**: Aims camera (rotates around current position)

**Camera Movement:**
```gdscript
func transition_to_cover(cover: CoverPoint, side: String, custom_path: Path3D = null):
    # Smoothly transitions to cover anchor position + rotation
    # Uses quaternion slerp for rotation to avoid 360-degree spins
    # Supports custom Path3D curves for cinematic camera movements
    # Respects cover's force_linear_transition flag
```

**Camera Transition System:**
- **Player-First Movement**: Player starts moving, then camera follows after `camera_start_delay`
- **Quaternion Rotation**: Uses `Quaternion.slerp()` to prevent camera spinning during transitions
- **Path Following**: Optionally follows Path3D curves for cinematic camera movements
- **Linear Override**: Set `force_linear_transition = true` on CoverPoint to ignore custom paths
- **Per-Cover Timing**: Each cover can override default transition duration and easing

**Shooting:**
```gdscript
func _handle_tap(position: Vector2):
    # Raycast from camera through screen position
    # Tells player to shoot at world position
    # Player handles animation and timing
```

---

## Player Controller

### PlayerController (`scripts/core/player_controller.gd`)

**Purpose:** Manages player animations, shooting timing, and state transitions.

**States:**
```gdscript
enum State {
    IN_COVER,      # Player behind cover, can shoot
    SHOOTING,      # Player stepped out, firing
    MOVING,        # Transitioning between covers
    VULNERABLE     # Player exposed, can take damage
}
```

**Key Properties:**
```gdscript
@export_group("Animation Timing")
@export var step_out_speed: float = 1.0  ## Animation speed multiplier
@export var step_in_delay: float = 0.3   ## Delay before returning to cover

@export_group("Combat")
@export var shoot_cooldown: float = 0.2  ## Time between shots
```

**Animation System (Current Implementation):**

Uses AnimationTree with BlendSpace1D for smooth directional blending:

```
AnimationTree
└── BlendSpace1D (step)
    ├── blend_position: -1.0 → step_left animation
    ├── blend_position: 0.0 → RESET animation (in cover)
    └── blend_position: 1.0 → step_right animation
```

**How Animation Works:**
1. Player starts at cover (blend_position = 0.0)
2. When shooting:
   - If cover_side == "left": blend_position = -1.0 (step left)
   - If cover_side == "right": blend_position = 1.0 (step right)
3. Animation plays at speed controlled by `step_out_speed`
4. After `step_in_delay`, blend_position returns to 0.0 (step back in)

**Shooting Flow:**
```
Player taps screen
    ↓
Camera raycasts to world position
    ↓
Camera calls player.shoot_at_position()
    ↓
Player sets blend_position (step out animation)
    ↓
Animation completes (0.15s / step_out_speed)
    ↓
Fire weapon immediately
    ↓
Wait step_in_delay
    ↓
Return to cover (blend_position = 0.0)
```

**Node Structure:**
```
Player (CharacterBody3D)
├── CollisionShape3D (Capsule)
├── Model (Node3D) ← Animation target
│   └── PlayerMesh (placeholder capsule)
├── ShootOrigin (Node3D) - Gun muzzle position
├── ShootRaycast (RayCast3D) - Hit detection
├── AnimationPlayer - Plays individual animations
└── AnimationTree - Blends animations via BlendSpace1D
```

**Cover Movement:**
```gdscript
func move_to_cover(cover_point: CoverPoint, side: String):
    current_state = State.MOVING
    current_cover = cover_point
    current_side = side

    # Snap to cover position
    global_position = cover_point.global_position
    global_rotation = cover_point.global_rotation

    current_state = State.IN_COVER
```

---

## Game Manager

### GameManager (`scripts/core/game_manager.gd`)

**Purpose:** Central coordinator for game state, cover navigation, and level flow.

**Key Responsibilities:**
- Maintains list of cover points in current level
- Handles cover-to-cover navigation
- Tracks current cover and side
- Manages game state (playing, paused, etc.)

**Cover Navigation:**
```gdscript
func move_to_next_cover():
    # Finds next cover point in sequence
    # Tells player to move
    # Tells camera to transition
```

**Initialization:**
```gdscript
func _ready():
    # Find camera and player references
    # Collect all CoverPoint nodes
    # Start at first cover point
```

---

## Animation System Deep Dive

### Current System: Procedural Animation with BlendSpace1D

**Implementation Location:**
- Scene: `scenes/player/player.tscn`
- Script: `scripts/core/player_controller.gd`

**Animation Definitions:**
Three animations in AnimationLibrary:

1. **RESET** (0.001s)
   - Resets Model position to (0, 0, 0)
   - Used as "in cover" pose

2. **step_left** (0.15s)
   - Moves Model from (0,0,0) to (-0.4, 0, 0)
   - Cubic interpolation for smooth motion

3. **step_right** (0.15s)
   - Moves Model from (0,0,0) to (0.4, 0, 0)
   - Cubic interpolation for smooth motion

**BlendSpace1D Configuration:**
```gdscript
blend_point_0/pos = -1.0  → step_left
blend_point_1/pos = 0.0   → RESET
blend_point_2/pos = 1.0   → step_right
blend_mode = 1            → Interpolated blending
```

**Why BlendSpace instead of State Machine:**
- Allows smooth blending between left/right/center
- Single parameter control (blend_position)
- No complex transition logic needed
- Can later add diagonal blend positions

**Control from Code:**
```gdscript
# Step out left
animation_tree.set("parameters/step/blend_position", -1.0)

# Return to cover
animation_tree.set("parameters/step/blend_position", 0.0)

# Step out right
animation_tree.set("parameters/step/blend_position", 1.0)
```

### Future System: Root Motion with Rigged Character

**Current Limitation:**
- Animations move child Model node, not character root
- Placeholder capsule mesh only
- No character skeleton/bones

**When Adding Rigged Character:**

1. **Character Requirements:**
   - Armature/Skeleton3D with skinned mesh
   - Animations that move the armature root (root motion)
   - Animation names: idle, step_left, step_right, shoot

2. **Integration Steps:**
   - Import character into `res://characters/`
   - Instance as child of Player's Model node
   - Update AnimationTree to point to character's AnimationPlayer
   - Update AnimationNodeAnimation names to match character's animations
   - Character's armature will move, carrying skinned mesh

3. **Root Motion Benefits:**
   - Animator controls exact movement in animation software
   - Character body animation matches positional movement
   - Can have complex multi-step animations
   - Easy to iterate in animation software

4. **No Code Changes Needed:**
   - player_controller.gd already controls blend_position
   - Timing properties already exported
   - System automatically uses character's animations

**Setup Checklist for Rigged Character:**
```
□ Character has idle/step_left/step_right animations
□ Animations include armature root movement
□ Import character model (.gltf/.fbx)
□ Instance under Player/Model node
□ Update AnimationTree anim_player path: "Model/YourCharacter/AnimationPlayer"
□ Update AnimationNodeAnimation resources with animation names
□ Test - animations should play automatically
```

---

## Input Flow Diagram

```
Touch/Mouse Input
    ↓
CameraController detects input type
    ↓
    ├─→ TAP: Raycast → Get world position → player.shoot_at_position()
    ├─→ DRAG: Rotate camera for aiming
    └─→ SWIPE: Calculate direction → game_manager.move_to_next_cover()
        ↓
        GameManager finds next cover point
        ↓
        ├─→ player.move_to_cover(cover, side)
        │   └─→ Snap player position to cover
        └─→ camera.move_to_cover(cover, side)
            └─→ Smooth interpolate to camera anchor
```

---

## File Structure

```
tapCrisis/
├── scenes/
│   ├── player/
│   │   └── player.tscn (Player with animations)
│   ├── cover/
│   │   └── cover_point.tscn (Cover point template)
│   └── levels/
│       └── test_level.tscn (Test environment)
├── scripts/
│   ├── core/
│   │   ├── camera_controller.gd (Camera + Input + Path following)
│   │   ├── player_controller.gd (Player + Animations + Path following)
│   │   ├── cover_point.gd (Cover point logic + Path references)
│   │   └── game_manager.gd (Game coordination)
├── addons/
│   └── path_creator/
│       ├── plugin.gd (Inspector-based path creation plugin)
│       ├── plugin.cfg
│       └── README.md
├── docs/
│   └── PATHS_GUIDE.md (Complete custom paths documentation)
├── characters/ (Future: Character models go here)
└── CLAUDE.md (This file)
```

---

## Key Design Decisions

### 1. Camera-as-Controller Architecture
**Why:** Mobile-first design where touch input naturally maps to camera space
**Benefit:** Simplified input handling, intuitive screen-space interactions

### 2. Animation-Driven Movement
**Why:** Ensures movement timing matches visual animation
**Benefit:** Responsive feel, easy to tune timing without code changes

### 3. BlendSpace1D for Cover Animation
**Why:** Smooth blending between directional poses
**Benefit:** Can add intermediate poses (45° angles) without state machine complexity

### 4. No Camera Look-At Behavior
**Why:** Designers need full control over camera composition
**Benefit:** Can pre-compose dramatic angles, no fighting automated aiming

### 5. Cover Anchors Store Full Transform
**Why:** Position + Rotation control from single node
**Benefit:** Fast iteration, visual editing in Godot editor

---

## Custom Camera & Player Paths

The game supports **dual custom paths** for cinematic camera movements and realistic player transitions between covers.

### Path Types

**Camera Paths:**
- Create dramatic overhead sweeps and cinematic camera movements
- Independent from player movement
- Default: Gentle overhead arc (30% of distance, max 3m height)

**Player Paths:**
- Define realistic running/movement routes between covers
- Stay close to ground for authentic character animation
- Default: Low tactical path (0.5m height)

### Quick Start

1. **Enable Plugin:** Project → Settings → Plugins → "Path Creator"
2. **Select CoverPoint:** Choose any cover in your scene
3. **Path Creator Panel:** Appears in Inspector when CoverPoint is selected
4. **Create Paths:**
   - Select origin node → Click "Pick"
   - Select destination node → Click "Pick"
   - Choose direction (Left, Right, Forward, Back)
   - Choose type (Camera or Player)
   - Click "Create Path"
5. **Edit:** Path is auto-selected - adjust curves in 3D viewport

**Inspector-Based:** Clean interface integrated into Inspector panel for streamlined workflow!

### Path Properties (per CoverPoint)

```gdscript
# Camera paths (cinematic)
forward_camera_path: Path3D
back_camera_path: Path3D
left_camera_path: Path3D
right_camera_path: Path3D

# Player paths (movement)
forward_player_path: Path3D
back_player_path: Path3D
left_player_path: Path3D
right_player_path: Path3D
```

### Usage in Code

```gdscript
# Get paths
var camera_path = cover.get_camera_path("forward")
var player_path = cover.get_player_path("forward")

# Both camera and player follow their respective paths (if defined)
camera.transition_to_cover(next_cover, side, camera_path)
await player.move_to_cover(next_cover, side, player_path)
```

**📖 For complete documentation, see [docs/PATHS_GUIDE.md](docs/PATHS_GUIDE.md)**

---

## Common Operations

### Adding a New Cover Point (Simplified Workflow)

**Step 1: Create the Cover**
1. Add new Node3D to your level scene
2. Change type to `CoverPoint` (or instance `cover_point.tscn` if you have a template)
3. Position it where you want the cover to be
4. Give it a descriptive name (e.g., "Cover_Entrance")

**Step 2: Configure Properties**
1. Select the CoverPoint in the scene tree
2. In the Inspector, set:
   - **Height**: Choose `MEDIUM` (crouch) or `TALL` (stand)
   - **Active Sides**: Check "Left" and/or "Right" (both enabled by default)
   - **Cover Name**: Optional debug label
   - **Movement Timing**: Adjust camera/player transition speeds if needed

**Step 3: Auto-Generate Anchors**
1. Scroll down to the "Cover Setup & Path Tools" panel in Inspector
2. Click the **"🔧 Setup Cover Anchors"** button
3. All 4 anchors (2 player, 2 camera) are created and positioned automatically!

**Step 4: Connect to Other Covers**
1. In the "Connections" group, set:
   - `left_cover` - Cover to the left
   - `right_cover` - Cover to the right
   - `forward_cover` - Cover in front
   - `back_cover` - Cover behind
2. These create the movement graph for the level

**Step 5: Create Custom Paths (Optional)**
1. For each direction, choose starting side ("From Left" or "From Right")
2. Enter target node path in the text field:
   - For camera paths: `TargetCover/CameraAnchor_Left` (or Right)
   - For player paths: `TargetCover/PlayerAnchor_Left` (or Right)
   - Tip: Right-click node in scene tree → Copy Node Path
3. Click **"Create"** next to "Camera" or "Player"
4. Path is automatically created with smart curve defaults
5. Click **"Edit"** to fine-tune the curve shape in 3D viewport

**Benefits of Manual Target Selection:**
- Connect to any Node3D in your scene (not just cover anchors)
- Create asymmetric paths (different entry/exit points)
- Full control over path endpoints for complex level layouts

**That's it!** GameManager auto-collects covers on level load.

### Adjusting Shooting Timing
1. Open Player scene in editor
2. Select Player node
3. Adjust in Inspector:
   - `step_out_speed`: Higher = faster step-out
   - `step_in_delay`: Time before returning to cover
   - `shoot_cooldown`: Minimum time between shots

### Testing Cover Flow
1. Run test_level.tscn
2. Player starts at first cover
3. Swipe horizontally to move between covers
4. Tap to shoot at cursor position
5. Drag to look around while in cover

---

## Known Limitations / TODO

### Current Limitations
- Placeholder capsule mesh (no rigged character yet)
- Procedural animation only (no imported animations)
- No weapon firing VFX/SFX
- No enemy AI/targeting
- No damage system
- Basic swipe detection (no diagonal movement)

### Next Steps
1. Import rigged character with cover animations
2. Add weapon firing system (raycast + VFX)
3. Implement enemy AI and targeting
4. Add damage/health system
5. Create multiple cover points with cover-to-cover paths
6. Add UI (health, ammo, crosshair)
7. Polish animation transitions

---

## Technical Notes

### Godot 4.2+ Specifics
- Using `@export_group` for property organization
- AnimationTree with typed NodePaths
- Input handling via `_input()` with InputEvent
- Async timing with `await get_tree().create_timer()`

### Performance Considerations
- Single AnimationTree per player (lightweight)
- Camera raycast only on tap (not per-frame)
- Cover points use simple Node3D (no physics overhead)
- Animation blending happens on GPU

### Mobile Optimization
- Touch input handled in camera controller
- Swipe threshold tunable for different screen sizes
- Look sensitivity adjustable for device variation
- No continuous raycasting (battery friendly)

---

## Glossary

**Cover Point** - A position in the level where the player can take cover
**Camera Anchor** - A node storing camera position + rotation for a cover side
**Cover Side** - Whether player is peeking from "left" or "right" of cover
**Blend Position** - AnimationTree parameter controlling which animation plays
**Root Motion** - Animation that moves the character's root transform
**Step Out** - Animation of player leaning/stepping out from cover to shoot
**Step In** - Animation of player returning to cover after shooting

---

## Change Log

### Session 1 - Core Systems
- Created cover point system with camera anchors
- Implemented camera controller with input handling
- Built player controller with state management
- Set up game manager for cover navigation

### Session 2 - Animation System
- Implemented AnimationPlayer with step-out animations
- Refactored to AnimationTree with BlendSpace1D
- Added directional animations (step_left/step_right)
- Consolidated timing properties (step_out_speed, step_in_delay)
- Fixed AnimationNodeStateMachineTransition parse error
- Documented root motion integration workflow

### Session 3 - Cover System Overhaul
- Created Cover Path Tools editor plugin (addons/cover_path_tools/)
- Implemented auto-anchor generation system
- Added per-cover timing properties (camera_transition_duration, player_movement_duration)
- Built dual-path system (separate camera and player paths)
- Implemented side-specific path creation (forward/back from left/right sides)
- Changed player anchors to ground-level markers (y=0, height via animation)
- Camera anchors auto-positioned based on cover height (MEDIUM/TALL)

### Session 4 - Manual Path Creation
- Simplified path creation tool with manual target node selection
- Replaced auto-detection with direct node path input fields
- Added target node text fields to all direction/side combinations
- Created `_on_create_path_manual()` for flexible path endpoint control
- Updated all documentation (README, COVER_SETUP_GUIDE, CLAUDE.md)
- Benefits: Connect to any Node3D, asymmetric paths, full endpoint control

### Session 5 - Complete Path System Redesign
- **Scrapped entire old path creation system** (deleted `addons/cover_path_tools/`)
- Created brand new "Path Creator" plugin (`addons/path_creator/`)
- **Inspector-based interface** - appears when CoverPoint selected
- Node picker workflow: select origin → Pick → select destination → Pick → Create
- Integrated anchor setup button for one-click cover configuration
- No complex auto-detection or path typing
- Single responsibility: create Path3D between two nodes
- Clean, minimal UI focused on speed and clarity
- Direction/type selection determines path naming only
- Clear buttons (X) to reset selections quickly

### Session 6 - Camera Timing & Transition Fixes
- **Fixed export variable runtime bug**: Changed timing defaults to -1 (sentinel value) to distinguish "use default" from "user set to 0"
- **Added camera start delay system**: Player moves first, camera follows after configurable delay
- **Fixed camera rotation spinning**: Converted from Euler angle interpolation to Quaternion slerp for shortest-path rotation
- **Added force_linear_transition option**: Allow designers to override custom paths and force linear camera movement
- **Updated conditional logic**: Changed all `> 0` checks to `>= 0` to allow explicit zero values
- **Per-cover timing overrides**: Each cover can now properly override camera transition duration, delay, and easing
- **Source-based timing design**: Timing settings apply when LEAVING a cover (not arriving), reducing configuration complexity
- **Simplified timing architecture**: Removed camera controller timing exports, made them internal constants - timing is now configured ONLY per-cover
- **Added debug output**: Camera transitions now log duration, ease type, and force_linear flag for troubleshooting
- **GameManager timing defaults**: Added DEFAULT_CAMERA_START_DELAY constant (0.3s) for consistent fallback behavior

### Session 7 - Animation & State Timing Fixes
- **Fixed reversed step-out animations**: Corrected blend_position logic in `_step_out()` function
- **Animation direction now matches cover side**: Left side → step RIGHT (out from left), Right side → step LEFT (out from right)
- **Updated player_controller.gd:249**: Inverted animation logic from `-1.0 if left else 1.0` to `1.0 if left else -1.0`
- **Fixed double-swipe bug**: Moved state updates to START of movement functions instead of end
- **State timing correction**: `current_cover` and `current_side` now update immediately when movement begins, preventing race conditions
- **Fixed player spawn offset**: Added animation initialization in `_ready()` to set blend_position = 0.0 at startup
- **Added starting_side safety check**: Defaults to "left" if null or empty in game_manager.gd
- **Updated both movement functions**: Applied state timing fix to both `move_to_cover()` and `rotate_to_side()`
- **Side rotation logic improvement**: Only attempt rotation when current cover has BOTH sides active
- **Added debug output**: Swipe direction handling now logs current cover state for troubleshooting
- **Fixed raycast shooting from behind cover**: Moved ShootOrigin and ShootRaycast nodes to be children of Model node instead of Player root, so they move with step-out animations
- **Updated node paths**: Changed `$ShootOrigin` to `$Model/ShootOrigin` in player_controller.gd:47
- **Fixed animation target conflict**: Reverted animations to target `Model:position` and `Model:rotation` instead of Player root, preventing conflict between animation and movement systems
- **Established architecture for skeletal characters**: Player root stays at cover anchor (movement control), Model node animated (visual/collision offset), allowing skeleton with per-bone colliders to inherit Model's transform

---

## Questions / Future Decisions

1. **Enemy Placement:** Should enemies be tied to specific cover points or free-roaming?
2. **Cover Damage:** Can cover be destroyed? Does it degrade?
3. **Movement Timing:** Should cover-to-cover movement be instant or animated?
4. **Weapon System:** Single weapon or multiple? Reloading mechanics?
5. **Difficulty Scaling:** How to increase challenge across levels?
