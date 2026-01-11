# SPD-SX Editor (Zig Port)

A command-line editor for Roland SPD-SX Sampling Pad configuration files, ported from Java to Zig.

## Features

- Load and save SPD-SX configuration from SD card
- List, view, and edit drum kits (up to 300 kits)
- List, view, and edit wave samples
- Manage tags for organizing waves
- Manage kit chains for sequential playback
- Export configurations to new locations

## Building

Requires Zig 0.15.0 or later.

```bash
cd zig-project
zig build
```

The executable will be created at `zig-out/bin/spd-sx-editor`.

### Build Modes

```bash
# Debug build (default)
zig build

# Release build (optimized)
zig build -Doptimize=ReleaseSafe

# Run directly
zig build run -- <arguments>

# Run tests
zig build test
```

## Usage

```
SPD-SX Editor - Roland SPD-SX Configuration Tool

Usage: spd-sx-editor <command> [options]

Commands:
  load <path>           Load configuration from SPD-SX SD card path
  save <path>           Save configuration to path
  list-kits             List all loaded kits
  list-waves            List all loaded waves
  list-tags             List all tags
  list-chains           List all kit chains
  show-kit <index>      Show details of a specific kit
  show-wave <index>     Show details of a specific wave
  rename-kit <idx> <name>  Rename a kit
  rename-wave <idx> <name> Rename a wave
  create-kit            Create a new empty kit
  delete-kit <index>    Delete a kit
  swap-kits <a> <b>     Swap two kits
  export <path>         Export configuration to new location
  help                  Show this help message
  version               Show version information
```

## Examples

### Load configuration from SD card

```bash
# Mount your SPD-SX SD card and load the configuration
spd-sx-editor load /media/SPD_SX

# On macOS
spd-sx-editor load /Volumes/SPD_SX
```

### List and view kits

```bash
# List all kits
spd-sx-editor list-kits

# Show details of kit #0
spd-sx-editor show-kit 0
```

### Edit kits

```bash
# Rename kit #0
spd-sx-editor rename-kit 0 "My Kit"

# Create a new kit
spd-sx-editor create-kit

# Swap kits 0 and 1
spd-sx-editor swap-kits 0 1

# Delete kit #5
spd-sx-editor delete-kit 5
```

### Work with waves

```bash
# List all waves
spd-sx-editor list-waves

# Show wave details
spd-sx-editor show-wave 0

# Rename a wave
spd-sx-editor rename-wave 0 "Kick 1"
```

### Save changes

```bash
# Save back to SD card
spd-sx-editor save /media/SPD_SX

# Export to a different location
spd-sx-editor export /path/to/backup
```

## SPD-SX File Structure

The SPD-SX stores its configuration on an SD card with the following structure:

```
SD_CARD/
├── Roland/           (optional - some firmware versions)
│   └── SPD-SX/
└── SPD-SX/
    ├── KIT/
    │   ├── kit000.spd
    │   ├── kit001.spd
    │   └── ...
    ├── WAVE/
    │   ├── PRM/
    │   │   ├── 00/
    │   │   │   ├── 00.spd
    │   │   │   └── ...
    │   │   └── ...
    │   └── DATA/
    │       └── (WAV files)
    └── SYSTEM/
        ├── tag_list.spd
        └── sysparam.spd
```

## Data Types

### Kit

A kit contains:
- Name (8 characters)
- Sub-name (16 characters)
- Level (0-127)
- Tempo (40.0-300.0 BPM, stored as x10)
- 15 pads with wave assignments and settings
- FX1 and FX2 effect settings

### Pad

Each pad contains:
- Wave assignment (-1 = none)
- Level, Pan
- Play mode, Loop, Trigger type
- MIDI channel and note number
- Sub-wave assignment for layering

### Wave

A wave sample contains:
- Name (12 characters)
- File path
- Tag assignment
- Tempo, beat, and measure info
- Start/end points

### Kit Chain

A kit chain allows sequential kit switching:
- Name (10 characters)
- Up to 20 steps, each referencing a kit

## Project Structure

```
zig-project/
├── build.zig           # Build configuration
├── README.md           # This file
└── src/
    ├── main.zig        # CLI application entry point
    ├── types.zig       # Data structures (Kit, Pad, Wave, etc.)
    ├── encoding.zig    # Character encoding utilities
    ├── storage.zig     # In-memory data storage
    ├── xml.zig         # XML parsing for .spd files
    └── xml_writer.zig  # XML writing for .spd files
```

## Differences from Java Version

This Zig port is a command-line application, while the original Java version had a JavaFX GUI. The core functionality is preserved:

- ✅ Load/save SPD-SX configuration files
- ✅ Edit kit names, settings, and pad assignments
- ✅ Edit wave names and metadata
- ✅ Manage tags and kit chains
- ❌ GUI interface (CLI only)
- ❌ Audio preview (requires audio library integration)

## License

This is a port of the SPD-SX Editor. Please refer to the original project for licensing information.

## Contributing

Contributions are welcome! Please ensure your code:
- Compiles without warnings
- Passes all tests (`zig build test`)
- Follows Zig style conventions
