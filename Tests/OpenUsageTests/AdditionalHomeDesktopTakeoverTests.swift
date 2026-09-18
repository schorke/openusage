import XCTest
@testable import OpenUsage

/// Claude Desktop signed into the same account/organization as an additional home: the Desktop
/// discovery runs first and would otherwise leave a Desktop-only card that never reads the home's
/// scoped Keychain service. The additional home must take that card over, keeping its id.
extension ClaudeDesktopAuthStoreTests {
    @MainActor
    func testAdditionalHomeTakesOverDesktopOnlyCardForTheSameIdentity() async throws {
        let fixture = try makeFixture(activeOrganization: otherOrganization, v2: [
            cacheKey(organization: otherOrganization): tokenEntry("desktop-work", expiresIn: 3600)
        ], accountUUID: accountUUID)
        let workHome = home.path + "/.claude-work"
        fixture.files.files[home.path + "/.claude.json"] =
            #"{"oauthAccount":{"accountUuid":"\#(accountUUID)","organizationUuid":"\#(organization)"}}"#
        fixture.files.files[workHome + "/.claude.json"] =
            #"{"oauthAccount":{"accountUuid":"\#(accountUUID)","organizationUuid":"\#(otherOrganization)","emailAddress":"me@work.example","organizationName":"Work Inc"}}"#
        let suite = "DesktopTakeover.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let accounts = ProviderAccountsStore(defaults: defaults)
        let fixtureHome = home
        let observer = DefaultAccountObserver(environment: FakeEnvironment([:]), files: fixture.files,
            keychain: FakeKeychain(), homeDirectory: { fixtureHome })
        func discover(homes: AdditionalHomesSetting) async -> ProviderAccountAssembly {
            await ProviderAccountAssembly.make(observer: observer, accountsStore: accounts,
                additionalHomes: homes, desktop: fixture.store, listDesktopOrganizationDirectories: { _ in [] })
        }
        let workIdentity = "\(accountUUID)|\(otherOrganization)"

        // Without the setting, Desktop alone yields a Desktop-only card for the work organization.
        let before = await discover(homes: .init())
        let desktopOnly = try XCTUnwrap(before.claudeCards.first { $0.identityKey == workIdentity })
        XCTAssertTrue(desktopOnly.usesDesktopCredentials)
        XCTAssertNil(desktopOnly.configDirectory)

        // With the home listed, the same card (same id) is pinned to the home and reads its own login.
        let after = await discover(homes: .init(claude: [workHome]))
        XCTAssertEqual(after.claudeCards.count, 2)
        let pinned = try XCTUnwrap(after.claudeCards.first { $0.identityKey == workIdentity })
        XCTAssertEqual(pinned.id, desktopOnly.id)
        XCTAssertFalse(pinned.usesDesktopCredentials)
        XCTAssertEqual(pinned.configDirectory, workHome)
        let personal = try XCTUnwrap(after.claudeCards.first { $0.identityKey != workIdentity })
        XCTAssertNil(personal.configDirectory)
        XCTAssertEqual(personal.additionalLogDirectories, [workHome])
        let record = try XCTUnwrap(accounts.records.first { $0.id == pinned.id })
        XCTAssertTrue(record.sources.contains { $0.kind == .additionalHome && $0.anchor == workHome })
    }
}
