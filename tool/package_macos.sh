#!/usr/bin/env bash
set -euo pipefail

version=${1:?Usage: bash tool/package_macos.sh VERSION ARCH [APP_PATH]}
arch=${2:?Expected arm64 or amd64}
app=${3:-build/macos/Build/Products/Release/PortWeave.app}
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
  echo 'Expected a numeric version with an optional prerelease suffix' >&2
  exit 1
fi
case "$arch" in
  arm64) slice=arm64 ;;
  amd64) slice=x86_64 ;;
  *) echo 'Expected arm64 or amd64' >&2; exit 1 ;;
esac
plist="$app/Contents/Info.plist"
for pair in 'CFBundleName PortWeave' 'CFBundleExecutable PortWeave' 'CFBundleIdentifier io.github.minggle.portweave'; do
  key=${pair%% *}
  expected=${pair#* }
  if [[ "$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist")" != "$expected" ]]; then
    echo "Unexpected $key; refusing to package an app with a conflicting identity" >&2
    exit 1
  fi
done
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:0' "$plist")" != 'portweave' ]] ||
  /usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:1' "$plist" >/dev/null 2>&1 ||
  /usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:1' "$plist" >/dev/null 2>&1; then
  echo 'Expected only the portweave URL scheme' >&2
  exit 1
fi
icon=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$plist")
if [[ "$icon" != *.icns ]]; then icon="$icon.icns"; fi
if [[ -z "$icon" || ! -f "$app/Contents/Resources/$icon" ]]; then
  echo 'Missing application icon' >&2
  exit 1
fi
if [[ ! -x "$app/Contents/MacOS/PortWeave" || ! -x "$app/Contents/MacOS/FlClashCore" ]]; then
  echo 'The app and Core must both be executable' >&2
  exit 1
fi
for binary in \
  "$app/Contents/MacOS/PortWeave" \
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
stage=$(mktemp -d "${TMPDIR:-/tmp}/portweave-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/PortWeave.app"
ln -s /Applications "$stage/Applications"
mkdir -p dist
name="PortWeave-$version-macos-$arch.dmg"
hdiutil create -volname PortWeave -srcfolder "$stage" -format UDZO "dist/$name"
hdiutil verify "dist/$name"
shasum -a 256 "dist/$name" | sed 's@  dist/@  @' > "dist/SHA256SUMS-macos-$arch"
