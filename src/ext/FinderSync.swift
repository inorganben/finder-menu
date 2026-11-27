import Cocoa
import FinderSync

@objc(FinderSyncExt)
class FinderSyncExt: FIFinderSync {

    override init() {
        super.init()
        // 监听根目录，使所有目录（含外置卷）都显示菜单
        FIFinderSyncController.default().directoryURLs = [
            URL(fileURLWithPath: "/"),
            URL(fileURLWithPath: "/Volumes"),
        ]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let menu = NSMenu(title: "")
        switch menuKind {
        case .contextualMenuForContainer:
            menu.addItem(item("在 Ghostty 新标签页中打开", #selector(openInGhostty(_:)), symbol: "terminal"))
            if clipboardHasFiles() {
                menu.addItem(item("移动项目到这里", #selector(moveHere(_:)), symbol: "arrow.right.doc.on.clipboard"))
            }
            menu.addItem(item("复制当前文件夹路径", #selector(copyFolderPath(_:)), symbol: "doc.on.doc"))
            menu.addItem(item("按修改日期整理", #selector(arrangeByDate(_:)), symbol: "calendar.badge.clock"))
            menu.addItem(item("按名称整理", #selector(arrangeByName(_:)), symbol: "textformat.abc"))
        case .contextualMenuForItems:
            menu.addItem(item("复制完整路径", #selector(copyFullPath(_:)), symbol: "doc.on.doc"))
        default:
            return nil
        }
        return menu
    }

    private func item(_ title: String, _ action: Selector, symbol: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        i.image = squareIcon(symbol)
        return i
    }

    /// 把 SF Symbol 等比缩放后居中画进正方形画布，避免被菜单拉伸变形
    private func squareIcon(_ name: String, side: CGFloat = 16) -> NSImage? {
        guard let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        let canvas = NSSize(width: side, height: side)
        let img = NSImage(size: canvas, flipped: false) { rect in
            let s = sym.size
            guard s.width > 0, s.height > 0 else { return false }
            let k = min(rect.width / s.width, rect.height / s.height)
            let w = s.width * k, h = s.height * k
            sym.draw(in: NSRect(x: (rect.width - w) / 2, y: (rect.height - h) / 2, width: w, height: h))
            return true
        }
        img.isTemplate = true
        return img
    }

    /// 只探测类型，不读取内容，避免触发剪贴板访问提示
    private func clipboardHasFiles() -> Bool {
        NSPasteboard.general.canReadObject(forClasses: [NSURL.self],
                                           options: [.urlReadingFileURLsOnly: true])
    }

    private func copyToPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    // MARK: - 动作

    @objc func copyFullPath(_ sender: AnyObject?) {
        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else { return }
        copyToPasteboard(urls.map { $0.path }.joined(separator: "\n"))
    }

    @objc func copyFolderPath(_ sender: AnyObject?) {
        guard let url = FIFinderSyncController.default().targetedURL() else { return }
        copyToPasteboard(url.path)
    }

    @objc func openInGhostty(_ sender: AnyObject?) {
        callHost("ghostty")
    }

    @objc func moveHere(_ sender: AnyObject?) {
        callHost("move")
    }

    @objc func arrangeByDate(_ sender: AnyObject?) {
        callHost("sort", extra: [URLQueryItem(name: "by", value: "date")])
    }

    @objc func arrangeByName(_ sender: AnyObject?) {
        callHost("sort", extra: [URLQueryItem(name: "by", value: "name")])
    }

    /// 沙盒内扩展不能直接发 AppleEvent，通过 URL scheme 交给宿主执行
    private func callHost(_ command: String, extra: [URLQueryItem] = []) {
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        var c = URLComponents()
        c.scheme = "findermenu"
        c.host = command
        c.queryItems = [URLQueryItem(name: "path", value: target.path)] + extra
        if let url = c.url {
            NSWorkspace.shared.open(url)
        }
    }
}
