import XCTest
@testable import OpenUsage

/// `openusage.cardNames` replaces the generated title of a Claude or Codex account card.
@MainActor
final class CardNamesSettingTests: XCTestCase {
    private func defaults(_ names: [String: Any]) throws -> UserDefaults {
        let suite = "CardNames.\(UUID().uuidString)"
        let value = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { value.removePersistentDomain(forName: suite) }
        value.set(names, forKey: CardNamesSetting.key)
        return value
    }

    private func claudeCard(_ id: String, _ name: String) -> ClaudeAccountCard {
        ClaudeAccountCard(
            id: id, identityKey: "\(id)-user|\(id)-org", organizationID: "\(id)-org",
            displayName: name, usesDesktopCredentials: false, allowsUnattributedPiUsage: false
        )
    }

    private func codexCard(_ id: String, _ name: String) throws -> CodexAccountCard {
        CodexAccountCard(
            id: id, identity: try XCTUnwrap(CodexAccountIdentity(accountID: "\(id)-workspace", email: "me@example.com")),
            displayName: name, authHomes: [], writableAuthHomes: [], piCredentialSources: [], claimsPiUsage: false
        )
    }

    private func names(_ providers: [ProviderRuntime]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: providers.map { ($0.provider.id, $0.provider.displayName) })
    }

    func testCustomNamesReplaceTheGeneratedCardTitles() throws {
        let defaults = try defaults([
            "claude": "Claude - Work",
            "codex@b": "Codex - Client",
        ])
        let providers = ProviderCatalog.make(
            defaults: defaults,
            claudeCards: [claudeCard("claude", "Claude — me@work.example"), claudeCard("claude@a", "Claude: me@client.example")],
            codex: CodexAccountDiscovery(cards: [try codexCard("codex", "Codex: Workspace a"), try codexCard("codex@b", "Codex: Workspace b")])
        )

        let names = names(providers)
        XCTAssertEqual(names["claude"], "Claude - Work")
        XCTAssertEqual(names["claude@a"], "Claude: me@client.example")
        XCTAssertEqual(names["codex"], "Codex: Workspace a")
        XCTAssertEqual(names["codex@b"], "Codex - Client")
    }

    func testCustomNameAppliesToASingleClaudeCard() throws {
        let providers = ProviderCatalog.make(
            defaults: try defaults(["claude": "Claude - Work"]),
            claudeCards: [claudeCard("claude", "Claude — me@work.example")]
        )
        XCTAssertEqual(names(providers)["claude"], "Claude - Work")
    }

    func testBlankOrNonTextNamesKeepTheGeneratedTitle() throws {
        let setting = CardNamesSetting(defaults: try defaults(["claude": "  ", "codex": 42]))
        XCTAssertEqual(setting.names, [:])
        XCTAssertEqual(setting.name(for: "claude", generated: "Claude"), "Claude")
    }
}
