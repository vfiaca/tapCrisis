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

**Purpose:** Defines positions where the player can take cover, with left/right side support.

**Key Properties:**
- `@export var cover_side: String = "left"` - Which side of cover ("left" or "right")
- Camera anchors for each side (CameraAnchor_Left, CameraAnchor_Right)
- Position markers for player placement

**Node Structure:**
```
CoverPoint (Node3D)
├── CameraAnchor_Left (Node3D)
│   ├── position: Where camera moves to
│   └── rotation: Camera's orientation
├── CameraAnchor_Right (Node3D)
│   ├── position: Where camera moves to
│   └── rotation: Camera's orientation
└── (Optional: Visual mesh for debugging)
```

**How It Works:**
- Each cover point has two camera anchors (left/right sides)
- Camera anchors store both position AND rotation
- When player takes cover, camera snaps to the anchor's transform
- No look_at behavior - camera uses exact anchor transform

**Usage:**
1. Place CoverPoint node in scene
2. Add CameraAnchor_Left and CameraAnchor_Right as children
3. Position anchors where camera should be for each side
4. Set anchor rotations to face desired direction
5. Set cover_side based on level layout

---

## Camera Controller

### CameraController (`scripts/core/camera_controller.gd`)

**Purpose:** Manages camera movement between cover points and handles touch/mouse input for aiming.

**Key Properties:**
```gdscript
@export var camera_move_speed: float = 5.0  ## Speed of camera transitions
@export var look_sensitivity: float = 0.002  ## Mouse/touch look sensitivity
@export var vertical_look_limit: float = 60.0  ## Max vertical rotation (degrees)
```

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
func move_to_cover(cover_point: CoverPoint, side: String):
    # Smoothly interpolates to cover anchor position + rotation
    # Uses exact transform from CameraAnchor, no look_at
```

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
│   └── core/
│       ├── camera_controller.gd (Camera + Input)
│       ├── player_controller.gd (Player + Animations)
│       ├── cover_point.gd (Cover point logic)
│       └── game_manager.gd (Game coordination)
├── characters/ (Future: Character models go here)
└── claude.md (This file)
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

## Common Operations

### Adding a New Cover Point
1. Instance `cover_point.tscn` in level
2. Position where player should stand
3. Add CameraAnchor_Left and CameraAnchor_Right children
4. Position + rotate anchors for desired camera angles
5. Set cover_side based on enemy placement
6. GameManager auto-collects on level load

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

---

## Questions / Future Decisions

1. **Enemy Placement:** Should enemies be tied to specific cover points or free-roaming?
2. **Cover Damage:** Can cover be destroyed? Does it degrade?
3. **Movement Timing:** Should cover-to-cover movement be instant or animated?
4. **Weapon System:** Single weapon or multiple? Reloading mechanics?
5. **Difficulty Scaling:** How to increase challenge across levels?
