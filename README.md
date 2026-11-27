# finder-menu

Finder 右键菜单扩展，菜单项直接在顶层。

- 文件夹空白处：在 Ghostty 新标签页中打开、移动项目到这里（复制文件后出现，等同 Cmd+Option+V）、复制当前文件夹路径、按修改日期整理、按名称整理
- 选中文件：复制完整路径

## 要求

macOS 12+、Ghostty（1.4.0 已验证）、命令行工具（`xcode-select --install`）。

## 安装

```bash
./install.sh
```

编译、签名、装到 `~/Applications`、启用扩展并重启 Finder。

菜单没出现：系统设置 → 登录项与扩展 → Finder 扩展，勾选“Finder 右键菜单”。
首次使用会弹“自动化”授权（控制 Finder / Ghostty），点允许。

## 卸载

```bash
pluginkit -r ~/Applications/FinderMenu.app/Contents/PlugIns/FinderMenuExt.appex
rm -rf ~/Applications/FinderMenu.app
killall Finder
```

## 说明

- “整理”只在图标视图生效。
- 移动遇到同名项目不会覆盖，会弹出提示。
- 日志：`~/Library/Logs/FinderMenu.log`
