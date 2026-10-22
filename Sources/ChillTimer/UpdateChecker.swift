import AppKit
import Foundation

/// 版本巡检与自动更新。数据源：GitHub Releases 最新正式版（tag 如 v0.2.0，附件为 .dmg）。
/// - 巡检：启动 5 秒后首检；之后每小时检查一次，距上次联网满 6 小时才重新拉取
/// - 红点：有新版本且不在「稍后提醒」期内时显示；稍后提醒 = 24 小时内不显示红点（同一版本）
/// - 更新：下载 DMG → 挂载取出 .app → 校验 Bundle ID 与版本 → 退出后由脚本替换并重启
@MainActor
final class UpdateChecker: ObservableObject {

    static let shared = UpdateChecker()

    struct Release: Equatable, Sendable {
        let version: String
        let notes: String
        let dmgURL: URL
    }

    enum InstallState: Equatable {
        case idle
        case downloading
        case installing
        case failed(String)
    }

    /// 比当前版本新的发布；没有则为 nil
    @Published private(set) var latest: Release?
    /// 菜单栏 / 齿轮 / 关于 tab 的红点
    @Published private(set) var showBadge = false
    @Published private(set) var checking = false
    /// 手动检查的结果提示（如「已是最新版本」）
    @Published private(set) var checkMessage: String?
    @Published private(set) var installState: InstallState = .idle
    /// 浮窗内的更新确认弹窗
    @Published var dialogPresented = false

    private static let repoURL = URL(string: "https://github.com/iAcc01/chill-timer")!
    private static let feedURL = URL(string: "https://api.github.com/repos/iAcc01/chill-timer/releases/latest")!
    private static let pageURL = repoURL.appendingPathComponent("releases/latest")
    private static let fetchInterval: TimeInterval = 6 * 3600
    private static let snoozeInterval: TimeInterval = 24 * 3600

    private enum Key {
        static let snoozedUntil = "updateSnoozedUntil"
        static let snoozedVersion = "updateSnoozedVersion"
    }

    private var pollTimer: Timer?
    private var snoozeTimer: Timer?
    private var lastFetch: Date?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private init() {}

    // MARK: 巡检

    func start() {
        guard pollTimer == nil else { return }
        Task {
            try? await Task.sleep(for: .seconds(5))
            await check()
        }
        let timer = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.periodicCheck() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func periodicCheck() async {
        if let last = lastFetch, Date().timeIntervalSince(last) < Self.fetchInterval {
            refreshBadge()
        } else {
            await check()
        }
    }

    /// manual = 用户在关于页主动点击，失败或无更新时给出提示
    func check(manual: Bool = false) async {
        guard !checking else { return }
        checking = true
        checkMessage = nil
        defer { checking = false }

        do {
            let release = try await fetchLatestRelease()
            lastFetch = Date()
            if let release, Self.isNewer(release.version, than: currentVersion) {
                latest = release
            } else {
                latest = nil
                if manual { checkMessage = "已是最新版本" }
            }
        } catch {
            if manual { checkMessage = "检查失败，请稍后再试" }
        }
        refreshBadge()
    }

    private func fetchLatestRelease() async throws -> Release? {
        do {
            return try await fetchFromAPI()
        } catch {
            // API 按出口 IP 限流（未登录 60 次/小时，公司网络共享出口很容易用完）；
            // 退回到网页跳转：/releases/latest → /releases/tag/<tag>，不占配额，只是拿不到更新说明
            return try await fetchFromRedirect()
        }
    }

    private func fetchFromAPI() async throws -> Release? {
        var request = URLRequest(url: Self.feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ChillTimer/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { return nil }          // 还没有任何正式发布
            guard http.statusCode == 200 else { throw UpdateError.network }
        }

        struct Payload: Decodable {
            struct Asset: Decodable {
                let name: String
                let browser_download_url: URL
            }
            let tag_name: String
            let body: String?
            let assets: [Asset]
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let dmg = payload.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) else {
            return nil                                          // 发布里没有安装包，视为不可更新
        }
        return Release(version: Self.normalized(payload.tag_name),
                       notes: (payload.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                       dmgURL: dmg.browser_download_url)
    }

    /// 安装包命名约定（Scripts/package_dmg.sh 产出）：ChillTimer-<版本>.dmg
    private func fetchFromRedirect() async throws -> Release? {
        var request = URLRequest(url: Self.pageURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "HEAD"
        request.setValue("ChillTimer/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let finalURL = http.url else { throw UpdateError.network }

        let parts = finalURL.pathComponents
        guard let index = parts.firstIndex(of: "tag"), index + 1 < parts.count else {
            return nil                                          // 跳到 /releases：还没有任何正式发布
        }
        let tag = parts[index + 1]
        let version = Self.normalized(tag)
        let dmgURL = Self.repoURL
            .appendingPathComponent("releases/download")
            .appendingPathComponent(tag)
            .appendingPathComponent("ChillTimer-\(version).dmg")
        return Release(version: version, notes: "", dmgURL: dmgURL)
    }

    // MARK: 红点与稍后提醒

    private func refreshBadge() {
        snoozeTimer?.invalidate()
        snoozeTimer = nil
        guard let latest else {
            showBadge = false
            return
        }
        let defaults = UserDefaults.standard
        let until = defaults.object(forKey: Key.snoozedUntil) as? Date ?? .distantPast
        let snoozedVersion = defaults.string(forKey: Key.snoozedVersion)

        // 稍后提醒只对当时那个版本生效；出了更新的版本立即提示
        if snoozedVersion == latest.version, until > Date() {
            showBadge = false
            let timer = Timer(fire: until, interval: 0, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.refreshBadge() }
            }
            RunLoop.main.add(timer, forMode: .common)
            snoozeTimer = timer
        } else {
            showBadge = true
        }
    }

    func presentDialog() {
        guard latest != nil else { return }
        if case .failed = installState { installState = .idle }
        dialogPresented = true
    }

    func remindLater() {
        guard let latest else { return }
        let defaults = UserDefaults.standard
        defaults.set(Date().addingTimeInterval(Self.snoozeInterval), forKey: Key.snoozedUntil)
        defaults.set(latest.version, forKey: Key.snoozedVersion)
        dialogPresented = false
        refreshBadge()
    }

    func dismissDialog() {
        guard installState != .downloading, installState != .installing else { return }
        dialogPresented = false
    }

    // MARK: 立即更新

    func installLatest() {
        guard let release = latest else { return }
        switch installState {
        case .downloading, .installing: return
        default: break
        }
        Task { await performInstall(release) }
    }

    private func performInstall(_ release: Release) async {
        installState = .downloading
        do {
            let dmg = try await download(release.dmgURL)
            installState = .installing

            let target = Bundle.main.bundleURL
            let bundleID = Bundle.main.bundleIdentifier
            let stagedApp = try await Task.detached {
                try Installer.stage(dmg: dmg, expectedVersion: release.version, expectedBundleID: bundleID)
            }.value

            guard Installer.canReplace(target) else {
                // 当前位置不可写（如从 DMG 直接运行）：交给用户手动拖拽安装
                NSWorkspace.shared.open(dmg)
                installState = .failed("无法自动替换当前应用，已打开安装包，请拖入「应用程序」完成更新")
                return
            }

            try Installer.replaceAndRelaunch(newApp: stagedApp, target: target)
            NSApp.terminate(nil)
        } catch {
            installState = .failed((error as? UpdateError)?.message ?? "更新失败，请稍后再试")
        }
    }

    private func download(_ url: URL) async throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChillTimerUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let destination = dir.appendingPathComponent("update.dmg")

        if url.isFileURL {
            try FileManager.default.copyItem(at: url, to: destination)
            return destination
        }
        let (temp, response) = try await URLSession.shared.download(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.network }
        try FileManager.default.moveItem(at: temp, to: destination)
        return destination
    }

    // MARK: 版本号

    nonisolated static func normalized(_ version: String) -> String {
        version.trimmingCharacters(in: CharacterSet(charactersIn: "vV ").union(.whitespacesAndNewlines))
    }

    /// 语义化版本比较：1.10.0 > 1.9.2，缺省段按 0 处理
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ value: String) -> [Int] {
            normalized(value).split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let a = parts(candidate), b = parts(current)
        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left > right }
        }
        return false
    }
}

// MARK: - 错误

enum UpdateError: Error, Sendable {
    case network
    case mount
    case invalidPackage(String)
    case command(String)

    var message: String {
        switch self {
        case .network: return "下载失败，请检查网络后重试"
        case .mount: return "安装包无法打开"
        case .invalidPackage(let reason): return "安装包校验未通过：\(reason)"
        case .command: return "安装失败，请稍后再试"
        }
    }
}

// MARK: - 安装（文件操作，不依赖主线程）

enum Installer {

    /// 挂载 DMG → 校验 → 拷出 .app 到临时目录 → 卸载。返回待安装的 .app 路径。
    nonisolated static func stage(dmg: URL, expectedVersion: String, expectedBundleID: String?) throws -> URL {
        let workDir = dmg.deletingLastPathComponent()
        let mountPoint = workDir.appendingPathComponent("mnt", isDirectory: true)
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        do {
            _ = try run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-noautoopen",
                                             "-mountpoint", mountPoint.path, dmg.path])
        } catch {
            throw UpdateError.mount
        }
        defer { _ = try? run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"]) }

        let contents = (try? FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)) ?? []
        guard let app = contents.first(where: { $0.pathExtension == "app" }),
              let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")) else {
            throw UpdateError.invalidPackage("未找到应用")
        }
        let bundleID = info["CFBundleIdentifier"] as? String
        let version = UpdateChecker.normalized(info["CFBundleShortVersionString"] as? String ?? "")
        if let expectedBundleID, bundleID != expectedBundleID {
            throw UpdateError.invalidPackage("应用标识不一致")
        }
        guard version == expectedVersion else {
            throw UpdateError.invalidPackage("版本号不一致")
        }

        let staged = workDir.appendingPathComponent(app.lastPathComponent)
        try? FileManager.default.removeItem(at: staged)
        do {
            _ = try run("/usr/bin/ditto", [app.path, staged.path])
        } catch {
            throw UpdateError.command("ditto")
        }
        return staged
    }

    /// 当前应用所在位置是否允许原地替换
    nonisolated static func canReplace(_ target: URL) -> Bool {
        let path = target.path
        let parent = target.deletingLastPathComponent().path
        return target.pathExtension == "app"
            && !path.contains("/AppTranslocation/")
            && !path.hasPrefix("/Volumes/")
            && FileManager.default.isWritableFile(atPath: parent)
            && FileManager.default.isWritableFile(atPath: path)
    }

    /// 启动替换脚本：等本进程退出 → 备份旧版 → 放入新版（失败则回滚）→ 重新打开
    nonisolated static func replaceAndRelaunch(newApp: URL, target: URL) throws {
        let script = """
        #!/bin/sh
        PID="$1"; NEW="$2"; DEST="$3"; WORK="$4"
        while kill -0 "$PID" 2>/dev/null; do sleep 0.2; done
        rm -rf "$DEST.old"
        if mv "$DEST" "$DEST.old" && /usr/bin/ditto "$NEW" "$DEST"; then
            rm -rf "$DEST.old"
        else
            rm -rf "$DEST"
            mv "$DEST.old" "$DEST"
        fi
        /usr/bin/xattr -dr com.apple.quarantine "$DEST" 2>/dev/null
        /usr/bin/open "$DEST"
        rm -rf "$WORK"
        """
        let workDir = newApp.deletingLastPathComponent()
        let scriptURL = workDir.appendingPathComponent("install.sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [scriptURL.path, "\(ProcessInfo.processInfo.processIdentifier)",
                             newApp.path, target.path, workDir.path]
        try process.run()
    }

    @discardableResult
    nonisolated static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else { throw UpdateError.command(output) }
        return output
    }
}

// MARK: - 菜单栏带红点图标

enum MenuBarIcon {
    /// 非模板图：图形按绘制时的外观取文字色，右上角红点保持红色
    static func badged(symbol: String) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        guard let glyph = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return NSImage() }

        let glyphSize = glyph.size
        let dot: CGFloat = 6
        let size = NSSize(width: glyphSize.width + 2, height: glyphSize.height + 1)

        let image = NSImage(size: size, flipped: false) { _ in
            let glyphRect = NSRect(x: 0, y: 0, width: glyphSize.width, height: glyphSize.height)
            let tinted = NSImage(size: glyphSize, flipped: false) { rect in
                glyph.draw(in: rect)
                NSColor.labelColor.set()
                rect.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: glyphRect)

            let dotRect = NSRect(x: size.width - dot, y: size.height - dot, width: dot, height: dot)
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "有新版本"
        return image
    }
}
