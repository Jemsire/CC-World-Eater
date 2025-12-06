# CC-World-Eater

A world eater setup for multi turtle excavation!

A fully automated world-eating mining system for ComputerCraft turtles! Mines entire areas from surface to bedrock using coordinated multi-turtle operations.

## 🚀 Quick Start

### Installation via Pastebin

1. Place your advanced computer next to a disk drive with a blank disk in.
2. Run `pastebin get <PASTEBIN_ID> install.lua`
3. Run `install.lua`
4. Follow the installation prompts to set up your World Eater system

### Installation via GitHub

1. Place your advanced computer next to a disk drive with a blank disk in.
2. Download the installer: `wget https://raw.githubusercontent.com/Jemsire/CC-World-Eater/main/install.lua install.lua`
3. Run `install.lua`
4. Follow the installation prompts to set up your World Eater system

## 📋 Features

- **Multi-Turtle Coordination**: Automatically manages multiple turtles working together
- **Surface to Bedrock Mining**: Excavates entire areas from top to bottom
- **GPS-Based Navigation**: Uses ComputerCraft GPS for precise positioning
- **Single-Drive Setup**: All files fit on a single floppy disk (~213KB used, ~299KB remaining)
- **Flexible Configuration**: Works with or without peripheral mods (Chunky Turtles optional)
- **Real-Time Monitoring**: Hub computer provides status updates and control
- **Queued Update System**: Turtles automatically return home and update one at a time at the disk drive

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

## 📺 Video Tutorials

### Description Video
**Coming Soon**

### Installation Tutorial
**Coming Soon**

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

## 💾 Floppy Disk Size Limit

ComputerCraft has a default limit of 512KB per floppy disk. World Eater currently uses approximately 213KB total, which fits comfortably on a single disk with plenty of room for future growth (~299KB remaining).

If you need more space, you can increase the floppy disk size limit in the mod's config file.

## 🔧 Troubleshooting

After having some chats with folks, it seems like there are some common pitfalls within the turtle setup. If you're getting weird behavior, check this list before posting an issue:

### Common Issues

* **GPS has an incorrect coordinate.** There are 4 computers in the GPS setup, each with an x, y, and z coordinate. If any of these numbers are entered wrong, the GPS will act funky and nothing will work. A good way to test it's working is to enter `gps locate` into any rednet enabled computer or turtle and verify the answer.

* **Hub reference coordinates are incorrect.** The `hub_reference` in the config file is the **center of the prepare area**, not the hub computer location. The hub computer location is automatically detected via GPS at startup. The disk drive location is automatically calculated as 1 block below the hub computer. Make sure your GPS system is working correctly (`gps locate` should return valid coordinates).

* **Turtles are more than 8 blocks away from the mine entrance.** Turtles have to be within the `control_room_area` when they are above ground, otherwise they will get lost and end up in `halt` mode. The `control_room_area` field in the `hub_files/config.lua` file is adjustable to fit whatever size you need. **Note:** If you have a large number of turtles, you may need to increase the control room area to fit a larger turtle parking area.

* **Your downloaded program is not up to date.** Some things, such as compatibility with the new Advanced Peripherals mod, are newer additions and might not exist in the older code. I apologize that there aren't version numbers - I maybe should have a whole releases section but I haven't gotten that far yet. I wasn't expecting such a need for updates. Anyways, you might want to re-download the program periodically, just remember to preserve your config file somehow.

Hopefully that covers a lot of it. Again, let me know if you still can't get the thing to work.

## 📁 Project Structure

```
CC-World-Eater/
├── hub_files/          # Hub computer files
│   ├── config.lua      # Hub configuration
│   ├── monitor.lua     # Status monitoring
│   ├── github_api.lua  # GitHub API helper functions
│   └── ...
├── turtle_files/       # Turtle computer files
│   ├── config.lua      # Turtle configuration
│   ├── turtle_main.lua # Main turtle logic
│   ├── github_api.lua  # GitHub API helper functions
│   └── ...
├── pocket_files/       # Pocket computer files
│   └── ...
├── hub.lua             # Hub startup script
├── turtle.lua          # Turtle startup script
├── pocket.lua          # Pocket startup script
└── install.lua         # Bootstrap installer
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
