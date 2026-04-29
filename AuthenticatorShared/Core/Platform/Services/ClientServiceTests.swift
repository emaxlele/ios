import BitwardenKit
import BitwardenKitMocks
import BitwardenSdk
import Testing

@testable import AuthenticatorShared
@testable import AuthenticatorSharedMocks

// MARK: - ClientServiceTests

struct ClientServiceTests {
    // MARK: Properties

    let clientBuilder: MockClientBuilder
    let configService: MockConfigService
    let errorReporter: MockErrorReporter
    let sdkRepositoryFactory: MockSdkRepositoryFactory
    let stateService: MockStateService
    let subject: DefaultClientService

    // MARK: Setup

    init() {
        clientBuilder = MockClientBuilder()
        configService = MockConfigService()
        errorReporter = MockErrorReporter()
        let factory = MockSdkRepositoryFactory()
        factory.makeCipherRepositoriesReturnValue = BitwardenSdk.Repositories(
            cipher: nil,
            folder: nil,
            userKeyState: nil,
            localUserDataKeyState: nil,
        )
        sdkRepositoryFactory = factory
        stateService = MockStateService()
        subject = DefaultClientService(
            clientBuilder: clientBuilder,
            configService: configService,
            errorReporter: errorReporter,
            sdkRepositoryFactory: sdkRepositoryFactory,
            stateService: stateService,
        )
    }

    // MARK: Tests

    /// `auth(for:)` returns and caches the same client for a given user.
    @Test
    func auth_cachesSameClientPerUser() async throws {
        let auth1 = try await subject.auth(for: "1", isPreAuth: false)
        let auth2 = try await subject.auth(for: "1", isPreAuth: false)
        #expect(auth1 === auth2)
    }

    /// `auth(for:)` returns different clients for different users.
    @Test
    func auth_returnsDifferentClientForDifferentUser() async throws {
        let auth1 = try await subject.auth(for: "1", isPreAuth: false)
        let auth2 = try await subject.auth(for: "2", isPreAuth: false)
        #expect(auth1 !== auth2)
    }

    /// `auth(for:)` falls back to the active account when `userId` is `nil`.
    @Test
    func auth_usesActiveAccountWhenUserIdIsNil() async throws {
        stateService.activeAccountId = "active-user"
        let auth = try await subject.auth(for: nil, isPreAuth: false)
        #expect(auth === clientBuilder.clients.first?.authClient)
        #expect(clientBuilder.clients.count == 1)
    }

    /// `client(for:)` called concurrently does not crash.
    @Test
    func client_calledConcurrently() async throws {
        for _ in 0 ..< 5 {
            async let concurrentTask1 = subject.auth(for: "1", isPreAuth: false)
            async let concurrentTask2 = subject.auth(for: "1", isPreAuth: false)
            _ = try await (concurrentTask1, concurrentTask2)
        }
    }

    /// Creating a client registers SDK client-managed repositories.
    @Test
    func client_registersClientManagedRepositories() async throws {
        _ = try await subject.auth(for: "1", isPreAuth: false)
        let client = try #require(clientBuilder.clients.first)
        #expect(sdkRepositoryFactory.makeCipherRepositoriesCalled)
        #expect(client.platformClient.stateMock.registerClientManagedRepositoriesReceivedRepositories != nil)
    }

    /// `crypto(for:)` returns and caches the same client for a given user.
    @Test
    func crypto_cachesSameClientPerUser() async throws {
        let crypto1 = try await subject.crypto(for: "1")
        let crypto2 = try await subject.crypto(for: "1")
        #expect(crypto1 === crypto2)
    }

    /// `removeClient(for:)` removes the cached client so a new one is created on the next call.
    @Test
    func removeClient_removesAndCreatesNewClient() async throws {
        let crypto = try await subject.crypto(for: "1")
        let cryptoAgain = try await subject.crypto(for: "1")
        #expect(crypto === cryptoAgain)

        try await subject.removeClient(for: "1")
        let cryptoAfterRemove = try await subject.crypto(for: "1")
        #expect(crypto !== cryptoAfterRemove)
    }

    /// `removeClient(for:)` with a `nil` userId removes the active account's client.
    @Test
    func removeClient_usesActiveAccountWhenUserIdIsNil() async throws {
        stateService.activeAccountId = "active-user"
        let crypto = try await subject.crypto(for: "active-user")
        try await subject.removeClient(for: nil)
        let cryptoAfterRemove = try await subject.crypto(for: "active-user")
        #expect(crypto !== cryptoAfterRemove)
    }

    /// `vault(for:)` returns a `VaultClientService` for the given user.
    @Test
    func vault() async throws {
        stateService.activeAccountId = "1"
        let vault = try await subject.vault(for: "1")
        #expect(vault === clientBuilder.clients.first?.vaultClient)

        let user2Vault = try await subject.vault(for: "2")
        #expect(vault !== user2Vault)
    }
}
