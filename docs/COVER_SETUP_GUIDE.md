# Cover Setup Quick Reference

A streamlined workflow for creating and connecting cover points in Tap Crisis.

## 🚀 Quick Start (5-Minute Setup)

### Step 1: Enable the Plugin

1. Go to **Project → Project Settings → Plugins**
2. Find "Path Creator" and check the **Enable** box
3. Restart Godot if prompted
4. The "Path Creator" panel will appear in the Inspector when you select a CoverPoint

### Step 2: Create Your First Cover

1. **Add CoverPoint Node**
   - In your level scene, right-click and add a new **Node3D**
   - Change its type to **CoverPoint** (use the "Change Type" button)
   - Position it where you want cover (e.g., behind a crate)
   - Name it something descriptive: `Cover_Entrance`

2. **Configure Basic Properties**
   - Select the CoverPoint in the scene tree
   - In the Inspector:
     - **Height**: Choose `MEDIUM` or `TALL`
       - `MEDIUM` - Player crouches, good for low walls/crates
       - `TALL` - Player stands, good for pillars/doorways
     - **Active Sides**: Leave as "Left, Right" (both enabled)

3. **Auto-Generate Anchors**
   - Scroll down in Inspector to **"Cover Setup & Path Tools"**
   - Click **🔧 Setup Cover Anchors** button
   - ✓ Camera anchors positioned automatically based on height!
   - ✓ Player anchors created at ground level (y=0)

4. **Position Player Anchors (Manual)**
   - Expand the CoverPoint in the scene tree
   - Select **PlayerAnchor_Left**
   - Move it to where the player should stand on the left side (keep y=0 for ground level)
   - Select **PlayerAnchor_Right**
   - Move it to where the player should stand on the right side (keep y=0 for ground level)
   - **Note**: Player height comes from animation (crouch/stand), not anchor height

### Step 3: Create a Second Cover

1. Duplicate the first cover (**Ctrl+D** or **Cmd+D**)
2. Move it to a new position (e.g., across the room)
3. Rename it: `Cover_Exit`
4. The anchors are already set up!

### Step 4: Connect the Covers

1. Select `Cover_Entrance`
2. In the Inspector, find the **"Connections"** section
3. Drag `Cover_Exit` into the `forward_cover` property
4. Select `Cover_Exit`
5. Drag `Cover_Entrance` into the `back_cover` property
6. ✓ Now the covers are connected both ways!

### Step 5: Add Movement Paths

1. **Select `Cover_Entrance`** in scene tree
2. **Scroll to "Path Creator" panel** in Inspector
3. **Create Forward Camera Path:**
   - Select `Cover_Entrance/CameraAnchor_Left` in scene tree → click **Pick** for Origin
   - Select `Cover_Exit/CameraAnchor_Left` in scene tree → click **Pick** for Destination
   - Set Direction: **Forward**
   - Set Type: **Camera**
   - Click **Create Path**
4. **Create Forward Player Path:**
   - Select `Cover_Entrance/PlayerAnchor_Left` in scene tree → click **Pick** for Origin
   - Select `Cover_Exit/PlayerAnchor_Left` in scene tree → click **Pick** for Destination
   - Set Direction: **Forward**
   - Set Type: **Player**
   - Click **Create Path**
5. **Select `Cover_Exit`** and repeat for backward direction
6. ✓ Paths created with smart defaults!

### Step 6: Test

1. **Save your scene** (Ctrl+S)
2. Add the covers to your game manager's starting_cover
3. **Run the game** (F5)
4. Use **W/S** or swipe forward/back to move between covers
5. The camera and player follow the custom paths!

**Quick Tip:**
- The **Pick** buttons make path creation super fast
- Just select node → click Pick → select next node → click Pick → Create!
- Clear buttons (X) let you reset your selections

---

## 📖 Detailed Reference

### Cover Properties

#### Cover Properties Group
- **height**: `MEDIUM` (crouch) or `TALL` (stand)
  - Controls which animation the player uses
  - MEDIUM: Player uses crouch animation, camera at 1.2m
  - TALL: Player uses standing animation, camera at 1.6m
  - Player anchor height is ALWAYS y=0 (ground level)
- **active_sides**: Which sides can be used (Left, Right, or Both)
- **cover_name**: Debug label (appears in console logs)

#### Camera Settings Group
- **left_fov**: Camera field of view when on left side (default: 75°)
- **right_fov**: Camera field of view when on right side (default: 75°)

#### Movement Timing Group
**NEW! Per-cover timing customization:**
- **camera_transition_duration**: How long camera takes to reach this cover (default: 1.5s)
- **player_movement_duration**: How long player takes to reach this cover (default: 0.8s)
- **transition_ease_type**: Easing curve for transitions (default: EASE_IN_OUT)

> **Tip**: Adjust these for dramatic slow-motion entries or quick tactical dives!

#### Connections Group
- **left_cover**: CoverPoint to the left
- **right_cover**: CoverPoint to the right
- **forward_cover**: CoverPoint in front
- **back_cover**: CoverPoint behind

> **Note**: You only need to set connections in the direction of movement. The system works if only one side is connected.

### Auto-Generated Anchors

When you click "Setup Cover Anchors", these are created:

- **PlayerAnchor_Left** - Ground-level position marker for left side (y=0)
- **PlayerAnchor_Right** - Ground-level position marker for right side (y=0)
- **CameraAnchor_Left** - Camera position for left view (auto-positioned)
- **CameraAnchor_Right** - Camera position for right view (auto-positioned)

**Automatic Positioning:**

**Camera Anchors** (fully automatic):
- Position: ±0.5m from center horizontally, elevated based on cover height
- MEDIUM covers: Camera at 1.2m height, -0.8m back
- TALL covers: Camera at 1.6m height, -1.0m back
- Rotation: -10° downward tilt, looking forward

**Player Anchors** (manual positioning required):
- Created at ground level: y=0
- Initial position: ±0.5m from center horizontally
- **You must position these** where you want the player to stand
- Keep y=0 for ground level (height comes from animation)

**Manual Adjustment:**
- **Player anchors**: Always adjust these to fit your level layout
- **Camera anchors**: Only adjust if you need specific camera framing
- Expand CoverPoint → Select anchor → Move/rotate as needed
- Changes saved automatically with your scene

### Path Creation

The "Cover Setup & Path Tools" panel shows 4 direction sections:
- **Left Direction**
- **Right Direction**
- **Forward Direction**
- **Back Direction**

Each direction has two path types:

#### Camera Paths (Cinematic)
- Used for dramatic camera movements
- Default: High arc (up to 3m elevation)
- Creates sweeping, cinematic transitions
- **Create**: Generates path with smart defaults
- **Edit**: Selects path for manual curve editing

#### Player Paths (Movement)
- Used for character running animations
- Default: Low tactical path (0.5m above ground)
- Creates realistic ground-level movement
- **Create**: Generates path with smart defaults
- **Edit**: Selects path for manual curve editing

**Bulk Operations** (Bottom of Panel):
- **Create All Camera Paths**: Creates camera paths for all connected directions
- **Create All Player Paths**: Creates player paths for all connected directions
- **Create All Paths (Camera + Player)**: Creates both types for all connections
- **Clear All Paths**: Removes all paths from this cover

### Path Editing

After creating a path:

1. Click the **Edit** button next to the path
2. The Path3D node is selected in the scene tree
3. In the 3D viewport:
   - **Click and drag** curve points to move them
   - **Click control handles** to adjust curve shape
   - **Right-click** on curve to add/delete points
4. Changes are saved automatically

**Tips:**
- Paths start/end at anchor positions (already correct!)
- Only adjust the **curve shape**, not endpoints
- Use camera preview to see the path from player perspective
- Test in-game frequently to check feel

---

## 🎯 Workflow Tips

### Rapid Level Prototyping

1. **Create one cover** with auto-setup
2. **Duplicate it** multiple times (Ctrl+D)
3. **Position the duplicates** around your level
4. **Connect them** using the Connections properties
5. **Create all paths** using "Create All Paths" bulk button
6. **Test and iterate**

### Cover Height Guidelines

**Use MEDIUM for:**
- Crates, boxes, low walls
- Tactical shooter feel
- Fast-paced sections
- Outdoors with waist-high barriers

**Use TALL for:**
- Pillars, columns, doorways
- Stealth sections
- Indoor corridors
- Full-height cover like walls

### Movement Timing Guidelines

**Slower transitions (1.5-2.0s):**
- Dramatic moments
- First entrance to an area
- Long-distance movement
- Cinematic reveals

**Faster transitions (0.5-0.8s):**
- Combat situations
- Quick cover-to-cover dashes
- Tight spaces
- Arcade action feel

### Path Creation Guidelines

**Always create camera paths for:**
- First time entering an area (dramatic reveal)
- Long-distance movements (show the environment)
- Story moments (cinematic framing)

**Always create player paths for:**
- When there are obstacles between covers
- Non-straight-line movements
- When you want specific running animations

**Skip paths when:**
- Covers are very close (< 2m apart)
- Movement is a simple straight line
- You want instant/snappy movement

---

## 🔧 Troubleshooting

### "Setup Cover Anchors" button doesn't appear
- Make sure you have a **CoverPoint** node selected
- Check that the "Cover Path Tools" plugin is enabled
- Try restarting Godot

### Anchors are in wrong positions
- Select the cover and change the **Height** property
- Click "Setup Cover Anchors" again to regenerate
- Or manually adjust anchor positions in the scene tree

### Paths don't align with anchors
- This was fixed in the latest version
- Make sure you're using the current plugin.gd
- Recreate the path (delete old one, create new)

### Player/camera doesn't follow path
- Check that the path is assigned to the cover's path property
- Look for the path in the cover's children (e.g., "Path_Forward_Camera")
- Verify the path has at least 2 curve points

### Movement feels too slow/fast
- Adjust `camera_transition_duration` on the **destination** cover
- Adjust `player_movement_duration` on the **destination** cover
- Or change the global defaults in CameraController/PlayerController

---

## 📚 See Also

- [CLAUDE.md](../CLAUDE.md) - Full project reference
- [docs/PATHS_GUIDE.md](PATHS_GUIDE.md) - Complete path system documentation
- [addons/path_creator/README.md](../addons/path_creator/README.md) - Plugin documentation

---

## 🎮 Complete Example: 3-Cover Room

Here's a complete workflow for creating a simple room with 3 covers:

```
Step 1: Create the covers
- Add 3 CoverPoint nodes
- Name them: Cover_Left, Cover_Center, Cover_Right
- Position them in your room
- Set all to Height: MEDIUM

Step 2: Setup anchors (on each cover)
- Select Cover_Left → Click "Setup Cover Anchors"
- Select Cover_Center → Click "Setup Cover Anchors"
- Select Cover_Right → Click "Setup Cover Anchors"

Step 3: Connect them (linear path)
- Cover_Left: forward_cover = Cover_Center
- Cover_Center: back_cover = Cover_Left, forward_cover = Cover_Right
- Cover_Right: back_cover = Cover_Center

Step 4: Create paths (manual approach)
- Cover_Left → Forward → From Left:
  * Camera target: Cover_Center/CameraAnchor_Left
  * Player target: Cover_Center/PlayerAnchor_Left
- Cover_Center → Back → From Left:
  * Camera target: Cover_Left/CameraAnchor_Left
  * Player target: Cover_Left/PlayerAnchor_Left
- Cover_Center → Forward → From Left:
  * Camera target: Cover_Right/CameraAnchor_Left
  * Player target: Cover_Right/PlayerAnchor_Left
- Cover_Right → Back → From Left:
  * Camera target: Cover_Center/CameraAnchor_Left
  * Player target: Cover_Center/PlayerAnchor_Left

Step 5: Test
- Set GameManager.starting_cover = Cover_Left
- Run game (F5)
- Use W/S to move forward/back through all covers
- Use A/D to peek left/right at each cover
```

**Total time**: ~3 minutes for 3 fully-connected covers with paths! 🚀
