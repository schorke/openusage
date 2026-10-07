import Foundation

/// User-chosen Total Spend colors for provider and account cards, keyed by card id (`claude`,
/// `claude@ab12cd34`, `codex@…`). There is no UI; set it with
/// `defaults write <bundle id> openusage.cardColors -dict claude "#1B3016,#3F6B35"`. A value is a
/// light-appearance hex, optionally followed by a dark-appearance hex; with one hex both appearances
/// use it. A color replaces the palette color in the ring, the legend, and the share card.
struct CardColorsSetting: Equatable, Sendable {
    static let key = "openusage.cardColors"

    struct Pair: Equatable, Sendable {
        let light: UInt32
        let dark: UInt32
    }

    /// Valid colors by card id. Unparseable values are dropped, so the card keeps its palette color.
    var colors: [String: Pair] = [:]

    init(colors: [String: Pair] = [:]) {
        self.colors = colors
    }

    init(defaults: UserDefaults) {
        let raw = defaults.dictionary(forKey: Self.key) ?? [:]
        colors = raw.compactMapValues { value in
            (value as? String).flatMap(Self.parse)
        }
    }

    /// `"#RRGGBB"` or `"#RRGGBB,#RRGGBB"` (light, dark). The `#` is optional.
    static func parse(_ value: String) -> Pair? {
        let hexes = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard (1...2).contains(hexes.count) else { return nil }
        let parsed = hexes.compactMap(hex)
        guard parsed.count == hexes.count else { return nil }
        return Pair(light: parsed[0], dark: parsed.last ?? parsed[0])
    }

    private static func hex(_ value: String) -> UInt32? {
        let digits = value.hasPrefix("#") ? value.dropFirst() : Substring(value)
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit) else { return nil }
        return UInt32(digits, radix: 16)
    }
}
