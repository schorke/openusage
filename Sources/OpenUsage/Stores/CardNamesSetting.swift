import Foundation

/// User-chosen names for Claude and Codex account cards, keyed by card id (`claude`,
/// `claude@ab12cd34`, `codex@…`). There is no UI; set it with
/// `defaults write <bundle id> openusage.cardNames -dict claude "Claude - Work"`. A name replaces the
/// generated "Claude — email (Org)" title everywhere the card's name shows.
struct CardNamesSetting: Equatable, Sendable {
    static let key = "openusage.cardNames"

    /// Trimmed, non-empty names by card id.
    var names: [String: String] = [:]

    init(names: [String: String] = [:]) {
        self.names = names
    }

    init(defaults: UserDefaults) {
        let raw = defaults.dictionary(forKey: Self.key) ?? [:]
        names = raw.compactMapValues { value in
            (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
    }

    /// The user's name for a card, else the generated one.
    func name(for cardID: String, generated: String) -> String {
        names[cardID] ?? generated
    }
}
