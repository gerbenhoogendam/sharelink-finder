import SwiftUI
import ServiceManagement

@main
struct SharelinkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        // --links <pad>… en --resolve <sharelink-url>… zijn de zelftest van build.sh; geen menubalk.
        let a = CommandLine.arguments
        if a.count > 2, a[1] == "--links" {
            a.dropFirst(2).forEach { print(CloudLinks.link(for: URL(fileURLWithPath: $0), mode: .file) ?? "GEEN") }
            exit(0)
        }
        if a.count > 2, a[1] == "--resolve" {
            a.dropFirst(2).forEach { print(URL(string: $0).flatMap { CloudLinks.target(for: $0) }?.0.path ?? "GEEN") }
            exit(0)
        }
    }

    var body: some Scene { Settings { EmptyView() } }   // geen venster, alleen menubalk
}

final class Payload: NSObject {
    let urls: [URL]; let modes: [LinkMode]
    init(_ urls: [URL], _ modes: [LinkMode]) { self.urls = urls; self.modes = modes }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var menuIcon: NSImage?
    private var toast: NSPanel?

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // Menubalk-icoon uit Resources (menubar.png + @2x), als template zodat macOS hem meekleurt met licht en donker.
        let icon = Bundle.main.image(forResource: "menubar") ?? NSImage(systemSymbolName: "link", accessibilityDescription: "Sharelink")!
        icon.isTemplate = true
        statusItem.button?.image = icon
        menuIcon = icon
        menu.delegate = self
        statusItem.menu = menu
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        try? SMAppService.mainApp.register()
    }

    // Klik op een sharelink://-link
    func application(_ app: NSApplication, open urls: [URL]) { urls.forEach(CloudLinks.open) }

    // Bij elke keer openen opnieuw opbouwen op basis van de Finder-selectie
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let selection = finderSelection()
        var groups: [Provider: [URL]] = [:]
        for url in selection {
            if let p = CloudLinks.provider(for: url) { groups[p, default: []].append(url) }
        }

        if groups.isEmpty {
            let info = NSMenuItem(title: selection.isEmpty ? "Selecteer een bestand in Finder" : "Geen ondersteunde locatie",
                                  action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
            menu.addItem(.separator())
        }

        for p in Provider.allCases {
            guard let urls = groups[p] else { continue }
            for (title, modes) in [("Link bestand", [LinkMode.file]),
                                   ("Link map", [.folder]),
                                   ("Link map & bestand", [.folder, .file])] {
                let item = NSMenuItem(title: title, action: #selector(copyAction(_:)), keyEquivalent: "")
                item.target = self
                item.image = p.icon
                if #available(macOS 27.0, *) { item.preferredImageVisibility = .visible }   // macOS 27 verbergt menu-afbeeldingen standaard
                item.representedObject = Payload(urls, modes)
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        menu.addItem(NSMenuItem(title: "Stoppen", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func copyAction(_ sender: NSMenuItem) {
        guard let p = sender.representedObject as? Payload else { return }
        confirm(CloudLinks.copyLinks(for: p.urls, modes: p.modes))
    }

    // Bevestiging: het icoon wordt even een vinkje en onder de menubalk schuift "Link gekopieerd" in.
    private func confirm(_ count: Int) {
        guard count > 0 else { return }
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Gekopieerd")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in button.image = self?.menuIcon }
        }
        showToast(count == 1 ? "Link gekopieerd" : "\(count) links gekopieerd")
    }

    private func showToast(_ text: String) {
        toast?.orderOut(nil)
        let height: CGFloat = 36
        let label = NSTextField(labelWithString: "✓  " + text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.alignment = .center
        label.sizeToFit()
        let width = max(150, label.frame.width + 28)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        effect.layer?.masksToBounds = true
        label.frame = NSRect(x: 14, y: (height - label.frame.height) / 2, width: width - 28, height: label.frame.height)
        effect.addSubview(label)
        panel.contentView = effect
        // Onder het icoon in de menubalk; zonder icoon rechtsboven op het hoofdscherm.
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        var origin = NSPoint(x: screen.maxX - width - 12, y: screen.maxY - height - 8)
        if let bar = statusItem.button?.window {
            origin = NSPoint(x: min(bar.frame.midX - width / 2, screen.maxX - width - 8), y: bar.frame.minY - height - 6)
        }
        panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y - 8))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        toast = panel
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 1
            panel.animator().setFrame(NSRect(origin: origin, size: panel.frame.size), display: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self, weak panel] in
            guard let panel, self?.toast === panel else { return }
            NSAnimationContext.runAnimationGroup({ ctx in ctx.duration = 0.3; panel.animator().alphaValue = 0 },
                                                 completionHandler: { panel.orderOut(nil); if self?.toast === panel { self?.toast = nil } })
        }
    }

    func finderSelection() -> [URL] {
        let src = """
        tell application "Finder"
            set out to ""
            repeat with i in (get selection)
                set out to out & POSIX path of (i as alias) & linefeed
            end repeat
            return out
        end tell
        """
        var err: NSDictionary?
        guard let res = NSAppleScript(source: src)?.executeAndReturnError(&err).stringValue else { return [] }
        return res.split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
    }

    // Services (rechtsklik > Services)
    private func urls(_ pb: NSPasteboard) -> [URL] { (pb.readObjects(forClasses: [NSURL.self]) as? [URL]) ?? [] }
    @objc func copyFileLink(_ pb: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        confirm(CloudLinks.copyLinks(for: urls(pb), modes: [.file]))
    }
    @objc func copyFolderLink(_ pb: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        confirm(CloudLinks.copyLinks(for: urls(pb), modes: [.folder]))
    }
    @objc func copyBothLinks(_ pb: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        confirm(CloudLinks.copyLinks(for: urls(pb), modes: [.folder, .file]))
    }
}
