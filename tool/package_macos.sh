#!/usr/bin/env bash
set -euo pipefail

version=${1:?Usage: bash tool/package_macos.sh VERSION ARCH [APP_PATH]}
arch=${2:?Expected arm64 or amd64}
app=${3:-build/macos/Build/Products/Release/FlClash.app}
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
  echo 'Expected a numeric version with an optional prerelease suffix' >&2
  exit 1
fi
case "$arch" in
  arm64) slice=arm64 ;;
  amd64) slice=x86_64 ;;
  *) echo 'Expected arm64 or amd64' >&2; exit 1 ;;
esac
if [[ ! -x "$app/Contents/MacOS/FlClash" || ! -x "$app/Contents/MacOS/FlClashCore" ]]; then
  echo 'The app and Core must both be executable' >&2
  exit 1
fi
for binary in \
  "$app/Contents/MacOS/FlClash" \
  "$app/Contents/MacOS/FlClashCore" \
  "$app/Contents/Frameworks/FlutterMacOS.framework/FlutterMacOS" \
  "$app/Contents/Frameworks/App.framework/App" \
  "$app/Contents/Frameworks/rust_api.framework/rust_api"; do
  if [[ ! -f "$binary" ]]; then
    echo "Missing binary: $binary" >&2
    exit 1
  fi
  lipo "$binary" -verify_arch "$slice"
done
codesign --verify --deep --strict "$app"
stage=$(mktemp -d "${TMPDIR:-/tmp}/flclash-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/FlClash.app"
ln -s /Applications "$stage/Applications"
mkdir -p dist
name="FlClash-$version-macos-$arch.dmg"
hdiutil create -volname FlClash -srcfolder "$stage" -format UDZO "dist/$name"
hdiutil verify "dist/$name"
shasum -a 256 "dist/$name" | sed 's@  dist/@  @' > "dist/SHA256SUMS-macos-$arch"
