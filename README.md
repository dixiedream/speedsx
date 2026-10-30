# SpeedSX

A fast, native configuration editor for the Roland SPD-SX sampling pad.

![Zig](https://img.shields.io/badge/Zig-0.17-orange)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Overview

SpeedSX provides a graphical interface for editing Roland SPD-SX configurations directly on your computer. Connect your SPD-SX via USB, point SpeedSX at the mounted drive, and edit your kits, samples, and settings with ease.

## Features

- **Kit Management** - Create, edit, duplicate, and organize up to 100 kits
- **Pad Configuration** - Configure all 15 pads (9 main + 4 triggers + 2 footswitches)
- **Sample Library** - Import WAV/AIFF files with automatic format conversion to SPD-SX compatible 44.1kHz 16-bit stereo
- **Drag & Drop** - Assign samples to pads by dragging from the wave list
- **Kit Chains** - Build and edit kit chain sequences
- **Audio Preview** - Play samples directly in the editor
- **FX Settings** - Configure FX1 and FX2 parameters per kit
- **MIDI Configuration** - Set per-pad MIDI notes, channels, and gate times
- **Native Performance** - Built with Zig for fast startup and low memory usage

## Requirements

- **Zig** 0.17 or later
- **SDL2** development libraries

### Installing SDL2

**Arch Linux:**
```bash
sudo pacman -S sdl2
```

**Ubuntu/Debian:**
```bash
sudo apt install libsdl2-dev
```

**macOS:**
```bash
brew install sdl2
```

**Windows:**
Download SDL2 development libraries from [libsdl.org](https://libsdl.org/) and configure your build environment accordingly.

## Building

```bash
git clone https://github.com/yourusername/speedsx.git
cd speedsx
zig build
```

The executable will be in `zig-out/bin/speedsx`.

### Build Options

```bash
# Release build (optimized)
zig build -Doptimize=fast

# Run tests
zig build test

# Build and run
zig build run
```

## Usage

1. Connect your SPD-SX to your computer via USB
2. The SPD-SX will mount as a drive (e.g., `/Volumes/SPD-SX_` on macOS, `/media/usb` on Linux)
3. Launch SpeedSX
4. Enter the path to your SPD-SX configuration folder (usually the `Roland` folder on the drive)
5. Click **Open** to load your configuration

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Ctrl+S` | Save project |
| `Ctrl+O` | Reload project |
| `Ctrl+N` | Add new kit |
| `Ctrl+C` | Copy selected pad |
| `Ctrl+V` | Paste to selected pad |
| `Tab` | Cycle through pads |
| `PageUp/Down` | Navigate kits |
| `1-9` | Trigger pad samples |
| `F1` | Settings |
| `F2` | MIDI Config |
| `F3` | Sample Browser |
| `F4` | Kit Chains |
| `Escape` | Close modal / Cancel |

### Importing Samples

- **Drag & drop** audio files directly onto pads or the wave list
- Use **F3** to open the sample browser and scan a folder for audio files
- Supported formats: WAV, AIFF (automatically converted to SPD-SX format)

## Releasing

Pushing a version tag triggers a GitHub Actions workflow that builds optimized binaries for Linux (x86_64 and ARM64), macOS (Intel and Apple Silicon), and Windows, then publishes a GitHub Release with downloadable archives.

```bash
git tag v0.2.0
git push origin v0.2.0
```

Use tags matching `v*` (for example `v0.2.0`).

**Runtime dependencies for release binaries:**

- **Linux and macOS** — SDL2 must be installed on the system (same as [Installing SDL2](#installing-sdl2) above).
- **Windows** — the release zip includes `SDL2.dll` next to `speedsx.exe`; extract both to the same folder.

Add release notes on GitHub after the release is created (the workflow only uploads binaries).

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Roland Corporation for the SPD-SX
- The Zig programming language team
- SDL2 developers
