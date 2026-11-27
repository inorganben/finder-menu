import Cocoa

// 宿主：接收 findermenu://ghostty?path=… 与 findermenu://sort?path=…，执行后退出

func esc(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
}

func logLine(_ m: String) {
    let f = NSHomeDirectory() + "/Library/Logs/FinderMenu.log"
    let line = "\(Date()) \(m)\n"
    if let h = FileHandle(forWritingAtPath: f) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile() }
    else { try? line.write(toFile: f, atomically: true, encoding: .utf8) }
}

@discardableResult
func runScript(_ source: String) -> String? {
    var err: NSDictionary?
    let result = NSAppleScript(source: source)?.executeAndReturnError(&err)
    if let err = err {
        logLine("AppleScript error: \(err)")
        return nil
    }
    return result?.stringValue
}

func openInGhostty(_ path: String) {
    let p = esc(path)
    let bundleID = "com.mitchellh.ghostty"
    let wasRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty

    if !wasRunning {
        // 冷启动：先拉起 Ghostty，等它自己的初始窗口出现，再在其中新建标签页
        runScript("tell application \"Ghostty\" to activate")
        for _ in 0..<50 {
            if runScript("tell application \"Ghostty\" to return (count of windows) as text") ?? "0" != "0" { break }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
    runScript("""
    tell application "Ghostty"
        if (count of windows) is 0 then
            new window with configuration {initial working directory:"\(p)"}
        else
            new tab in front window with configuration {initial working directory:"\(p)"}
        end if
        activate
    end tell
    """)
}

func arrange(_ path: String, by: String) {
    let prop = by == "name" ? "name" : "modification date"
    var p = path
    while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
    let ep = esc(p)
    let r = runScript("""
    on norm(s)
        if (length of s) > 1 and s ends with "/" then return text 1 thru -2 of s
        return s
    end norm
    tell application "Finder"
        set want to "\(ep)"
        set w to missing value
        repeat with n from 1 to (count of Finder windows)
            try
                if my norm(POSIX path of ((target of Finder window n) as alias)) is want then
                    set w to Finder window n
                    exit repeat
                end if
            end try
        end repeat
        if w is not missing value then
            if current view of w is icon view then
                clean up w by \(prop)
                return "cleaned"
            end if
            return "not icon view"
        else if my norm(POSIX path of (path to desktop folder)) is want then
            clean up desktop by \(prop)
            return "desktop cleaned"
        end if
        return "no window matched"
    end tell
    """)
    logLine("arrange(\(prop)) \(p): \(r ?? "nil")")
}

/// 等同于 Cmd+Option+V：把剪贴板里（Cmd+C 复制的）文件移动到目标文件夹
func moveHere(_ dest: String) {
    let pb = NSPasteboard.general
    let urls = (pb.readObjects(forClasses: [NSURL.self],
                               options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    logLine("move \(urls.count) item(s) -> \(dest)")
    guard !urls.isEmpty else { return }

    let list = urls.map { "\"\(esc($0.path))\"" }.joined(separator: ", ")
    let result = runScript("""
    set failed to {}
    tell application "Finder"
        set destFolder to (POSIX file "\(esc(dest))") as alias
        repeat with p in {\(list)}
            try
                move ((POSIX file (p as text)) as alias) to destFolder
            on error
                set end of failed to (p as text)
            end try
        end repeat
    end tell
    set AppleScript's text item delimiters to linefeed
    return failed as text
    """) ?? ""

    if result.isEmpty {
        pb.clearContents()   // 已经移走，清掉剪贴板，避免菜单项残留
    } else {
        logLine("move failed: \(result)")
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "部分项目未能移动"
        a.informativeText = "目标位置可能已有同名项目：\n" + result
        a.runModal()
    }
}

final class Delegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "findermenu" {
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "path" })?.value
            logLine("open \(url.absoluteString)")
            guard let path = path else { continue }
            switch url.host {
            case "ghostty": openInGhostty(path)
            case "move": moveHere(path)
            case "sort":
                let by = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "by" })?.value ?? "date"
                arrange(path, by: by)
            default: break
            }
        }
        NSApp.terminate(nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 直接双击启动（无 URL）时不常驻
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { NSApp.terminate(nil) }
    }
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
