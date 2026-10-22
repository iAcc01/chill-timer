#!/bin/bash
# 构建 Chill Timer.app 并打成拖拽安装的 DMG：dist/ChillTimer-<版本>.dmg
set -euo pipefail

cd "$(dirname "$0")/.."

./Scripts/build.sh

APP="dist/Chill Timer.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
DMG="dist/ChillTimer-${VERSION}.dmg"
STAGE="$(mktemp -d)"

echo "==> 打包 DMG ($VERSION)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # 拖到这里即完成安装

rm -f "$DMG"
hdiutil create \
    -volname "Chill Timer" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> 完成: $(pwd)/$DMG ($(du -h "$DMG" | cut -f1))"
