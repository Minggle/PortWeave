#!/usr/bin/env bash
set -euo pipefail

if ! command -v rsvg-convert >/dev/null; then
  echo 'Install librsvg to generate PortWeave icons.' >&2
  exit 1
fi
if ! command -v python3 >/dev/null; then
  echo 'python3 is required to pack Windows ICO files.' >&2
  exit 1
fi
source_dir=assets_source/images/portweave
asset_dir=assets/images/portweave
appicon_dir=macos/Runner/Assets.xcassets/AppIcon.appiconset
win_appicon=windows/runner/resources/app_icon.ico
win_tray_dir=$asset_dir/tray/windows
scratch=$(mktemp -d "${TMPDIR:-/tmp}/portweave-icons.XXXXXX")
trap 'rm -rf "$scratch"' EXIT

pack_ico() {
  local output=$1
  shift
  python3 - "$output" "$@" <<'PY'
import pathlib, struct, sys

out = pathlib.Path(sys.argv[1])
entries = []
for item in sys.argv[2:]:
    size_s, path_s = item.split(":", 1)
    entries.append((int(size_s), pathlib.Path(path_s).read_bytes()))
entries.sort(key=lambda e: e[0])
header = struct.pack("<HHH", 0, 1, len(entries))
offset = 6 + 16 * len(entries)
directory = bytearray()
images = bytearray()
for size, png in entries:
    dim = 0 if size == 256 else size
    directory += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(png), offset)
    images += png
    offset += len(png)
out.parent.mkdir(parents=True, exist_ok=True)
out.write_bytes(header + directory + images)
PY
}

mkdir -p "$asset_dir" "$win_tray_dir"
for size in 16 32 64 128 256 512 1024; do
  rsvg-convert -w "$size" -h "$size" "$source_dir/icon.svg" -o "$appicon_dir/app_icon_$size.png"
done
rsvg-convert -w 512 -h 512 "$source_dir/icon.svg" -o "$asset_dir/icon.png"

win_app_args=()
for size in 16 20 24 32 40 48 64 96 128 256; do
  png="$scratch/app_$size.png"
  rsvg-convert -w "$size" -h "$size" "$source_dir/icon.svg" -o "$png"
  win_app_args+=("$size:$png")
done
pack_ico "$win_appicon" "${win_app_args[@]}"

for status in 1 2 3 4; do
  case "$status" in
    1) color='#697889' ;;
    2) color='#00A990' ;;
    3) color='#5278E8' ;;
    4) color='#DC9A26' ;;
  esac
  source="$source_dir/glyph.svg"
  if [[ "$status" == 4 ]]; then source="$source_dir/safe.svg"; fi
  sed "s/#000000/$color/g" "$source" > "$scratch/color.svg"
  for scale in 1 2 3 4; do
    suffix="/$scale.0x"
    if [[ "$scale" == 1 ]]; then suffix=''; fi
    for mode in color monochrome; do
      if [[ "$mode" == monochrome && "$status" != 1 && "$status" != 4 ]]; then continue; fi
      input="$source"
      if [[ "$mode" == color ]]; then input="$scratch/color.svg"; fi
      output="$asset_dir/tray/$mode$suffix"
      mkdir -p "$output"
      rsvg-convert -w "$((18 * scale))" -h "$((18 * scale))" "$input" -o "$output/status_$status.png"
    done
  done
  win_tray_args=()
  for size in 16 20 24 32 40 48 64; do
    png="$scratch/tray_${status}_${size}.png"
    rsvg-convert -w "$size" -h "$size" "$scratch/color.svg" -o "$png"
    win_tray_args+=("$size:$png")
  done
  pack_ico "$win_tray_dir/status_$status.ico" "${win_tray_args[@]}"
done
