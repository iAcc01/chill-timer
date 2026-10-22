#!/bin/bash
# 编译并打包成 Chill Timer.app（通用二进制：Apple 芯片 + Intel）
set -euo pipefail

cd "$(dirname "$0")/.."

ARCHS=(--arch arm64 --arch x86_64)

echo "==> 编译 (release, arm64 + x86_64)"
# 某些受限终端环境（CI / 沙箱）下 SwiftPM 自带沙箱不可用，自动降级
if ! swift build -c release "${ARCHS[@]}"; then
    swift build -c release "${ARCHS[@]}" --disable-sandbox
fi

# 多架构构建的产物在 .build/apple/Products/Release
BIN=".build/apple/Products/Release/ChillTimer"

APP="dist/Chill Timer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/ChillTimer"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
cp -R "Resources/Actions" "$APP/Contents/Resources/Actions"

# 临时签名（ad-hoc），避免 Gatekeeper 直接拒绝运行
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "==> 完成: $(pwd)/$APP（架构: $(lipo -archs "$APP/Contents/MacOS/ChillTimer")）"
