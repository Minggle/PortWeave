#!/usr/bin/env bash
set -euo pipefail

if ! command -v rsvg-convert >/dev/null; then
  echo 'Install librsvg to generate PortWeave icons.' >&2
  exit 1
fi
source_dir=assets_source/images/portweave
asset_dir=assets/images/portweave
appicon_dir=macos/Runner/Assets.xcassets/AppIcon.appiconset
scratch=$(mktemp -d "${TMPDIR:-/tmp}/portweave-icons.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$asset_dir"
for size in 16 32 64 128 256 512 1024; do
  rsvg-convert -w "$size" -h "$size" "$source_dir/icon.svg" -o "$appicon_dir/app_icon_$size.png"
done
rsvg-convert -w 512 -h 512 "$source_dir/icon.svg" -o "$asset_dir/icon.png"
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
done
