import AppKit
import UniformTypeIdentifiers

enum LinkMode: String { case file, folder }

enum Provider: String, CaseIterable {
    case smb, dropbox, gdrive, synology

    var displayName: String {
        switch self {
        case .smb:      return "Fileserver"
        case .dropbox:  return "Dropbox"
        case .gdrive:   return "Google Drive"
        case .synology: return "Synology Drive"
        }
    }

    // Logo uit de applicatiemap: die app staat er zodra de provider in gebruik is. Fileserver: het netwerk-icoon van macOS.
    var icon: NSImage {
        let apps: [Provider: String] = [.dropbox: "/Applications/Dropbox.app",
                                        .gdrive: "/Applications/Google Drive.app",
                                        .synology: "/Applications/Synology Drive Client.app"]
        let source: NSImage
        if let app = apps[self], FileManager.default.fileExists(atPath: app) {
            source = NSWorkspace.shared.icon(forFile: app)
        } else if self == .smb, let server = Bundle.main.image(forResource: "fileserver") ?? NSImage(named: NSImage.networkName) {
            source = server   // Xserve-icoon uit Resources; de netwerkbol van macOS als terugval
        } else {
            source = NSWorkspace.shared.icon(for: .folder)
        }
        let img = source.copy() as! NSImage
        img.size = NSSize(width: 16, height: 16)
        return img
    }

    var cloudStoragePrefix: String? {
        switch self {
        case .dropbox:  return "Dropbox"
        case .gdrive:   return "GoogleDrive"
        case .synology: return "SynologyDrive"
        case .smb:      return nil
        }
    }
}

enum CloudLinks {
    // Standaard de redirectpagina op share-link.nl (GitHub Pages); eigen domein zonder opnieuw bouwen: defaults write nl.itgsolutions.sharelink LinkBase 'https://open.jouwdomein.nl/#'
    static var base: String { UserDefaults.standard.string(forKey: "LinkBase") ?? "https://share-link.nl/#" }
    static let fm = FileManager.default

    static var home: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir))
        }
        return fm.homeDirectoryForCurrentUser
    }

    // MARK: roots van cloudproviders

    static func roots(for p: Provider) -> [URL] {
        guard let prefix = p.cloudStoragePrefix else { return [] }
        var out: [URL] = []
        if p == .dropbox,
           let data = try? Data(contentsOf: home.appendingPathComponent(".dropbox/info.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["business", "personal"] {
                guard let d = json[key] as? [String: Any] else { continue }
                // root_path is de teamroot (teammappen staan daar direct onder), path de eigen ledenmap.
                for k in ["root_path", "path"] {
                    if let path = d[k] as? String { out.append(URL(fileURLWithPath: path)) }
                }
            }
        }
        let cs = home.appendingPathComponent("Library/CloudStorage")
        if let items = try? fm.contentsOfDirectory(at: cs, includingPropertiesForKeys: nil) {
            out += items.filter { $0.lastPathComponent.hasPrefix(prefix) }
        }
        if p == .dropbox  { out.append(home.appendingPathComponent("Dropbox")) }
        if p == .synology { out.append(home.appendingPathComponent("SynologyDrive")) }

        var seen = Set<String>()
        return out.map { $0.resolvingSymlinksInPath().standardizedFileURL }
                  .filter { fm.fileExists(atPath: $0.path) && seen.insert($0.path).inserted }
                  .sorted { $0.path.count > $1.path.count }
    }

    static func allRoots() -> [URL] { Provider.allCases.flatMap(roots(for:)) }

    // MARK: SMB

    struct SMBInfo { let host: String; let share: String; let mountPoint: URL }

    static func smbInfo(for url: URL) -> SMBInfo? {
        guard let v = try? url.resourceValues(forKeys: [.volumeURLKey, .volumeURLForRemountingKey]),
              let mount = v.volume, let remote = v.volumeURLForRemounting,
              remote.scheme?.lowercased() == "smb", let host = remote.host?.lowercased() else { return nil }
        let share = remote.path.split(separator: "/").first.map(String.init) ?? ""
        guard !share.isEmpty else { return nil }
        return SMBInfo(host: host, share: share.removingPercentEncoding ?? share, mountPoint: mount)
    }

    // Hostaliassen per klant via managed preference: domein nl.itgsolutions.sharelink, key HostAliases
    static func canonicalHost(_ h: String) -> String {
        let map = UserDefaults.standard.dictionary(forKey: "HostAliases") as? [String: String] ?? [:]
        return (map[h.lowercased()] ?? h).lowercased()
    }

    static func mountedVolume(host: String, share: String) -> URL? {
        let vols = fm.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeURLForRemountingKey],
                                        options: [.skipHiddenVolumes]) ?? []
        var fallback: URL?
        for v in vols {
            guard let info = smbInfo(for: v), info.share.caseInsensitiveCompare(share) == .orderedSame else { continue }
            if canonicalHost(info.host) == canonicalHost(host) { return info.mountPoint }
            fallback = fallback ?? info.mountPoint
        }
        return fallback
    }

    // MARK: Google Drive taalonafhankelijk

    private static let gdriveTokens: [String: String] = [
        "shared drives": "@shared", "gedeelde drives": "@shared",
        "my drive": "@mydrive",    "mijn drive": "@mydrive"
    ]

    // MARK: bij welke bron hoort een item?

    static func provider(for url: URL) -> Provider? {
        let real = url.resolvingSymlinksInPath().standardizedFileURL.path
        for p in Provider.allCases where p != .smb {
            if roots(for: p).contains(where: { real.hasPrefix($0.path + "/") }) { return p }
        }
        return smbInfo(for: url) != nil ? .smb : nil
    }

    // MARK: link maken (verzender)

    private static let allowed = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~/")
    private static func enc(_ s: String) -> String? {
        s.precomposedStringWithCanonicalMapping.addingPercentEncoding(withAllowedCharacters: allowed)
    }

    static func link(for url: URL, mode: LinkMode) -> String? {
        let real = url.resolvingSymlinksInPath().standardizedFileURL
        for p in Provider.allCases where p != .smb {
            for root in roots(for: p) where real.path.hasPrefix(root.path + "/") {
                var parts = String(real.path.dropFirst(root.path.count + 1))
                    .split(separator: "/", omittingEmptySubsequences: false).map(String.init)
                if p == .gdrive, let first = parts.first, let tok = gdriveTokens[first.lowercased()] {
                    parts[0] = tok
                }
                guard let e = enc(parts.joined(separator: "/")) else { return nil }
                return base + mode.rawValue + "/" + p.rawValue + "/" + e
            }
        }
        if let info = smbInfo(for: real) {
            let mp = info.mountPoint.standardizedFileURL.path
            guard real.path.hasPrefix(mp + "/"),
                  let e = enc(String(real.path.dropFirst(mp.count + 1))),
                  let s = enc(info.share) else { return nil }
            return base + mode.rawValue + "/smb/" + canonicalHost(info.host) + "/" + s + "/" + e
        }
        return nil   // OneDrive of lokale schijf: geen link
    }

    @discardableResult
    static func copyLinks(for urls: [URL], modes: [LinkMode]) -> Int {
        var lines: [String] = []
        for url in urls {
            for mode in modes {
                guard let l = link(for: url, mode: mode) else { continue }
                lines.append(modes.count > 1 ? (mode == .file ? "Bestand: " : "Map: ") + l : l)
            }
        }
        guard !lines.isEmpty else { NSSound.beep(); return 0 }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        return lines.count
    }

    // MARK: link openen (ontvanger)

    private struct Parsed { let mode: LinkMode; let provider: Provider; let rest: [String] }

    private static func parse(_ url: URL) -> Parsed? {
        guard url.scheme == "sharelink", let host = url.host, let mode = LinkMode(rawValue: host) else { return nil }
        let prefix = "sharelink://\(host)/"
        let s = url.absoluteString
        guard s.hasPrefix(prefix) else { return nil }
        let comps = s.dropFirst(prefix.count).split(separator: "/").map {
            String($0).removingPercentEncoding ?? String($0)
        }
        guard let first = comps.first, let p = Provider(rawValue: first), !comps.contains("..") else { return nil }
        return Parsed(mode: mode, provider: p, rest: Array(comps.dropFirst()))
    }

    private static func existing(in root: URL, _ rel: String) -> URL? {
        for variant in [rel, rel.decomposedStringWithCanonicalMapping] {
            let t = root.appendingPathComponent(variant).standardizedFileURL
            if t.path.hasPrefix(root.standardizedFileURL.path + "/"), fm.fileExists(atPath: t.path) { return t }
        }
        return nil
    }

    private static func resolveCloud(_ p: Provider, _ rest: [String]) -> URL? {
        for root in roots(for: p) {
            if p == .gdrive, let first = rest.first, first.hasPrefix("@") {
                // taalonafhankelijk: probeer elke bovenste map
                let tops = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
                for top in tops {
                    if let t = existing(in: top, rest.dropFirst().joined(separator: "/")) { return t }
                }
            } else if let t = existing(in: root, rest.joined(separator: "/")) {
                return t
            }
        }
        return nil
    }

    private static let neverOpen: Set<String> =
        ["app", "command", "sh", "tool", "pkg", "mpkg", "scpt", "workflow", "terminal"]

    private static func reveal(_ t: URL, _ mode: LinkMode) {
        if mode == .folder || neverOpen.contains(t.pathExtension.lowercased()) {
            NSWorkspace.shared.activateFileViewerSelecting([t])
        } else {
            NSWorkspace.shared.open(t)
        }
    }

    // Zonder mounten: cloudmappen en al gemounte shares. Ook de zelftest in build.sh.
    static func target(for url: URL) -> (URL, LinkMode)? {
        guard let p = parse(url) else { return nil }
        if p.provider != .smb { return resolveCloud(p.provider, p.rest).map { ($0, p.mode) } }
        guard p.rest.count >= 3, let mp = mountedVolume(host: p.rest[0], share: p.rest[1]),
              let t = existing(in: mp, p.rest.dropFirst(2).joined(separator: "/")) else { return nil }
        return (t, p.mode)
    }

    static func open(_ url: URL) {
        if let (t, mode) = target(for: url) { return reveal(t, mode) }
        guard let p = parse(url), p.provider == .smb, p.rest.count >= 3 else { NSSound.beep(); return }
        let host = p.rest[0], share = p.rest[1]
        let rel = p.rest.dropFirst(2).joined(separator: "/")
        // Niet gemount: via Finder mounten (sleutelhanger of wachtwoordvraag) en wachten
        let shareEnc = share.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? share
        guard let smbURL = URL(string: "smb://\(host)/\(shareEnc)") else { return }
        NSWorkspace.shared.open(smbURL)
        Task { @MainActor in
            for _ in 0..<120 {   // max 60 s, inclusief tijd om een wachtwoord te typen
                try? await Task.sleep(nanoseconds: 500_000_000)
                if let mp = mountedVolume(host: host, share: share), let t = existing(in: mp, rel) {
                    return reveal(t, p.mode)
                }
            }
            NSSound.beep()
        }
    }
}
