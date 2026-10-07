import XCTest
@testable import OpenUsage

/// `openusage.cardNames` replaces the generated title of any provider card. The app applies the names
/// in `LayoutStore`, so a rename shows at once and a cleared name restores the generated title.
@MainActor
final class CardNamesSettingTests: XCTestCase {
    private func defaults(_ names: [String: Any] = [:]) throws -> UserDefaults {
        let suite = "CardNames.\(UUID().uuidString)"
        let value = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { value.removePersistentDomain(forName: suite) }
        if !names.isEmpty { value.set(names, forKey: CardNamesSetting.key) }
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

    private func layout(_ defaults: UserDefaults) throws -> LayoutStore {
        let providers = ProviderCatalog.make(
            defaults: defaults,
            claudeCards: [claudeCard("claude", "Claude — me@work.example"), claudeCard("claude@a", "Claude: me@client.example")],
            codex: CodexAccountDiscovery(cards: [try codexCard("codex", "Codex: Workspace a"), try codexCard("codex@b", "Codex: Workspace b")])
        )
        return LayoutStore(registry: .from(providers), defaults: defaults)
    }

    func testCustomNamesReplaceTheGeneratedCardTitles() throws {
        let layout = try layout(try defaults([
            "claude": "Claude - Work",
            "codex@b": "Codex - Client",
            "cursor": "Cursor - Team",
        ]))

        XCTAssertEqual(layout.provider(id: "claude")?.displayName, "Claude - Work")
        XCTAssertEqual(layout.provider(id: "claude@a")?.displayName, "Claude: me@client.example")
        XCTAssertEqual(layout.provider(id: "codex")?.displayName, "Codex: Workspace a")
        XCTAssertEqual(layout.provider(id: "codex@b")?.displayName, "Codex - Client")
        XCTAssertEqual(layout.provider(id: "cursor")?.displayName, "Cursor - Team")
        XCTAssertEqual(layout.generatedName(for: "claude"), "Claude — me@work.example")
    }

    func testCatalogKeepsTheGeneratedTitles() throws {
        let providers = ProviderCatalog.make(
            defaults: try defaults(["claude": "Claude - Work"]),
            claudeCards: [claudeCard("claude", "Claude — me@work.example")]
        )
        XCTAssertEqual(providers.first { $0.provider.id == "claude" }?.provider.displayName, "Claude")
    }

    func testRenameShowsAtOnceAndPersists() throws {
        let defaults = try defaults()
        let layout = try layout(defaults)

        layout.renameProvider("cursor", to: "  Cursor - Team  ")

        XCTAssertEqual(layout.provider(id: "cursor")?.displayName, "Cursor - Team")
        XCTAssertTrue(layout.hasCustomName("cursor"))
        XCTAssertEqual(defaults.dictionary(forKey: CardNamesSetting.key) as? [String: String], ["cursor": "Cursor - Team"])
        XCTAssertEqual(try self.layout(defaults).provider(id: "cursor")?.displayName, "Cursor - Team")
    }

    func testBlankRenameRestoresTheGeneratedTitle() throws {
        let defaults = try defaults(["codex@b": "Codex - Client"])
        let layout = try layout(defaults)

        layout.renameProvider("codex@b", to: "   ")

        XCTAssertEqual(layout.provider(id: "codex@b")?.displayName, "Codex: Workspace b")
        XCTAssertFalse(layout.hasCustomName("codex@b"))
        XCTAssertNil(defaults.dictionary(forKey: CardNamesSetting.key))
    }

    func testRenameToTheGeneratedTitleStoresNoName() throws {
        let defaults = try defaults()
        let layout = try layout(defaults)

        layout.renameProvider("codex", to: "Codex: Workspace a")

        XCTAssertFalse(layout.hasCustomName("codex"))
        XCTAssertNil(defaults.dictionary(forKey: CardNamesSetting.key))
    }

    func testRenameOfAnUnknownCardDoesNothing() throws {
        let defaults = try defaults()
        let layout = try layout(defaults)

        layout.renameProvider("missing", to: "Nobody")

        XCTAssertEqual(layout.cardNames, CardNamesSetting())
        XCTAssertNil(defaults.dictionary(forKey: CardNamesSetting.key))
    }

    func testSnapshotsCarryTheCustomNames() {
        let setting = CardNamesSetting(names: ["cursor": "Cursor - Team"])
        let snapshots = setting.applied(to: [
            "cursor": ProviderSnapshot(providerID: "cursor", displayName: "Cursor", lines: []),
            "zai": ProviderSnapshot(providerID: "zai", displayName: "Z.ai", lines: []),
        ])
        XCTAssertEqual(snapshots["cursor"]?.displayName, "Cursor - Team")
        XCTAssertEqual(snapshots["zai"]?.displayName, "Z.ai")
    }

    func testBlankOrNonTextNamesKeepTheGeneratedTitle() throws {
        let setting = CardNamesSetting(defaults: try defaults(["claude": "  ", "codex": 42]))
        XCTAssertEqual(setting.names, [:])
        XCTAssertEqual(setting.name(for: "claude", generated: "Claude"), "Claude")
    }
}
