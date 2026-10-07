import XCTest
@testable import OpenUsage

/// `openusage.cardColors` replaces the Total Spend palette color of a provider or account card.
@MainActor
final class CardColorsSettingTests: XCTestCase {
    private func defaults(_ colors: [String: Any]) throws -> UserDefaults {
        let suite = "CardColors.\(UUID().uuidString)"
        let value = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { value.removePersistentDomain(forName: suite) }
        value.set(colors, forKey: CardColorsSetting.key)
        return value
    }

    func testOneHexColorsBothAppearancesAndTwoHexesSplitThem() throws {
        let setting = CardColorsSetting(defaults: try defaults([
            "claude@a": "#FF5911",
            "claude": "#1b3016, #3f6b35",
        ]))

        XCTAssertEqual(setting.colors["claude@a"], .init(light: 0xFF5911, dark: 0xFF5911))
        XCTAssertEqual(setting.colors["claude"], .init(light: 0x1B3016, dark: 0x3F6B35))
    }

    func testInvalidValuesAreDroppedSoTheCardKeepsItsPaletteColor() throws {
        let setting = CardColorsSetting(defaults: try defaults([
            "claude": "orange",
            "codex": "#12345",
            "copilot": "+12345",
            "codex@a": "#111111,#222222,#333333",
            "cursor": 42,
            "amp": "F34E3F",
        ]))

        XCTAssertEqual(setting.colors, ["amp": .init(light: 0xF34E3F, dark: 0xF34E3F)])
    }
}
