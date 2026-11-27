#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
OUT=build
APP=$OUT/FinderMenu.app
EXT=$APP/Contents/PlugIns/FinderMenuExt.appex
rm -rf "$OUT"; mkdir -p "$APP/Contents/MacOS" "$EXT/Contents/MacOS"

# 宿主
swiftc -O -o "$APP/Contents/MacOS/FinderMenu" src/app/main.swift
cp src/app/Info.plist "$APP/Contents/Info.plist"

# 扩展（入口必须是 _NSExtensionMain）
swiftc -O -application-extension -module-name FinderMenuExt \
  -framework Cocoa -framework FinderSync \
  -Xlinker -e -Xlinker _NSExtensionMain \
  -o "$EXT/Contents/MacOS/FinderMenuExt" src/ext/FinderSync.swift
cp src/ext/Info.plist "$EXT/Contents/Info.plist"

# 签名：先扩展（沙盒），后宿主
codesign --force --sign - --entitlements src/ext/ext.entitlements "$EXT"
codesign --force --sign - "$APP"
echo "built: $APP"
