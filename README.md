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

## Download (release binaries)

GitHub Releases ship self-contained archives for each platform. Extract the archive and run the executable from that folder:

- **Linux / macOS** — `speedsx` with SDL2 in `lib/` (no system SDL install required).
- **Windows** — `speedsx.exe` and `SDL2.dll` in the same folder.

```bash
./speedsx --help
./speedsx --version
```

## Building from source

End-user [release archives](#download-release-binaries) bundle SDL2. A **developer build** links against SDL2 on your machine and does not download extra Zig packages at compile time (SDL bindings are vendored in the repo).

### 1. Install Zig

Use **[Zig 0.17.0](https://ziglang.org/download/)** — the same version as [CI](.github/workflows/build.yml). Other 0.17.x versions may work but are not what we test.

```bash
zig version   # should report 0.17.0
```

Install via your package manager only if it ships 0.17.0; otherwise use the official tarball and add `zig` to your `PATH`.

### 2. Install native dependencies

| Platform | Packages / tools |
|----------|------------------|
| **Linux** | SDL2 dev headers, **pkg-config** (required — the build uses pkg-config to find SDL2) |
| **macOS** | SDL2 via Homebrew; Xcode **Command Line Tools** for the linker |
| **Windows** | [MSYS2](https://www.msys2.org/) MinGW64: `SDL2`, `pkg-config` |

**Arch Linux:**
```bash
sudo pacman -S sdl2 pkgconf zig
```

**Ubuntu/Debian:**
```bash
sudo apt install libsdl2-dev pkg-config
# install Zig 0.17.0 separately if apt is too old
```

**macOS:**
```bash
xcode-select --install   # if CLT not installed
brew install sdl2
```

**Windows (MSYS2):** open **MSYS2 MinGW 64-bit** and run:
```bash
pacman -S mingw-w64-x86_64-SDL2 mingw-w64-x86_64-pkg-config
```

Before `zig build` in **Git Bash**, **MSYS2**, or CI-like shells, put MinGW on `PATH` and point pkg-config at SDL2:

```bash
export PATH="/c/tools/msys64/mingw64/bin:/c/tools/msys64/usr/bin:$PATH"
export PKG_CONFIG_PATH="/c/tools/msys64/mingw64/lib/pkgconfig"
```

Adjust paths if MSYS2 is not installed under `C:\tools\msys64`.

### 3. Verify prerequisites

```bash
zig version
pkg-config --modversion sdl2    # Linux/macOS/MSYS2 — should print an SDL2 version
```

If `pkg-config` cannot find SDL2, fix SDL2 dev packages or `PKG_CONFIG_PATH` before building.

### 4. Clone, build, run

```bash
git clone https://github.com/dixiedream/speedsx.git
cd speedsx
zig build
./zig-out/bin/speedsx
```

Output binary: `zig-out/bin/speedsx` (or `speedsx.exe` on Windows).

**Clean rebuild** (after pulling binding or build script changes):

```bash
rm -rf .zig-cache zig-out
zig build
```

**Graphical app:** you need a normal desktop session (Wayland/X11 on Linux, macOS window server, Windows desktop). Headless servers are not supported for running the editor.

### Build options

```bash
# Release build (optimized, stripped)
zig build -Doptimize=ReleaseFast -Dstrip=true

# Core unit tests (same set CI runs)
zig build test-core

# Build and run (forwards CLI args after --)
zig build run
```

Cross-compiling (example):

```bash
zig build -Dtarget=x86_64-windows-gnu    # from Linux, with matching Windows SDL2/pkg-config setup
```

### SDL bindings (maintainers)

SDL2 Zig bindings live under [`src/bindings/`](src/bindings/). To regenerate from [`src/sdl2.h`](src/sdl2.h) after SDL or toolchain header changes, see [`scripts/regenerate-sdl-bindings.sh`](scripts/regenerate-sdl-bindings.sh) and commit the updated files.

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

Pushing a version tag triggers a GitHub Actions workflow that builds optimized, stripped binaries for Linux (x86_64 and ARM64), macOS (Intel and Apple Silicon), and Windows, bundles SDL2 where needed, and publishes a GitHub Release.

```bash
git tag v0.2.5
git push origin v0.2.5
```

Use tags matching `v*`. You can also run the workflow manually via **Actions → Zig CI → Run workflow**.

Add release notes on GitHub after the release is created (the workflow uploads binaries only).

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Roland Corporation for the SPD-SX
- The Zig programming language team
- SDL2 developers
