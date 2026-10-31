#!/usr/bin/env bash
# Bundle SDL2 shared libraries next to the SpeedSX executable for portable releases.
# Usage: bundle-sdl.sh <executable> <staging_dir>
set -euo pipefail

exe="$1"
staging="$2"

if [[ ! -f "$exe" ]]; then
  echo "bundle-sdl.sh: executable not found: $exe" >&2
  exit 1
fi

mkdir -p "$staging/lib"
cp "$exe" "$staging/speedsx"
chmod +x "$staging/speedsx"

os="$(uname -s)"
case "$os" in
  Linux)
    if ! command -v patchelf >/dev/null 2>&1; then
      echo "bundle-sdl.sh: patchelf is required on Linux" >&2
      exit 1
    fi
    while IFS= read -r line; do
      [[ "$line" =~ libSDL2 ]] || continue
      lib_path="$(echo "$line" | awk '{print $3}')"
      [[ -n "$lib_path" && -f "$lib_path" ]] || continue
      real="$(readlink -f "$lib_path")"
      base="$(basename "$real")"
      cp "$real" "$staging/lib/$base"
    done < <(ldd "$staging/speedsx")
    patchelf --set-rpath '$ORIGIN/lib' "$staging/speedsx"
    ;;
  Darwin)
    if ! command -v codesign >/dev/null 2>&1; then
      echo "bundle-sdl.sh: codesign is required on macOS" >&2
      exit 1
    fi
    sdl_line="$(otool -L "$staging/speedsx" | grep -i SDL2 | head -1 || true)"
    if [[ -z "$sdl_line" ]]; then
      echo "bundle-sdl.sh: no SDL2 dependency found in binary" >&2
      exit 1
    fi
    old_path="$(echo "$sdl_line" | awk '{print $1}')"
    [[ -f "$old_path" ]] || {
      echo "bundle-sdl.sh: SDL2 library missing at $old_path" >&2
      exit 1
    }
    dylib_name="$(basename "$old_path")"
    cp "$old_path" "$staging/lib/$dylib_name"
    install_name_tool -id "@loader_path/$dylib_name" "$staging/lib/$dylib_name"
    install_name_tool -change "$old_path" "@loader_path/lib/$dylib_name" "$staging/speedsx"
    install_name_tool -delete_rpath /opt/homebrew/lib "$staging/speedsx" 2>/dev/null || true
    install_name_tool -delete_rpath /usr/local/lib "$staging/speedsx" 2>/dev/null || true
    codesign --force --sign - --timestamp=none "$staging/lib/$dylib_name"
    codesign --force --sign - --timestamp=none "$staging/speedsx"
    ;;
  *)
    echo "bundle-sdl.sh: unsupported OS: $os" >&2
    exit 1
    ;;
esac
