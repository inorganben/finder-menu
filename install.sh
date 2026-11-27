#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
./build.sh
DEST="$HOME/Applications/FinderMenu.app"
EXTID=local.findermenu.app.ext
mkdir -p "$HOME/Applications"
pkill -f FinderMenuExt 2>/dev/null || true
rm -rf "$DEST"; cp -R build/FinderMenu.app "$DEST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
pluginkit -a "$DEST/Contents/PlugIns/FinderMenuExt.appex"
pluginkit -e use -i "$EXTID"
killall Finder
echo "installed. 若菜单未出现：系统设置 → 登录项与扩展 → Finder 扩展，勾选 “Finder 右键菜单”"
pluginkit -m -p com.apple.FinderSync -i "$EXTID" -v
