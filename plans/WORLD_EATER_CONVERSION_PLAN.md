# World Eater Conversion Plan

## Overview
Convert the strip mining system to a "world eater" that assigns individual blocks (x, z coordinates) to turtles. Each turtle will mine straight down to bedrock, then return to get a new assignment.

### Setup Layout (Top-Down View)
```
                    NORTH
                      |
    [Turtle Parking]  |  [Hub Ref]  |  [Chests/Stations]
    [Turtle Parking]  |  [Hub PC]   |  [Item Drop]
    [Turtle Parking]  |  [Hub Ref]  |  [Refuel]
                      |
                    SOUTH
                      |
         (Mining Center: 2 blocks below Hub Ref on Y)
                      |
         [Mining Area expands outward from here]
```

**Key Points:**
- **Hub Reference:** Central reference point (like current `mine_entrance`)
- **Hub Computer:** Must be within 8 block radius north or south of hub_reference
- **Turtles:** Line up on **west side** (left)
- **Chests:** On **east side** (right)
- **Mining Center:** 2 blocks below hub_reference (prevents surface interference)
- **Mining Area:** Spiral outward from mining_center

## Key Changes Required

### 1. Data Structure Changes

#### Current System (Strip Mining):
- Stores strips organized by level (Y coordinate)
- Each strip has orientation (north/south/east/west)
- Tracks strip progress along horizontal axis
- File structure: `/mine/<x,z>/<level>/<strip_name>` or `/mine/<x,z>/<level>/main_shaft`

#### New System (World Eater):
- Store mined blocks as (x, z) coordinates
- Track which blocks have been completely mined to bedrock
- File structure: `/mine/<x,z>/mined_blocks/<x>,<z>` (simple flag files)
- Remove level-based organization (no more multiple Y levels)

### 2. Hub Files Changes

#### `hub_files/mine_manager.lua`

**Functions to Modify:**
- `load_mine()`: Load mined blocks instead of strips
- `write_strip()` → `write_block()`: Mark block as mined
- `update_strip()` → `update_block()`: Mark block as mined when turtle reaches bedrock
- `expand_mine()`: Remove (no longer needed)
- `gen_next_strip()` → `gen_next_block()`: Find closest unmined block
- `get_closest_free_strip()` → `get_closest_unmined_block()`: Find closest unmined (x, z)
- `pair_turtles_begin()`: Assign block instead of strip
- `solo_turtle_begin()`: Assign block instead of strip
- `go_mine()`: Change to mine down to bedrock instead of along strip

**New Functions Needed:**
- `is_block_mined(x, z)`: Check if block has been mined
- `mark_block_mined(x, z)`: Mark block as completely mined
- `get_bedrock_level()`: Get bedrock Y level (configurable, default -64)

**Data Structure Changes:**
- Replace `state.mine[level][x][orientation]` with `state.mined_blocks[x][z] = true`
- Replace `turtle.strip` with `turtle.block = {x = x, z = z}`
- Remove `turtle.steps_left` (replace with depth tracking if needed)

### 3. Turtle Files Changes

#### `turtle_files/actions.lua`

**New Actions Needed:**
- `mine_to_bedrock(block)`: Mine straight down from surface to bedrock
  - Go to assigned (x, z) coordinate at surface level
  - Mine down, clearing all blocks including ores
  - Stop at bedrock (Y = -64 or config.bedrock_level)
  - Return to surface
  - Clear gravity blocks (gravel/sand) that may fall

**Modified Actions:**
- `go_to_strip()` → `go_to_block()`: Navigate to assigned (x, z) at surface
- Remove `mine_vein()`: Replace with `mine_to_bedrock()`

**New Helper Functions:**
- `mine_column_down()`: Mine straight down from current position to bedrock
  - Check for bedrock before each dig
  - Handle lava, water, gravity blocks
  - Track depth reached
  - Return early if inventory full or fuel low
- `mine_column_up()`: Return to surface (or go up to mine_enter level)
  - Navigate back up the column
  - Handle obstacles (may need to dig if blocks fell)
  - Return to exact (x, z) coordinate at surface
- `detect_bedrock()`: Check if block below is bedrock
  - Use `turtle.inspectDown()` to check block name
  - Return true if bedrock detected
- `handle_lava()`: Deal with lava when mining down
  - Detect lava before digging
  - Place block or skip as appropriate
- `check_inventory_space()`: Verify enough inventory space for descent
  - Estimate blocks to mine (depth)
  - Return true if enough space, false otherwise

### 4. Structured Setup System

#### Setup Layout Constraints

**Reference Point System:**
- `hub_reference`: Central reference block (like current `mine_entrance`)
- All other components positioned relative to this point

**Placement Rules:**
1. **Hub Computer:**
   - Must be within 8 radius blocks north or south of `hub_reference`
   - Same Y coordinate as `hub_reference` (surface level)
   - Validated during startup

2. **Turtle Parking Area:**
   - Located on **west side** of `hub_reference`
   - Turtles line up heading west from reference point
   - Area extends west from `hub_reference.x`

3. **Chests & Stations:**
   - Located on **east side** of `hub_reference`
   - Item drop station: East of reference
   - Refuel station: East of reference
   - Prevents interference with turtle parking

4. **Mining Center:**
   - X, Z: Same as `hub_reference`
   - Y: `hub_reference.y - 2` (2 blocks below surface)
   - This is the center point for mining radius/diameter
   - Starting 2 blocks down prevents interference with surface structures

**Benefits:**
- Predictable setup layout
- Easy to understand placement requirements
- Prevents collisions between turtles and infrastructure
- Clear separation of parking vs. work areas
- Mining center below surface prevents surface interference

#### Validation Functions

**New Functions Needed:**
- `validate_hub_location()`: Check hub computer is within ±8 blocks north/south
- `calculate_mining_center()`: Calculate mining center from hub_reference
- `setup_wizard()`: Guide user through proper placement during installation

### 5. Config Changes

#### `hub_files/config.lua` & `turtle_files/config.lua`

**Add New Config Options:**
```lua
-- Hub reference location (the central reference point for the entire setup)
-- This is the "start block" that everything is positioned relative to
hub_reference = {
    x = 104,  -- X coordinate of the hub reference point
    y = 76,   -- Y coordinate (surface level)
    z = 215   -- Z coordinate of the hub reference point
}

-- Hub computer location (MUST be within 8 blocks north or south of hub_reference)
-- Will be validated during setup
hub_location = {
    x = 104,  -- X coordinate (should match hub_reference.x)
    y = 76,   -- Y coordinate (should match hub_reference.y)
    z = 215   -- Z coordinate (must be within hub_reference.z ± 8)
}

-- Mining center (where mining operations start from)
-- Located 2 blocks below hub_reference to avoid interference
mining_center = {
    x = hub_reference.x,      -- Same X as hub reference
    y = hub_reference.y - 2,  -- 2 blocks below hub reference
    z = hub_reference.z       -- Same Z as hub reference
}

-- Bedrock level (Y coordinate where mining stops)
bedrock_level = -64  -- Minecraft 1.18+ bedrock level

-- Mining area bounds (optional, for limiting world eater area)
-- If not specified, will mine all blocks starting from mining_center outward
-- Radius/diameter is centered on mining_center
mining_area = {
    min_x = -inf,
    max_x = inf,
    min_z = -inf,
    max_z = inf
}

-- Mining radius (optional, alternative to mining_area)
-- If set, creates a circular mining area centered on mining_center
mining_radius = nil  -- Set to number (in blocks) to limit mining to radius, nil for unlimited
```

**Note:** Since we're mining ALL blocks, there's no spacing needed - every (x, z) coordinate gets assigned and mined.

**Structured Setup System:**
- **Hub Reference Point:** The central reference block (like current `mine_entrance`)
- **Hub Computer:** Must be placed within 8 blocks north or south of hub_reference
- **Turtle Parking:** Turtles line up on the **west side** of hub_reference
- **Chests/Stations:** Item drop and refuel stations on the **east side** of hub_reference
- **Mining Center:** Located 2 blocks below hub_reference (prevents interference with surface structures)
- **Mining Area:** Centered on mining_center, expands outward in spiral pattern

**Hub Location Usage:**
- Validates hub computer is in correct position during setup (±8 blocks north/south)
- Can be auto-detected during installation (prompt user to confirm)
- Helps with troubleshooting GPS and navigation issues
- Used for reference in error messages and diagnostics

**Location Structure Updates:**
```lua
locations = {
    -- Hub reference point (central reference)
    hub_reference = {x = c.x+0, y = c.y+0, z = c.z+0},
    
    -- Mining center (2 blocks below hub_reference)
    mining_center = {x = c.x+0, y = c.y-2, z = c.z+0},
    
    -- Mine entrance (turtles descend from here)
    mine_enter = {x = c.x+0, y = c.y+0, z = c.z+0},
    
    -- Mine exit (turtles return here)
    mine_exit = {x = c.x+0, y = c.y+1, z = c.z+1},
    
    -- Item drop station (EAST of hub_reference)
    item_drop = {x = c.x+2, y = c.y+1, z = c.z+1, orientation = 'east'},
    
    -- Refuel station (EAST of hub_reference)
    refuel = {x = c.x+2, y = c.y+1, z = c.z+0, orientation = 'east'},
    
    -- Turtle homes (WEST of hub_reference)
    -- Turtles line up heading west
    greater_home_area = {
        min_x = -inf,
        max_x = c.x-3,  -- West of hub_reference
        min_y = c.y+0,
        max_y = c.y+1,
        min_z = c.z-1,
        max_z = c.z+2
    },
    
    -- Control room area (validates hub computer placement)
    control_room_area = {
        min_x = c.x-8,   -- Can extend west
        max_x = c.x+8,   -- Can extend east
        min_y = c.y+0,
        max_y = c.y+8,
        min_z = c.z-8,   -- Can extend 8 blocks north
        max_z = c.z+8    -- Can extend 8 blocks south
    },
}
```

**Remove/Modify:**
- Remove `mine_levels`: No longer needed (mining all levels)
- Remove `grid_width`: No longer needed (mining all blocks)
- Modify `mission_length`: Not needed for world eater (each block is one mission)
- Keep `fuel_per_unit`, `fuel_padding`: Still needed for fuel management
- Update `mine_entrance` to use `hub_reference` as base
- Update all location calculations to use structured layout

### 5. Fuel Calculation Changes

#### Current:
```lua
state.min_fuel = (basics.distance(state.next_strip, config.locations.mine_enter) + config.mission_length) * 3
```

#### New:
```lua
-- Calculate fuel needed: distance to block + mining depth + return
local surface_y = config.locations.mining_center.y + 2  -- Surface level (2 blocks above mining center)
local distance_to_block = basics.distance(
    {x = block.x, y = surface_y, z = block.z}, 
    config.locations.mine_enter
)
local depth = surface_y - config.bedrock_level  -- Depth from surface to bedrock
state.min_fuel = (distance_to_block + depth * 2) * 3  -- *2 for down and back up
```

**Note:** Mining operations start from `mining_center` (2 blocks below `hub_reference`), but turtles travel to surface level (mining_center.y + 2) before descending.

### 6. Assignment Logic Changes

#### Current Flow:
1. Find closest free strip at a random level
2. Assign strip to turtle pair
3. Turtle goes to strip start position
4. Turtle mines along strip horizontally
5. Update strip progress

#### New Flow:
1. Find closest unmined block (x, z) within mining area (spiral outward from `mining_center`)
2. Assign block to turtle
3. Turtle goes to block (x, z) at surface level (mining_center.y + 2)
4. Turtle mines straight down to bedrock (mines ALL blocks in the column)
5. Mark block as mined when complete
6. Return to surface and get next assignment

**Note:** Mining area is centered on `mining_center` (2 blocks below `hub_reference`), not `hub_reference` itself. This prevents interference with surface infrastructure.

### 7. File Structure Changes

#### Current:
```
/mine/<center_x>,<center_z>/
  <level>/
    <strip_name>  (contains z coordinates or x coordinates)
    main_shaft
  turtles/
    <turtle_id>/
      strip  (contains: level,name,orientation)
      deployed  (contains: steps_left)
```

#### New:
```
/mine/<center_x>,<center_z>/
  mined_blocks/
    <x>,<z>  (empty file, existence means block is mined)
  turtles/
    <turtle_id>/
      block  (contains: x,z)
      deployed  (optional, can track depth reached)
```

### 8. Mining Pattern Changes

#### Current (Strip Mining):
- Mine horizontally along a strip
- Follow ore veins when detected
- Clear gravity blocks
- Move forward along strip

#### New (World Eater):
- Mine vertically down a column
- Mine ALL blocks (not just ores)
- Clear gravity blocks as you go
- Stop at bedrock
- Return to surface

## Implementation Steps

### Phase 0: Installation System Improvements (Can be done in parallel)
1. Create `installer.lua` script
2. Add dual-drive detection and file splitting
3. Add GitHub download support (with pastebin fallback)
4. Add hub location configuration and auto-detection
5. Create installation wizard for setup
6. Test installation on single and dual-drive setups

### Phase 1: Core Data Structure Changes
1. Modify `load_mine()` to load mined blocks instead of strips
2. Create `write_block()` and `is_block_mined()` functions
3. Update file structure handling
4. Add structured setup system (`hub_reference`, `mining_center`)
5. Add `validate_hub_location()` function
6. Update config with new location structure

### Phase 2: Assignment Logic
1. Replace `get_closest_free_strip()` with `get_closest_unmined_block()`
2. Update `pair_turtles_begin()` and `solo_turtle_begin()` to assign blocks
3. Update fuel calculation

### Phase 3: Turtle Actions
1. Create `mine_to_bedrock()` action
2. Replace `go_to_strip()` with `go_to_block()`
3. Remove/modify `mine_vein()` logic

### Phase 4: Integration & Testing
1. Update all references from strips to blocks
2. Test assignment system
3. Test mining down to bedrock
4. Test return and reassignment
5. Test dual-drive installation
6. Test GitHub/pastebin installation methods

### Phase 5: Update System Compatibility
1. Update `turtle_files/update` to handle dual-drive setup
2. Update `hub_files/events.lua` update handler for new file structure
3. Ensure update system works with disk/disk2 split
4. Test update commands (`update <#>`, `hubupdate`)

### Phase 6: Migration & Data Conversion (Optional)
1. Create migration script to convert old strip mine data
2. Convert existing `/mine/<x,z>/<level>/` structure to new format
3. Mark all previously mined areas as "mined blocks"
4. Preserve turtle assignments if possible
5. Provide clear migration instructions

### Phase 7: Cleanup
1. Remove unused strip-related code
2. Update config files
3. Update documentation
4. Create installation guide
5. Create migration guide (if needed)

## Preserved Features

These features should remain unchanged:
- Coal/fuel estimation and management
- Drop-off and refueling logic
- Turtle pairing (if using chunky turtles)
- User commands (on/off, halt, return, etc.)
- Reporting system
- Update system
- GPS navigation
- Calibration

## Edge Cases to Handle

1. **Bedrock Detection**: 
   - Use `turtle.inspectDown()` to check block name
   - If block name contains "bedrock" or matches bedrock block ID, stop mining
   - Alternative: Stop at configurable Y level (bedrock_level)
   - Implementation: Check before each `turtle.digDown()` call

2. **Lava**: 
   - Detect lava with `turtle.inspectDown()` before digging
   - If lava detected, place cobblestone/block below before descending
   - Or skip block and continue (lava will flow, turtle can handle)
   - Keep bucket in inventory for emergency lava removal

3. **Caves**: 
   - Large caves shouldn't be an issue - turtle mines straight down
   - If turtle falls into cave, it should continue mining down from new position
   - May need to handle case where turtle is no longer at assigned (x, z)
   - Update block assignment if turtle position drifts significantly

4. **Inventory Full**: 
   - Check `turtle.getItemCount()` before descending
   - If inventory full before reaching bedrock, return to surface
   - Drop off items, then return to same block to continue
   - Track depth reached in turtle state, resume from that depth

5. **Fuel Running Low**: 
   - Calculate fuel needed before starting: distance + depth*2 + return
   - Check fuel level periodically during descent
   - If fuel insufficient, return to surface early
   - Refuel and return to same block to continue

6. **Gravity Blocks**: 
   - Handle gravel/sand falling during descent
   - After digging down, check if block above fell
   - Clear gravity blocks above turtle before continuing
   - Use existing `clear_gravity_blocks()` function

7. **Water**: 
   - Detect water with `turtle.inspectDown()`
   - If water detected, can mine through it (turtle can dig underwater)
   - Or place block to stop water flow
   - Handle water sources vs flowing water differently

8. **Turtle Gets Stuck**: 
   - If turtle can't move down (bedrock/unbreakable block), mark block as "unmineable"
   - Skip to next block assignment
   - Log error for user review

9. **GPS Loss**: 
   - If GPS unavailable during mining, turtle should return to surface
   - Recalibrate before getting new assignment
   - Don't assign new blocks if GPS is down

10. **Update System Compatibility**:
    - Update system uses `/disk/turtle_files/` path
    - Need to handle dual-drive setup (disk vs disk2)
    - Update scripts need to check both drives
    - Or standardize on disk for turtle files (disk2 only for initial install)

## Installation & Setup Improvements

### 1. Hub Computer Location Configuration

**Add to Config:**
```lua
-- Hub computer location (for reference and validation)
hub_location = {
    x = 104,  -- X coordinate of hub computer
    y = 76,   -- Y coordinate of hub computer (surface level)
    z = 215   -- Z coordinate of hub computer
}
```

**Purpose:**
- Allows system to validate hub computer is in correct location
- Can be used for setup validation
- Helps with troubleshooting GPS issues
- Can be auto-detected during initial setup

### 2. Dual-Drive Installation System

**Problem:** Default floppy disk limit is 512KB, but program exceeds this.

**Solution:** Split installation across 2 disk drives:
- **Drive 1 (disk):** Hub files only (`hub_files/` directory)
- **Drive 2 (disk2):** Turtle files + Pocket files (`turtle_files/`, `pocket_files/`, `turtle.lua`, `pocket.lua`)

**Implementation Changes:**

#### `hub.lua` modifications:
```lua
-- Check for disk2, if not present, fall back to single disk mode
local has_disk2 = peripheral.getType('disk2') ~= nil

if has_disk2 then
    -- Dual drive mode
    -- Hub files from disk
    -- Turtle/pocket files from disk2
else
    -- Single drive mode (backward compatible)
    -- All files from disk
end
```

#### Installation script changes:
- Create installer that detects available drives
- Automatically splits files across drives if 2 drives available
- Falls back to single drive if only 1 available
- Provides clear instructions for dual-drive setup

### 3. Installation Methods

#### Option A: Bootstrap Installer (Recommended)
**Small pastebin script that downloads everything from GitHub**

```lua
-- Simple bootstrap installer (small enough for pastebin)
-- User runs: pastebin get <CODE> install.lua
-- Then: install.lua

-- This script:
-- 1. Detects available disk drives
-- 2. Downloads file manifest from GitHub
-- 3. Downloads all files from GitHub raw URLs
-- 4. Splits files across 2 drives automatically
-- 5. Sets up hub/turtle/pocket as appropriate
```

**Benefits:**
- Single small script (fits in pastebin easily)
- All actual code stored on GitHub (no size limits)
- Automatic dual-drive detection and splitting
- Easy updates (just update GitHub, installer stays same)
- Version control through GitHub

**Implementation:**
- Bootstrap installer (~100-200 lines max)
- Downloads file list from GitHub (manifest.json)
- Downloads each file to appropriate drive
- Validates installation
- Handles errors gracefully

#### Option B: Direct GitHub Installation
```lua
-- GitHub raw file download
-- Requires HTTP API or wget program
wget https://raw.githubusercontent.com/user/repo/main/installer.lua installer.lua
installer.lua
```

**Implementation:**
- Create `installer.lua` that downloads from GitHub
- Use GitHub raw file URLs
- Fallback to pastebin if GitHub unavailable
- Support version tags/branches

#### Option C: Pastebin-Only Installation (Fallback)
```lua
-- Fallback if GitHub unavailable
pastebin get <code> worldeater.lua
worldeater disk
disk/hub.lua
```

**For servers without internet access:**
- Split installer into multiple pastebin codes if needed
- Manual dual-drive setup instructions

### 4. Bootstrap Installer Script Structure

**New file: `install.lua` (Bootstrap Installer)**
```lua
-- Bootstrap installer (small, fits in pastebin)
-- Downloads everything else from GitHub

-- Configuration
local GITHUB_REPO = "user/repo"
local GITHUB_BRANCH = "main"  -- or "master"
local GITHUB_BASE = "https://raw.githubusercontent.com/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH

-- File manifest (downloaded from GitHub)
local MANIFEST_URL = GITHUB_BASE .. "/manifest.json"

-- Drive assignments
local DRIVE_HUB = "disk"      -- Hub files go here
local DRIVE_TURTLE = "disk2" -- Turtle/Pocket files go here

-- Functions:
-- 1. detect_system_type() - Detect if hub/turtle/pocket
-- 2. detect_drives() - Find available disk drives
-- 3. download_file(url, path) - Download file from GitHub
-- 4. download_manifest() - Get file list and assignments
-- 5. install_files() - Download and place files on correct drives
-- 6. validate_installation() - Check all files present
-- 7. setup_wizard() - Configure hub location, etc.
```

**File Manifest Structure (`manifest.json` on GitHub):**
```json
{
  "version": "1.0.0",
  "files": {
    "hub_files/startup.lua": {
      "drive": "hub",
      "path": "hub_files/startup.lua"
    },
    "hub_files/config.lua": {
      "drive": "hub",
      "path": "hub_files/config.lua"
    },
    "turtle_files/startup.lua": {
      "drive": "turtle",
      "path": "turtle_files/startup.lua"
    },
    "turtle.lua": {
      "drive": "turtle",
      "path": "turtle.lua"
    }
  },
  "hub_files": [
    "hub_files/startup.lua",
    "hub_files/config.lua",
    "hub_files/state.lua",
    ...
  ],
  "turtle_files": [
    "turtle_files/startup.lua",
    "turtle_files/config.lua",
    ...
  ],
  "pocket_files": [
    "pocket_files/startup.lua",
    ...
  ]
}
```

**Installation Flow:**
1. User runs: `pastebin get <CODE> install.lua`
2. User runs: `install.lua`
3. Installer detects system type (hub/turtle/pocket)
4. Installer detects available drives (disk, disk2)
5. Downloads manifest.json from GitHub
6. Downloads all files from GitHub based on manifest
7. Splits files across drives automatically:
   - Hub files → disk (or disk if only one drive)
   - Turtle/Pocket files → disk2 (or disk if only one drive)
8. Validates all files downloaded correctly
9. If hub: Runs setup wizard (hub location, GPS validation)
10. Completes installation and prompts to run startup

**Error Handling:**
- Check internet connectivity
- Fallback to pastebin if GitHub unavailable
- Validate disk space
- Check file integrity
- Provide clear error messages

### 5. File Size Optimization

**Strategies to reduce size:**
- Minify Lua files (remove comments, whitespace)
- Compress large config sections
- Split large files if needed
- Use external storage for non-critical files

**Dual-drive benefits:**
- Hub files: ~200-300KB (fits on one disk)
- Turtle/Pocket files: ~200-300KB (fits on second disk)
- Total split across 2 drives fits within limits

## Configuration Migration

### For New Installations:
1. Run bootstrap installer (`install.lua`)
2. Follow setup wizard to configure `hub_reference` location
3. Configure `bedrock_level` and `mining_area` if needed
4. Initialize turtles (they'll get new block assignments)

### For Upgrading from Strip Mining:
1. **Backup existing data:**
   - Copy `/mine/` directory
   - Save config files
   - Note current turtle assignments

2. **Run migration (if available):**
   - Migration script converts strip data to block data
   - Marks all mined strips as mined blocks
   - Preserves turtle state if possible

3. **Manual migration:**
   - Clear old `/mine/<x,z>/<level>/` directories
   - Start fresh with new block-based system
   - Reinitialize all turtles

4. **Reinstall with dual-drive setup:**
   - Use bootstrap installer
   - Files will be split across drives automatically
   - Update config with new options

5. **Reinitialize turtles:**
   - Turtles will get new block assignments
   - Old strip assignments are no longer valid
   - Use `reset <#>` command if needed

## Notes

- The world eater will be more fuel-intensive (mining entire columns)
- Consider adding a "mining radius" limit via `mining_area` config to prevent infinite expansion
- May want to add a "mining depth" option to stop before bedrock if desired
- Since we're mining ALL blocks, no spacing is needed - every block gets assigned
- Assignment pattern: Spiral outward from mine_entrance to find closest unmined block

## Installation Requirements

### Hardware Setup:
1. **Hub Computer:**
   - Advanced Computer
   - Modem (for rednet)
   - Monitor 4x3 (optional, for display)
   - Disk Drive 1 (for hub files)
   - Disk Drive 2 (optional, for turtle/pocket files if single drive insufficient)
   - GPS setup (4 computers at known coordinates)
   - **Placement:** Must be within 8 block radius north or south of hub_reference point

2. **Setup Layout:**
   - **Hub Reference Point:** Mark the central reference block (this is your "start block")
   - **West Side:** Turtle parking area (turtles line up heading west)
   - **East Side:** Item drop and refuel stations (chests and fuel storage)
   - **Mining Center:** 2 blocks directly below hub_reference point
   - **Mining Area:** Expands outward from mining_center in spiral pattern

2. **Turtle Setup:**
   - Advanced Turtle
   - Modem (for rednet)
   - Either Pickaxe or Chunky peripheral (chunk loader)
   - **Placement:** Park on west side of hub_reference point
   - Turtles will automatically find their parking spots during initialization

3. **Dual-Drive Setup (Recommended for servers with 512KB limit):**
   - Place 2 disk drives adjacent to hub computer
   - First drive: Hub files
   - Second drive: Turtle/Pocket files
   - Installer will automatically detect and use both

4. **Setup Wizard:**
   - During installation, system will:
     - Detect hub_reference location (or prompt user to set it)
     - Validate hub computer is within ±8 blocks north/south
     - Calculate mining_center (hub_reference.y - 2)
     - Verify GPS is working
     - Set up initial mining area centered on mining_center

### Installation Commands:

**Method 1: Bootstrap Installer (Recommended - Easiest)**
```bash
# Step 1: Get small bootstrap installer from pastebin
pastebin get <CODE> install.lua

# Step 2: Run installer (downloads everything from GitHub, auto-splits to 2 drives)
install.lua

# Step 3: If hub computer, follow setup wizard
# Step 4: Run startup
disk/hub.lua  # or disk2/hub.lua depending on drive setup
```

**What the installer does:**
- Detects if you're on hub/turtle/pocket computer
- Detects available disk drives (disk, disk2)
- Downloads file manifest from GitHub
- Downloads all files from GitHub raw URLs
- Automatically splits files:
  - Hub files → disk (drive 1)
  - Turtle/Pocket files → disk2 (drive 2)
- Validates installation
- Runs setup wizard for hub computers

**Method 2: Direct GitHub (If HTTP API Available)**
```bash
# Download installer directly from GitHub
wget https://raw.githubusercontent.com/user/repo/main/install.lua install.lua
install.lua
```

**Method 3: Manual Dual-Drive Setup (Fallback)**
```bash
# Only if GitHub/pastebin unavailable
# Manually download and split files across drives
# See manual installation guide
```

**Bootstrap Installer Features:**
- ✅ Small (~100-200 lines, fits in pastebin)
- ✅ Downloads all files from GitHub (no size limits)
- ✅ Auto-detects drives and splits files
- ✅ Handles single or dual-drive setups
- ✅ Validates installation
- ✅ Setup wizard for configuration
- ✅ Error handling and fallbacks

**Bootstrap Installer Implementation:**

The installer (`install.lua`) is a small script that:
1. **Detects System Type:** Automatically detects if running on hub/turtle/pocket computer
2. **Detects Drives:** Finds available disk drives (disk, disk2)
3. **Downloads Manifest:** Gets file list from GitHub (`manifest.json`)
4. **Downloads Files:** Downloads all required files from GitHub raw URLs
5. **Splits Files:** Automatically places files on correct drives:
   - Hub files → disk (drive 1)
   - Turtle/Pocket files → disk2 (drive 2, or disk if only one drive)
6. **Validates:** Checks all files downloaded correctly
7. **Setup Wizard:** Guides hub computer setup (location, GPS validation)

**File Structure:**
- `install.lua` - Bootstrap installer (pastebin-friendly, ~200 lines)
- `manifest.json` - File list and drive assignments (stored on GitHub)
- All other files stored on GitHub repository

**Usage:**
```bash
# User only needs to run 2 commands:
pastebin get <CODE> install.lua
install.lua

# Installer handles everything else automatically!
```

**Benefits:**
- Single small script in pastebin (no size limits for actual code)
- All code version controlled on GitHub
- Easy updates (update GitHub, installer stays same)
- Automatic dual-drive handling
- Works offline with fallback options

