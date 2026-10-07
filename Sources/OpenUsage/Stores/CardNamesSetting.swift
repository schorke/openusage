import Foundation

/// User-chosen names for provider cards, keyed by card id (`cursor`, `claude`, `claude@ab12cd34`,
/// `codex@…`). Rename a card in the dashboard: double-click its name, or right-click its header and
/// choose "Rename…". A name replaces the generated title (e.g. "Claude — email (Org)") everywhere the
/// card's name shows; clearing it restores the generated title.
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

    /// Sets the user's name for a card. A blank name, or the generated name itself, removes the
    /// custom name so the card follows its generated title again.
    mutating func setName(_ name: String, for cardID: String, generated: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == generated {
            names[cardID] = nil
        } else {
            names[cardID] = trimmed
        }
    }

    /// The snapshots with each card's display name replaced by the user's name, for the surfaces
    /// that read names from snapshots (the local HTTP API and the CLI).
    func applied(to snapshots: [String: ProviderSnapshot]) -> [String: ProviderSnapshot] {
        guard !names.isEmpty else { return snapshots }
        return snapshots.mapValues { snapshot in
            var named = snapshot
            named.displayName = name(for: snapshot.providerID, generated: snapshot.displayName)
            return named
        }
    }

    func save(to defaults: UserDefaults) {
        if names.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else {
            defaults.set(names, forKey: Self.key)
        }
    }
}
