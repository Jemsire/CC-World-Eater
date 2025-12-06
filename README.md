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
- **Dual-Drive Support**: Handles floppy disk size limitations with automatic dual-drive setup
- **Flexible Configuration**: Works with or without peripheral mods (Chunky Turtles optional)
- **Real-Time Monitoring**: Hub computer provides status updates and control

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
[![World Eater Description](https://img.youtube.com/vi/2I2VXl9Pg6Q/0.jpg)](https://www.youtube.com/watch?v=2I2VXl9Pg6Q)

### Installation Tutorial
[![World Eater Tutorial](https://img.youtube.com/vi/2DTP1LXuiCg/0.jpg)](https://www.youtube.com/watch?v=2DTP1LXuiCg)

## 🎮 User Commands

Control your World Eater system with these commands:

### System Control
- `on` / `go` - Start the mining operation
- `off` / `stop` - Stop the mining operation

### Individual Turtle Control
- `turtle <#> <action>` - Control a specific turtle
- `update <#>` - Update a turtle's code
- `reboot <#>` - Reboot a turtle
- `shutdown <#>` - Shutdown a turtle
- `reset <#>` - Reset a turtle's state
- `clear <#>` - Clear a turtle's inventory
- `halt <#>` - Halt a turtle's current operation
- `return <#>` - Return a turtle to base

### Hub Control
- `hubupdate` - Update hub computer code
- `hubreboot` - Reboot hub computer
- `hubshutdown` - Shutdown hub computer

> **Tip:** Use `*` as notation for all turtles (e.g., `reboot *` reboots all turtles)

## 🔄 Updating from GitHub

All systems can be updated directly from the GitHub repository. Updates automatically preserve your configuration files.

### Hub Computer Update

From the hub computer, run:
```lua
disk/hub_files/update
```

To also update config files (not recommended unless you want to reset your settings):
```lua
disk/hub_files/update force-config
```

### Turtle Update

From a turtle computer, run:
```lua
disk/turtle_files/update
-- or if using disk2:
disk2/turtle_files/update
```

To also update config files:
```lua
disk/turtle_files/update force-config
```

### Pocket Computer Update

From a pocket computer, run:
```lua
disk/pocket_files/update
-- or if using disk2:
disk2/pocket_files/update
```

To also update config files:
```lua
disk/pocket_files/update force-config
```

**Note:** By default, config files (`config.lua` and `info.lua`) are **not** updated to preserve your settings. Use `force-config` only if you want to reset to default configurations.

## 💾 Floppy Disk Size Limit

There's a built-in limit in ComputerCraft for how much data a floppy disk can store, and World Eater exceeds this limit. The installer supports dual-drive installation to work around this:

1. **Increase disk size** (Preferred): Increase floppy disk size in the mod's config file if you have access to it.
2. **Dual-drive setup**: Place two disk drives with blank disks next to your hub computer. The installer will automatically distribute files across both drives:
   - Hub files → First drive (`disk`)
   - Turtle/Pocket files → Second drive (`disk2`)

The installer script (`install.lua`) handles file distribution automatically, allowing you to use the full program even with the default 512KB disk limit.

## 🔧 Troubleshooting

After having some chats with folks, it seems like there are some common pitfalls within the turtle setup. If you're getting weird behavior, check this list before posting an issue:

### Common Issues

* **GPS has an incorrect coordinate.** There are 4 computers in the GPS setup, each with an x, y, and z coordinate. If any of these numbers are entered wrong, the GPS will act funky and nothing will work. A good way to test it's working is to enter `gps locate` into any rednet enabled computer or turtle and verify the answer.

* **Mine entrance has an incorrect y value.** Similarly, the position of `mine_entrance` is essential, and must have the correct y value of the block directly above the ground (same as the disk drive in the videos). If the y value is off, I don't quite know what will happen.

* **Turtles are more than 8 blocks away from the mine entrance.** Turtles have to be within the `control_room_area` when they are above ground, otherwise they will get lost and end up in `halt` mode. So if your disk drive is 9 or more blocks away from the entrance, the turtles will just sit there not doing anything after you initialize them. The `control_room_area` field in the `hub_files/config.lua` file is adjustable to fit whatever size you need. **Note:** If you have a large number of turtles, you may need to increase the control room area to fit a larger turtle parking area.

* **Your downloaded program is not up to date.** Some things, such as compatibility with the new Advanced Peripherals mod, are newer additions and might not exist in the older code. I apologize that there aren't version numbers - I maybe should have a whole releases section but I haven't gotten that far yet. I wasn't expecting such a need for updates. Anyways, you might want to re-download the program periodically, just remember to preserve your config file somehow.

Hopefully that covers a lot of it. Again, let me know if you still can't get the thing to work.

## 📁 Project Structure

```
CC-World-Eater/
├── hub_files/          # Hub computer files
│   ├── config.lua      # Hub configuration
│   ├── monitor.lua     # Status monitoring
│   └── ...
├── turtle_files/       # Turtle computer files
│   ├── config.lua      # Turtle configuration
│   ├── turtle_main.lua # Main turtle logic
│   └── ...
├── pocket_files/       # Pocket computer files
│   └── ...
├── hub.lua             # Hub startup script
├── turtle.lua          # Turtle startup script
├── pocket.lua          # Pocket startup script
├── install.lua         # Bootstrap installer
└── manifest.json       # File manifest for installer
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- CC Tweaked for the amazing ComputerCraft implementation
- Advanced Peripherals / Peripherals Plus One for enhanced turtle capabilities
- All the community members who have tested and provided feedback

---

**Made for ComputerCraft / CC Tweaked**
