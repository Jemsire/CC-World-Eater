inf = 1e309

---==[ MINE ]==---


---==[ WORLD EATER CONFIGURATION ]==---

-- HUB REFERENCE POINT (Central reference for entire setup)
--     This is the central reference block that everything is positioned relative to
--     Hub computer must be within 8 blocks north or south of this point
hub_reference = {x = 104, y = 76, z = 215}

-- MINING CENTER (Where mining operations start from)
--     Located 2 blocks below hub_reference to avoid surface interference
--     Mining area expands outward from this point in a spiral pattern
mining_center = {
    x = hub_reference.x,
    y = hub_reference.y - 2,  -- 2 blocks below hub_reference
    z = hub_reference.z
}

-- BEDROCK LEVEL (Y coordinate where mining stops)
--     Minecraft 1.18+ bedrock is at Y=-64
bedrock_level = -64

-- MINING RADIUS (Primary way to limit mining area - RECOMMENDED)
--     Creates a circular mining area centered on mining_center
--     Radius is in blocks from mining_center (diameter = radius * 2)
--     Set to nil for unlimited mining
--     Example: mining_radius = 50  -- Mines 50 blocks radius (100 block diameter total)
mining_radius = 100  -- Set to number (in blocks) to limit mining to radius

-- MINING AREA BOUNDS (Optional, alternative to mining_radius - uses ABSOLUTE world coordinates)
--     If mining_radius is set, this is IGNORED
--     These are ABSOLUTE world coordinates (not relative to mining_center)
--     Set to nil for unlimited mining
--     NOTE: Use mining_radius instead for easier radius/diameter control
mining_area = {
    min_x = -inf,
    max_x = inf,
    min_z = -inf,
    max_z = inf
}

-- mine_entrance is based on hub_reference (used throughout codebase)
mine_entrance = {x = hub_reference.x, y = hub_reference.y, z = hub_reference.z}
c = mine_entrance


-- WHETHER OR NOT TURTLES NEED PAIRS
--     added this because a good number of
--     people were asking for the ability to
--     disale chunky turtles in case they
--     couldn't access the peripherals mod.
--     WARNING: not using chunky turtles will
--     result in narcoleptic turtles!
use_chunky_turtles = true


-- EXTRA FUEL FOR TURTLES TO BRING ALONG,
-- JUST IN CASE
fuel_padding = 30


-- FUEL PER ITEM 
--     for coal default is 80. Other fuel sources
--     can be used without changing this number,
--     should be fine.
fuel_per_unit = 80


-- TIME AFTER LAST PING TO DECLARE TURTLE
-- DISCONNECTED
turtle_timeout = 5


-- TIME AFTER LAST PING TO DECLARE POCKET
-- COMPUTER DISCONNECTED
pocket_timeout = 5


-- TIME TO WAIT AFTER SENDING TASK WITH NO
-- RESPONSE TO RESEND
task_timeout = 0.5


-- EVERY BLOCK NAME CONTAINING ANY OF THESE
-- STRINGS WILL NOT BE MINED
--     e.g. "chest" will prevent "minecraft:trapped_chest".
--     ore types should not be put on this list,
--     but if not desired should be removed from
--     <orenames> below.
--
-- WHAT HAPPENS WHEN TURTLE HITS A DISALLOWED BLOCK:
--     - Bedrock: Mining stops and returns to surface (expected - reached bottom)
--       * Block is marked as mined
--       * Turtle gets new assignment
--     - Other blocks (chest, computer, etc.): 
--       * Turtle attempts to navigate AROUND the obstacle
--       * Checks adjacent blocks (north, south, east, west) for minable paths
--       * If path found: Continues mining from new position
--       * If no path found: Returns to surface and gets new assignment
--       * This prevents turtles from getting stuck on obstacles
dig_disallow = {
    'computer',
    'chest',
    'chair',
    'spawner',
    'beacon',         
    'enchanting_table', 
    'end_portal_frame', 
    'command_block',   
    'structure_block', 
    'barrier',        
    'bedrock',        
    'end_crystal', 
    'respawn_anchor', 
}


paths = {
    -- THE ORDER IN WHICH TURTLES WILL
    -- TRAVERSE AXES BETWEEN AREAS
    --     recommended not to change this one.
    home_to_home_exit          = 'zyx',
    control_room_to_home_enter = 'yzx',
    home_to_waiting_room       = 'zyx',
    waiting_room_to_mine_exit  = 'yzx',
    mine_enter_to_block        = 'yxz',  -- Path to assigned block for world eater
}


locations = {
    -- THE VARIUS PLACES THE TURTLES MOVE
    -- BETWEEN
    --     coordinates are relative to the
    --     <hub_reference> variable. areas are for
    --     altering turtle behavior to prevent
    --     collisions and stuff.

    -- HUB REFERENCE POINT (Central reference)
    hub_reference = {x = hub_reference.x, y = hub_reference.y, z = hub_reference.z},
    
    -- MINING CENTER (2 blocks below hub_reference)
    mining_center = {x = mining_center.x, y = mining_center.y, z = mining_center.z},

    -- THE BLOCK TURTLES WILL GO TO BEFORE
    -- DECENDING (now based on hub_reference)
    mine_enter = {x = c.x+0, y = c.y+0, z = c.z+0},

     -- THE BLOCK TURTLES WILL COME UP TO
     -- FROM THE MINE
     --     one block higher by default.
    mine_exit = {x = c.x+0, y = c.y+1, z = c.z+1},

     -- THE BLOCK TURTLES GO TO IN ORDER
     -- TO ACCESS THE CHEST FOR ITEMS
    item_drop = {x = c.x+2, y = c.y+1, z = c.z+1, orientation = 'east'},

     -- THE BLOCK TURTLES GO TO IN ORDER
     -- TO ACCESS THE CHEST FOR FUEL
    refuel = {x = c.x+2, y = c.y+1, z = c.z+0, orientation = 'east'},

     -- THE AREA ENCOMPASSING TURTLE HOMES
     --     where they sleep.
    greater_home_area = {
        min_x =  -inf,
        max_x = c.x-3,
        min_y = c.y+0,
        max_y = c.y+1,
        min_z = c.z-1,
        max_z = c.z+2
    },

     -- THE ROOM WHERE THE MAGIC HAPPENS
     --     turtles can find there way home from
     --     here.
     --     Updated for world eater: Hub computer must be within 8 blocks north/south
    control_room_area = {
        min_x = c.x-8,   -- Can extend west
        max_x = c.x+8,   -- Can extend east
        min_y = c.y+0,
        max_y = c.y+8,
        min_z = c.z-8,   -- Can extend 8 blocks north
        max_z = c.z+8    -- Can extend 8 blocks south
    },

     -- WHERE TURTLES QUEUE TO BE PAIRED UP
    waiting_room_line_area = {
        min_x =  -inf,
        max_x = c.x-2,
        min_y = c.y+0,
        max_y = c.y+0,
        min_z =  c.z+0,
        max_z = c.z+1
    },

     -- THE AREA ENCOMPASSING BOTH WHERE
     -- TURTLES PAIR UP, AND THE PATH THEY
     -- TAKE TO THE MINE ENTRANCE
    waiting_room_area = {
        min_x = c.x-2,
        max_x = c.x+0,
        min_y = c.y+0,
        max_y = c.y+0,
        min_z =  c.z+0,
        max_z = c.z+1
    },

     -- THE LOOP TURTLES GO IN BETWEEN THEIR
     -- HOMES, THE ITEM DROP STATION, AND THE
     -- REFUELING STATION
     --     routes work like linked lists.
     --     keys are current positions, and
     --     values are the associated ajecent
     --     blocks to move to. this loop should
     --     be closed, and it should not be
     --     possible for a collision to occur
     --     between a turtle following the loop,
     --     and a turtle pairing, traveling to
     --     the mine entrance, or any other
     --     movement.
    main_loop_route = {

         -- MINING TURTLE HOME ENTER
        [c.x-1 .. ',' .. c.y+1 .. ',' .. c.z-1] = {x = c.x-2, y = c.y+1, z = c.z-1},

         -- MINING TURTLE HOME EXIT
        [c.x-2 .. ',' .. c.y+1 .. ',' .. c.z-1] = {x = c.x-2, y = c.y+1, z = c.z+0},

         -- CHUNKY TURTLE HOME EXIT
        [c.x-2 .. ',' .. c.y+1 .. ',' .. c.z+0] = {x = c.x-2, y = c.y+1, z = c.z+1},

         -- CHUNKY TURTLE HOME ENTER
        [c.x-2 .. ',' .. c.y+1 .. ',' .. c.z+1] = {x = c.x-2, y = c.y+1, z = c.z+2},

        [c.x-2 .. ',' .. c.y+1 .. ',' .. c.z+2] = {x = c.x-1, y = c.y+1, z = c.z+2},
        [c.x-1 .. ',' .. c.y+1 .. ',' .. c.z+2] = {x = c.x+0, y = c.y+1, z = c.z+2},
        [c.x+0 .. ',' .. c.y+1 .. ',' .. c.z+2] = {x = c.x+0, y = c.y+1, z = c.z+1},
        [c.x+0 .. ',' .. c.y+1 .. ',' .. c.z+1] = {x = c.x+1, y = c.y+1, z = c.z+1},

         -- ITEM DROP STATION
        [c.x+1 .. ',' .. c.y+1 .. ',' .. c.z+1] = {x = c.x+2, y = c.y+1, z = c.z+1},

         -- REFUELING STATION
        [c.x+2 .. ',' .. c.y+1 .. ',' .. c.z+1] = {x = c.x+2, y = c.y+1, z = c.z+0},

        [c.x+2 .. ',' .. c.y+1 .. ',' .. c.z+0] = {x = c.x+2, y = c.y+1, z = c.z-1},
        [c.x+2 .. ',' .. c.y+1 .. ',' .. c.z-1] = {x = c.x+1, y = c.y+1, z = c.z-1},
        [c.x+1 .. ',' .. c.y+1 .. ',' .. c.z-1] = {x = c.x+0, y = c.y+1, z = c.z-1},
        [c.x+0 .. ',' .. c.y+1 .. ',' .. c.z-1] = {x = c.x-1, y = c.y+1, z = c.z-1},
    },
}


mining_turtle_locations = {
    -- LOCATIONS THAT ARE SPECIFIC TO
    -- MINING TURTLES

     -- TURTLE HOMES
     --     this is where the first turtle parking
     --     spot will be, and each following will
     --     be in the <increment> direction.
    homes = {x = c.x-3, y = c.y+0, z = c.z-3, increment = 'west'},

     -- THE AREA ENCOMPASSING THE HOME
     -- LINE, AS WELL AS THE PATH TURTLES
     -- TAKE TO GET TO THEIR HOME
    home_area = {
        min_x = -inf,
        max_x = c.x-3,
        min_y = c.y+0,
        max_y = c.y+0,
        min_z = c.z-1,
        max_z = c.z-1
    },

     -- WHERE TURTLES ENTER THE LINE TO
     -- GET TO THEIR HOME
    home_enter = {x = c.x-2, y = c.y+1, z = c.z-1, orientation = 'west'},

     -- WHERE TURTLES EXIT THEIR HOMES
    home_exit = {x = c.x-2, y = c.y+1, z = c.z+0},

     -- WHERE TURTLES WAIT TO BE PAIRED
    waiting_room = {x = c.x-2, y = c.y+0, z = c.z+0},

     -- THE PATH TURTLES WILL TAKE AFTER
     -- PAIRING
    waiting_room_to_mine_enter_route = {
        [c.x-2 .. ',' .. c.y+0 .. ',' .. c.z+0] = {x = c.x-1, y = c.y+0, z = c.z+0},
        [c.x-1 .. ',' .. c.y+0 .. ',' .. c.z+0] = {x = c.x+0, y = c.y+0, z = c.z+0},
    }
}


chunky_turtle_locations = {
    -- LOCATIONS THAT ARE SPECIFIC TO
    -- MINING TURTLES

     -- TURTLE HOMES
     --     this is where the first turtle parking
     --     spot will be, and each following will
     --     be in the <increment> direction.
    homes = {x = c.x-3, y = c.y+0, z = c.z+2, increment = 'west'},

     -- THE AREA ENCOMPASSING THE HOME
     -- LINE, AS WELL AS THE PATH TURTLES
     -- TAKE TO GET TO THEIR HOME
    home_area = {
        min_x = -inf,
        max_x = c.x-3,
        min_y = c.y+0,
        max_y = c.y+0,
        min_z = c.z+2,
        max_z = c.z+2
    },

     -- WHERE TURTLES ENTER THE LINE TO
     -- GET TO THEIR HOME
    home_enter = {x = c.x-2, y = c.y+1, z = c.z+2, orientation = 'west'},

     -- WHERE TURTLES EXIT THEIR HOMES
    home_exit = {x = c.x-2, y = c.y+1, z = c.z+1},

     -- WHERE TURTLES WAIT TO BE PAIRED
    waiting_room = {x = c.x-2, y = c.y+0, z = c.z+1},

     -- THE PATH TURTLES WILL TAKE AFTER
     -- PAIRING
    waiting_room_to_mine_enter_route = {
        [c.x-2 .. ',' .. c.y+0 .. ',' .. c.z+1] = {x = c.x-1, y = c.y+0, z = c.z+1},
        [c.x-1 .. ',' .. c.y+0 .. ',' .. c.z+1] = {x = c.x-1, y = c.y+0, z = c.z+0},
        [c.x-1 .. ',' .. c.y+0 .. ',' .. c.z+0] = {x = c.x+0, y = c.y+0, z = c.z+0},
    }
}


gravitynames = {
    -- ALL BLOCKS AFFECTED BY GRAVITY
    --     if a turtle sees these it will take
    --     extra care to make sure they're delt
    --     with. works at least a lot percent of
    --     the time
    ['minecraft:gravel'] = true,
    ['minecraft:sand'] = true,
}


orenames = {
    -- ALL THE BLOCKS A TURTLE CONSIDERS ORE
    --     block names are exact.
    ['BigReactors:YelloriteOre'] = true,
    ['bigreactors:oreyellorite'] = true,
    ['DraconicEvolution:draconiumDust'] = true,
    ['DraconicEvolution:draconiumOre'] = true,
    ['Forestry:apatite'] = true,
    ['Forestry:resources'] = true,
    ['IC2:blockOreCopper'] = true,
    ['IC2:blockOreLead'] = true,
    ['IC2:blockOreTin'] = true,
    ['IC2:blockOreUran'] = true,
    ['ic2:resource'] = true,
    ['ProjRed|Core:projectred.core.part'] = true,
    ['ProjRed|Exploration:projectred.exploration.ore'] = true,
    ['TConstruct:SearedBrick'] = true,
    ['ThermalFoundation:Ore'] = true,
    ['thermalfoundation:ore'] = true,
    ['thermalfoundation:ore_fluid'] = true,
    ['thaumcraft:ore_amber'] = true,
    ['minecraft:coal'] = true,
    ['minecraft:coal_ore'] = true,
    ['minecraft:diamond'] = true,
    ['minecraft:diamond_ore'] = true,
    ['minecraft:dye'] = true,
    ['minecraft:emerald'] = true,
    ['minecraft:emerald_ore'] = true,
    ['minecraft:gold_ore'] = true,
    ['minecraft:iron_ore'] = true,
    ['minecraft:lapis_ore'] = true,
    ['minecraft:redstone'] = true,
    ['minecraft:redstone_ore'] = true,
    ['galacticraftcore:basic_block_core'] = true,
    ['mekanism:oreblock'] = true,
    ['appliedenergistics2:quartz_ore'] = true
}

blocktags = {
    -- ALL BLOCKS WITH ONE OF THESE TAGS A TURTLE CONSIDERS ORE
    --     most mods categorize ores with the forge:ores tag.
    --     this is an easy way to detect all but a few ores,
    --     which don't posess this exact tag (for example certus quartzfrom AE2)
    ['forge:ores'] = true,
    -- adds Certus Quartz and Charged Certus Quartz
    ['forge:ores/certus_quartz'] = true
}

fuelnames = {
    -- ITEMS THE TURTLE CONSIDERS FUEL
    -- CC:Tweaked turtles can use any furnace fuel
    -- Fuel value = (furnace burn time * 5) / 100 movements
    
    -- Common vanilla fuels
    ['minecraft:coal'] = true,           -- 80 movements
    ['minecraft:charcoal'] = true,       -- 80 movements
    ['minecraft:lava_bucket'] = true,    -- 1,000 movements (best efficiency)
    ['minecraft:blaze_rod'] = true,      -- 120 movements
    ['minecraft:log'] = true,            -- 15 movements
    ['minecraft:log2'] = true,           -- 15 movements (acacia/dark oak)
    ['minecraft:planks'] = true,         -- 15 movements
    ['minecraft:stick'] = true,          -- 5 movements
    ['minecraft:wooden_sword'] = true,   -- 10 movements
    ['minecraft:wooden_pickaxe'] = true, -- 10 movements
    ['minecraft:wooden_axe'] = true,     -- 10 movements
    ['minecraft:wooden_shovel'] = true,  -- 10 movements
    ['minecraft:wooden_hoe'] = true,     -- 10 movements
    ['minecraft:sapling'] = true,        -- 5 movements
    ['minecraft:wood'] = true,           -- 15 movements
    
    -- Note: Modded fuels that work as furnace fuel will also work for turtles
    -- Common modded fuels include:
    -- - Coal Coke (Railcraft): 160 movements
    -- - Peat (Forestry): 80 movements
    -- - Any modded item with furnace fuel value
}


---==[ SCREEN ]==---


-- MAXIMUM ZOOM OUT (INVERSE) OF THE
-- MAP SCREEN
monitor_max_zoom_level = 5


-- DEFAULT ZOOM OF THE MAP SCREEN
--     0 is [1 pixel : 1 block]
default_monitor_zoom_level = 0


-- CENTER OF THE MAP SCREEN
--     probably want the mine center
default_monitor_location = {x = c.x, z = c.z}
