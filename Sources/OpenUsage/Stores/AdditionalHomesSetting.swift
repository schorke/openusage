import Foundation

/// Extra Claude config directories the user signs into outside the default home — the
/// `CLAUDE_CONFIG_DIR=~/.claude-work claude` pattern. The list is explicit (no directory scan): set it
/// with `defaults write <bundle id> openusage.claudeAdditionalHomes -array ~/.claude-work`. Each entry
/// that names its account becomes a card of its own; an entry naming the default account just
/// attaches as another source of that card. (Codex finds its `~/.codex-*` homes on its own.)
struct AdditionalHomesSetting: Equatable, Sendable {
    static let claudeKey = "openusage.claudeAdditionalHomes"

    /// Absolute, `~`-expanded, deduplicated paths in the user's order.
    var claude: [String] = []

    init(claude: [String] = []) {
        self.claude = claude
    }

    init(defaults: UserDefaults, home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        claude = Self.normalize(defaults.stringArray(forKey: Self.claudeKey) ?? [], home: home)
    }

    var isEmpty: Bool { claude.isEmpty }

    /// Trim, expand a leading `~`, drop relative or empty entries (logged — a typo must not fail
    /// silently), and strip a trailing slash so the path hashes like the CLI's own `CLAUDE_CONFIG_DIR`.
    static func normalize(_ raw: [String], home: URL) -> [String] {
        var seen = Set<String>()
        return raw.compactMap { entry -> String? in
            var path = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            if path == "~" || path.hasPrefix("~/") { path = home.path + String(path.dropFirst(1)) }
            while path.count > 1, path.hasSuffix("/") { path.removeLast() }
            guard path.hasPrefix("/"), !path.contains("\0") else {
                AppLog.warn(.config, "additional home ignored (not an absolute path): \(entry)")
                return nil
            }
            return seen.insert(path).inserted ? path : nil
        }
    }
}
