# CC-World-Eater

[![GitHub release](https://img.shields.io/github/v/release/Jemsire/CC-World-Eater?style=flat-square)](https://github.com/Jemsire/CC-World-Eater/releases)
[![License](https://img.shields.io/github/license/Jemsire/CC-World-Eater?style=flat-square)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/Jemsire/CC-World-Eater?style=flat-square)](https://github.com/Jemsire/CC-World-Eater/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/Jemsire/CC-World-Eater?style=flat-square)](https://github.com/Jemsire/CC-World-Eater/network/members)
[![GitHub issues](https://img.shields.io/github/issues/Jemsire/CC-World-Eater?style=flat-square)](https://github.com/Jemsire/CC-World-Eater/issues)
[![Discord](https://img.shields.io/discord/195687811733651456?style=flat-square&logo=discord&logoColor=white&label=Discord&color=5865F2)](https://discord.jemsire.com/)

A world eater setup for multi turtle excavation!

A fully automated world-eating mining system for ComputerCraft turtles! Mines entire areas from surface to bedrock using coordinated multi-turtle operations.

## 🚀 Quick Start

### Prep Area (Setup)
![Prep area (Setup)](assets/images/prep-area.png)
> 8 blocks each direction from center block(Stone border shown is 19x19)
> Left and right should be left clear when setting up turtles
> Computer can be built anywhere south or north of the main center block
> From center block mine down a block and 1 block south of the center block
> Prep at least 1 pair if using chunk turtles or 1 miner if not
> Top chest is a fuel chest
> Lower chest is the dump chest so make sure it has lots of space or a storage system attached.

### Main Computer (Setup)
![Main Computer (Setup)](assets/images/computer-setup.png)
> Drive MUST be one block below computer
> Wireless modem should be on top to save space.
> Monitors are 4 long by 3 tall (4x3)

### Installation via GitHub(Recommended Method)

1. Build the setup
2. Open the main hub computer
3. Download the installer by running: `wget https://raw.githubusercontent.com/Jemsire/CC-World-Eater/main/install.lua install.lua`
4. Type `install.lua` and hit enter to run
5. Follow the installation prompts to set up your World Eater system

### Installation via Pastebin

1. Build the setup
2. Open the main hub computer
3. Upload the install.lua as a [pastebin](https://pastebin.com/) and copy your code/ID(recommend 10 minute deletion time)
3. Run `pastebin get <PASTEBIN_ID> install.lua`
4. Type `install.lua` and hit enter to run
5. Follow the installation prompts to set up your World Eater system


## 📋 Features

- **Block-Based Column Mining**: Each turtle mines complete columns (x, z coordinates) from surface to bedrock, ensuring thorough excavation
- **Multi-Turtle Coordination**: Automatically manages multiple turtles working together in parallel
- **Surface to Bedrock Mining**: Excavates entire areas from top to bottom (configurable bedrock level)
- **Spiral Mining Pattern**: Mines outward in a spiral pattern from the mining center for efficient coverage
- **GPS-Based Navigation**: Uses ComputerCraft GPS for precise positioning and auto-detection of hub location
- **Mining Radius Control**: Configure mining area with radius limits or unlimited expansion
- **Obstacle Avoidance**: Turtles automatically navigate around protected blocks (chests, computers, spawners, etc.)
- **Auto-Detection**: Hub computer location and disk drive position are automatically detected via GPS
- **Single-Drive Setup**: All files fit on a single floppy disk (~213KB used, ~299KB remaining)
- **Flexible Configuration**: Works with or without peripheral mods (Chunky Turtles optional)
- **Real-Time Monitoring**: Hub computer provides status updates, turtle views, and control interface
- **Queued Update System**: Turtles automatically return home and update one at a time at the disk drive
- **GitHub Integration**: Direct updates from GitHub repository with automatic version tracking
- **Version Management**: Separate version tracking for hub and turtle systems (see `hub_files/version.lua` and `turtle_files/version.lua`)
- **Installation Wizard**: Interactive setup wizard guides you through configuration

## 🎮 Compatibility

### Required Mods

- **CC Tweaked** - [CurseForge](https://www.curseforge.com/minecraft/mc-mods/cc-tweaked)

### Optional Peripherals (Recommended)

**For Minecraft 1.16+**
- **Advanced Peripherals** - [CurseForge](https://www.curseforge.com/minecraft/mc-mods/advanced-peripherals)

**For Minecraft 1.12**
- **Peripherals Plus One** - [GitHub](https://github.com/rolandoislas/PeripheralsPlusOne)
- **The Framework** (Required by PeripheralsPlusOne) - [CurseForge](https://www.curseforge.com/minecraft/mc-mods/the-framework)

### Play with or without Peripherals

I highly recommend using a peripherals mod with chunky turtles, but upon popular request I added the ability to disable the need for chunky turtle pairs. Just go to the config and set `use_chunky_turtles = false`.

## ⚙️ Configuration

The World Eater system is highly configurable through `hub_files/config.lua`. Key settings include:

### Mining Area Configuration

- **`mining_radius`**: Set a circular mining radius (in blocks) from the mining center. Set to `nil` for unlimited mining.
  ```lua
  mining_radius = 100  -- Mines 100 blocks radius (200 block diameter)
  ```

- **`bedrock_level`**: Y coordinate where mining stops (default: `-64` for Minecraft 1.18+)
  ```lua
  bedrock_level = -64
  ```

- **`hub_reference`**: Central reference point for the entire setup (center of prep area)
  ```lua
  hub_reference = {x = 104, y = 76, z = 215}
  ```

### Turtle Behavior

- **`use_chunky_turtles`**: Enable/disable chunky turtle pairs (default: `true`)
- **`fuel_padding`**: Extra fuel turtles bring along as safety margin (default: `30`)
- **`fuel_per_unit`**: Fuel value per fuel item (default: `80` for coal)

### Protected Blocks

Blocks containing these strings will not be mined (turtles navigate around them):
- `computer`, `chest`, `spawner`, `beacon`, `enchanting_table`, `command_block`, `bedrock`, etc.

Configure in `dig_disallow` table in `hub_files/config.lua`.

### Auto-Detection

- **Hub Location**: Automatically detected via GPS at startup (must be within 8 blocks north/south of `hub_reference`)
- **Disk Drive**: Automatically calculated as 1 block below hub computer
- **Mining Center**: Automatically set to 2 blocks below `hub_reference`

> **Note**: See `hub_files/config.lua` for all available configuration options and detailed comments.

## 📺 Video Tutorials

### Description Video
**Coming Soon**

### Installation Tutorial
**Coming Soon**

## 📸 Screenshots

![Main Screen](assets/images/main-screen.png)
> Main mining screen to show whats complete and whats not.
![Turtle View](assets/images/turtle-menu.png)
> View each turtle individually for debugging or controlling manually.
![Auto Updater](assets/images/auto-update.png)
> Auto updater that grabs from github for latest updates easily!
![Settings Menu](assets/images/computer-setup.png)
> Settings menu allows you to mass send commands to turtles and turn it on or off.

## 🎮 User Commands

Control your World Eater system with these commands:

### System Control
- `on` / `go` - Start the mining operation
- `off` / `stop` - Stop the mining operation

### Individual Turtle Control
- `turtle <#> <action>` - Control a specific turtle
- `reboot <#>` - Reboot a turtle
- `shutdown <#>` - Shutdown a turtle
- `reset <#>` - Reset a turtle's state
- `clear <#>` - Clear a turtle's inventory
- `halt <#>` - Halt a turtle's current operation
- `return <#>` - Return a turtle to base

**Note:** Turtles are updated automatically when the hub runs `update` - no individual turtle update command needed.

### Hub Control
- `update` - Update hub computer code and all turtles (when run without turtle ID)
- `reboot` - Reboot hub computer (when run without turtle ID)
- `shutdown` - Shutdown hub computer (when run without turtle ID)

> **Tip:** Use `*` as notation for all turtles (e.g., `reboot *` reboots all turtles)

## 🔄 Updating from GitHub

All systems can be updated directly from the GitHub repository. Updates automatically preserve your configuration files.

### Hub Computer Update (Updates Hub + All Turtles)

From the hub computer, simply type:
```
update
```

This will update both the hub computer and all connected turtles automatically. The update system will:
1. Queue all turtles for update
2. Send each turtle home (if not already there)
3. Have turtles navigate to the disk drive one at a time
4. Update each turtle sequentially (prevents conflicts)
5. Update the hub computer after all turtles complete

**Note:** Turtles must be able to navigate back to the hub area for updates. If a turtle is too far away or stuck, you may need to manually return it first using the `return <#>` command.

To update via the update script directly (hub only):
```lua
disk/hub_files/update
```

To also update config files (not recommended unless you want to reset your settings):
```lua
disk/hub_files/update force-config
```

### Turtle Update

Turtles automatically update when the hub runs `update`. They copy files directly from the hub's disk drive (no GitHub download needed). Turtles always update their config files to stay in sync with the hub's configuration.

**Note:** Turtles do not have individual update commands - they are updated automatically when the hub updates.

### Pocket Computer Update

From a pocket computer, run:
```lua
disk/pocket_files/update
```

To also update config files:
```lua
disk/pocket_files/update force-config
```

**Note:** 
- Hub update: By default, config files (`config.lua` and `info.lua`) are **not** updated to preserve your settings. Use `force-config` only if you want to reset to default configurations.
- Turtle update: Turtles **always** update their config files when updating to stay in sync with the hub's configuration.

## 💾 Storage & Installation

### Floppy Disk Size Limit

ComputerCraft has a default limit of 512KB per floppy disk. World Eater currently uses approximately 213KB total, which fits comfortably on a single disk with plenty of room for future growth (~299KB remaining).

If you need more space, you can increase the floppy disk size limit in the mod's config file.

### Installation Methods

The installer supports multiple methods:
- **GitHub Download** (Recommended): Direct download from repository
- **Pastebin Fallback**: For environments without internet access
- **Interactive Wizard**: Guides you through hub reference setup and configuration

The installer automatically:
- Detects system type (hub/turtle/pocket/chunky)
- Downloads appropriate files
- Sets up file structure on disk drive
- Validates hub location via GPS

## 🔧 Troubleshooting

After having some chats with folks, it seems like there are some common pitfalls within the turtle setup. If you're getting weird behavior, check this list before posting an issue:

### Common Issues

* **GPS has an incorrect coordinate.** There are 4 computers in the GPS setup, each with an x, y, and z coordinate. If any of these numbers are entered wrong, the GPS will act funky and nothing will work. A good way to test it's working is to enter `gps locate` into any rednet enabled computer or turtle and verify the answer.

* **Hub reference coordinates are incorrect.** The `hub_reference` in the config file is the **center of the prepare area**, not the hub computer location. The hub computer location is automatically detected via GPS at startup. The disk drive location is automatically calculated as 1 block below the hub computer. Make sure your GPS system is working correctly (`gps locate` should return valid coordinates).

* **Turtles are more than 8 blocks away from the mine entrance.** Turtles have to be within the `control_room_area` when they are above ground, otherwise they will get lost and end up in `halt` mode. The `control_room_area` field in the `hub_files/config.lua` file is adjustable to fit whatever size you need. **Note:** If you have a large number of turtles, you may need to increase the control room area to fit a larger turtle parking area.

* **Mining radius too large or unlimited.** If you set `mining_radius = nil` or a very large radius, the system will attempt to mine an enormous area. Consider setting a reasonable radius limit in `hub_files/config.lua`.

* **Protected blocks blocking progress.** If turtles keep getting stuck on the same blocks, those blocks may be in the `dig_disallow` list. Check `hub_files/config.lua` and remove any blocks you want mined (except bedrock, which should always be protected).

* **Version mismatch between hub and turtles.** The system tracks versions separately for hub and turtles. Run `update` from the hub to ensure all systems are synchronized.

Hopefully that covers a lot of it. Again, let me know if you still can't get the thing to work.

## 📁 Project Structure

```
CC-World-Eater/
├── hub_files/          # Hub computer files
│   ├── config.lua      # Hub configuration (mining settings, locations, etc.)
│   ├── monitor.lua     # Status monitoring and UI
│   ├── mine_manager.lua # Mining assignment and block tracking
│   ├── github_api.lua  # GitHub API helper functions
│   ├── version.lua     # Hub version tracking
│   └── ...
├── turtle_files/       # Turtle computer files
│   ├── config.lua      # Turtle configuration
│   ├── turtle_main.lua # Main turtle logic
│   ├── actions.lua     # Mining actions (go_to_block, mine_to_bedrock, etc.)
│   ├── version.lua     # Turtle version tracking
│   └── ...
├── pocket_files/       # Pocket computer files
│   └── ...
├── assets/             # Images and assets for documentation
│   └── images/         # Screenshots and setup images
├── hub.lua             # Hub startup script
├── turtle.lua          # Turtle startup script
├── pocket.lua          # Pocket startup script
└── install.lua         # Bootstrap installer with setup wizard
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Mastermine](https://github.com/merlinlikethewizard/Mastermine) - The original script that this project was reworked from
- CC Tweaked for the amazing ComputerCraft implementation
- Advanced Peripherals / Peripherals Plus One for enhanced turtle capabilities
- All the community members who have tested and provided feedback

---

**Made for ComputerCraft / CC Tweaked**
