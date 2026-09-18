import CryptoKit
import XCTest
@testable import OpenUsage

/// User-listed extra Claude homes (`AdditionalHomesSetting`): a `CLAUDE_CONFIG_DIR` directory per
/// account, each becoming its own card without any Swap tool.
@MainActor
final class AdditionalHomeAccountTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/Users/dev")
    private let userA = "11111111-1111-1111-1111-111111111111"
    private let orgA = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    private let userB = "22222222-2222-2222-2222-222222222222"
    private let orgB = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"

    private func defaults() throws -> UserDefaults {
        let suite = "AdditionalHomes.\(UUID().uuidString)"
        let value = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { value.removePersistentDomain(forName: suite) }
        return value
    }

    private func claudeState(user: String, org: String, email: String, orgName: String) -> String {
        #"{"oauthAccount":{"accountUuid":"\#(user)","organizationUuid":"\#(org)","emailAddress":"\#(email)","organizationName":"\#(orgName)"}}"#
    }

    private func credentials(_ access: String) -> String {
        #"{"claudeAiOauth":{"accessToken":"\#(access)","refreshToken":"refresh","expiresAt":4102444800000,"scopes":["user:profile"]}}"#
    }

    private func assembly(
        _ files: FakeFiles, store: ProviderAccountsStore, homes: AdditionalHomesSetting,
        environment: FakeEnvironment = FakeEnvironment([:]), families: Set<String> = ProviderAccountID.families
    ) async -> ProviderAccountAssembly {
        let home = home
        let observer = DefaultAccountObserver(
            environment: environment, files: files, keychain: FakeKeychain(nil), homeDirectory: { home }
        )
        return await ProviderAccountAssembly.make(
            observer: observer, accountsStore: store, families: families, additionalHomes: homes
        )
    }

    // MARK: - Setting

    func testSettingNormalizesPathsAndDropsRelativeEntries() throws {
        let defaults = try defaults()
        defaults.set(["~/.claude-work/", " /abs/dir ", "relative", "", "/abs/dir"], forKey: AdditionalHomesSetting.claudeKey)

        let setting = AdditionalHomesSetting(defaults: defaults, home: home)

        XCTAssertEqual(setting.claude, ["/Users/dev/.claude-work", "/abs/dir"])
        XCTAssertTrue(AdditionalHomesSetting(defaults: try self.defaults(), home: home).isEmpty)
    }

    // MARK: - Claude

    func testAdditionalClaudeHomeBecomesItsOwnCardPinnedToThatHome() async throws {
        let work = "/Users/dev/.claude-work"
        let files = FakeFiles([
            home.path + "/.claude.json": claudeState(user: userA, org: orgA, email: "me@example.com", orgName: "Personal"),
            work + "/.claude.json": claudeState(user: userB, org: orgB, email: "me@work.example", orgName: "Work Inc"),
        ])
        let defaults = try defaults()
        let store = ProviderAccountsStore(defaults: defaults)

        let result = await assembly(files, store: store, homes: AdditionalHomesSetting(claude: [work]))

        XCTAssertEqual(result.claudeCards.count, 2)
        let defaultCard = try XCTUnwrap(result.claudeCards.first { $0.identityKey == "\(userA)|\(orgA)" })
        let workCard = try XCTUnwrap(result.claudeCards.first { $0.identityKey == "\(userB)|\(orgB)" })
        XCTAssertEqual(defaultCard.id, "claude", "the default login keeps the bare id")
        XCTAssertNil(defaultCard.configDirectory)
        XCTAssertEqual(workCard.configDirectory, work)
        XCTAssertEqual(workCard.organizationID, orgB)
        XCTAssertEqual(workCard.displayName, "Claude: me@work.example (Work Inc)")
        XCTAssertEqual(workCard.organizationName, "Work Inc")
        XCTAssertTrue(result.claudeCards.allSatisfy { $0.additionalLogDirectories == [work] })
        XCTAssertFalse(workCard.allowsUnattributedPiUsage)
        XCTAssertEqual(result.identityKeysByCard[workCard.id], "\(userB)|\(orgB)")
        let record = try XCTUnwrap(store.records.first { $0.identityKey == "\(userB)|\(orgB)" })
        XCTAssertEqual(record.sources.map(\.kind), [.additionalHome])
        XCTAssertFalse(record.sources[0].holdsDefaultSource)
        XCTAssertEqual(store.defaultBadgeHolder(family: "claude")?.id, "claude")

        // Stable across launches, and the catalog renders one provider per card.
        let again = await assembly(files, store: store, homes: AdditionalHomesSetting(claude: [work]))
        XCTAssertEqual(again.claudeCards, result.claudeCards)
        let providers = ProviderCatalog.make(defaults: defaults, claudeCards: result.claudeCards)
        XCTAssertEqual(providers.filter { $0.provider.id.hasPrefix("claude") }.count, 2)
    }

    func testAdditionalClaudeHomeNamingTheDefaultAccountOnlyAttachesAsASource() async throws {
        let mirror = "/Users/dev/.claude-mirror"
        let state = claudeState(user: userA, org: orgA, email: "me@example.com", orgName: "Personal")
        let files = FakeFiles([home.path + "/.claude.json": state, mirror + "/.claude.json": state])
        let store = ProviderAccountsStore(defaults: try defaults())

        let result = await assembly(files, store: store, homes: AdditionalHomesSetting(claude: [mirror]))

        XCTAssertEqual(result.claudeCards.count, 1)
        XCTAssertNil(result.claudeCards[0].configDirectory)
        XCTAssertEqual(result.claudeCards[0].additionalLogDirectories, [mirror])
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records[0].sources.map(\.kind), [.defaultHome, .additionalHome])
    }

    func testAdditionalClaudeHomeWithoutIdentityIsSkipped() async throws {
        let files = FakeFiles([
            home.path + "/.claude.json": claudeState(user: userA, org: orgA, email: "me@example.com", orgName: "Personal"),
            "/Users/dev/.claude-empty/.credentials.json": credentials("orphan"),
        ])
        let store = ProviderAccountsStore(defaults: try defaults())

        let result = await assembly(files, store: store, homes: AdditionalHomesSetting(claude: ["/Users/dev/.claude-empty", "/Users/dev/.claude-missing"]))

        XCTAssertEqual(result.claudeCards.map(\.identityKey), ["\(userA)|\(orgA)"], "only the default login has a card")
        XCTAssertNil(result.claudeCards[0].configDirectory)
        XCTAssertEqual(result.identityKeysByCard, ["claude": "\(userA)|\(orgA)"])
        XCTAssertEqual(store.records.count, 1)
    }

    func testPinnedClaudeStoreReadsOnlyItsOwnHomeAndIgnoresDefaultAndEnvironmentLogins() throws {
        let work = "/Users/dev/.claude-work"
        let digest = SHA256.hash(data: Data(work.precomposedStringWithCanonicalMapping.utf8))
        let scoped = "Claude Code-credentials-" + String(digest.map { String(format: "%02x", $0) }.joined().prefix(8))
        let keychain = ServiceKeychain(currentUserValues: [
            "Claude Code-credentials": credentials("default-account"),
            scoped: credentials("work-account"),
        ])
        let store = ClaudeAuthStore(
            environment: FakeEnvironment(["CLAUDE_CODE_OAUTH_TOKEN": "env-token", "CLAUDE_CONFIG_DIR": "/wrong"]),
            files: FakeFiles([:]), keychain: keychain,
            expectedIdentityKey: "\(userB)|\(orgB)", configDirectory: work
        )

        XCTAssertEqual(store.keychainServiceCandidates(), [scoped])
        let candidates = store.loadCredentialCandidates()
        XCTAssertEqual(candidates.map(\.oauth.accessToken), ["work-account"])

        // Rotation writes back to the pinned item, never to the default login.
        var state = try XCTUnwrap(candidates.first)
        let generation = store.credentialGeneration()
        state.oauth.accessToken = "rotated"
        XCTAssertTrue(try store.save(state, ifUnchanged: generation))
        XCTAssertTrue(keychain.currentUserValues[scoped]?.contains("rotated") == true)
        XCTAssertEqual(keychain.currentUserValues["Claude Code-credentials"], credentials("default-account"))

        keychain.currentUserValues.removeValue(forKey: scoped)
        XCTAssertTrue(store.loadCredentialCandidates().isEmpty, "no fallback to another account's login")
    }
}
