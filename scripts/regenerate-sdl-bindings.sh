#!/usr/bin/env bash
# Regenerate src/bindings/sdl2.zig from SDL2 headers (requires translate_c in build.zig.zon temporarily
# or a local translate-c install). After regeneration, copy c_builtins.zig and helpers.zig from the
# translate_c 2.0.0 package lib/ if those files changed.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

cache_sdl="$(find .zig-cache/o -name sdl2.zig -newer src/sdl2.h 2>/dev/null | head -1)"
if [[ -z "$cache_sdl" ]]; then
  echo "Running zig build to generate bindings..."
  zig build
  cache_sdl="$(find .zig-cache/o -name sdl2.zig 2>/dev/null | head -1)"
fi

if [[ -z "$cache_sdl" || ! -f "$cache_sdl" ]]; then
  echo "Could not find generated sdl2.zig under .zig-cache/o" >&2
  exit 1
fi

mkdir -p src/bindings
cp "$cache_sdl" src/bindings/sdl2.zig
echo "Updated src/bindings/sdl2.zig from $cache_sdl"
