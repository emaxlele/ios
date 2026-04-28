import BitwardenKit
import BitwardenSdk

/// A factory to create SDK repositories.
protocol SdkRepositoryFactory { // sourcery: AutoMockable
    /// Makes a `BitwardenSdk.Repositories` for the given `userId`.
    /// - Parameter userId: The user ID to use in the repository which belongs to the SDK instance
    /// the repository will be registered in.
    /// - Returns: The repositories for the given `userId`.
    func makeCipherRepositories(userId: String?) -> BitwardenSdk.Repositories

    /// Makes a `BitwardenSdk.ServerCommunicationConfigRepository`.
    /// - Returns: The repository to use for server communication config.
    func makeServerCommunicationConfigRepository() -> BitwardenSdk.ServerCommunicationConfigRepository
}

/// Default implementation of `SdkRepositoryFactory`.
struct DefaultSdkRepositoryFactory: SdkRepositoryFactory {
    // MARK: Properties

    /// The store for persisting local user data key states.
    private let appSettingsStore: AppSettingsStore
    /// The data store for managing the persisted ciphers for the user.
    private let cipherDataStore: CipherDataStore
    /// The service that provides state management functionality for the
    /// server communication configuration.
    private let serverCommunicationConfigStateService: ServerCommunicationConfigStateService

    // MARK: Init

    /// Initializes a `DefaultSdkRepositoryFactory`.
    /// - Parameters:
    ///   - appSettingsStore: The store for persisting local user data key states.
    ///   - cipherDataStore: The data store for managing the persisted ciphers for the user.
    ///   - serverCommunicationConfigStateService: The service that provides state management functionality for the
    /// server communication configuration.
    init(
        appSettingsStore: AppSettingsStore,
        cipherDataStore: CipherDataStore,
        serverCommunicationConfigStateService: ServerCommunicationConfigStateService,
    ) {
        self.appSettingsStore = appSettingsStore
        self.cipherDataStore = cipherDataStore
        self.serverCommunicationConfigStateService = serverCommunicationConfigStateService
    }

    // MARK: Methods

    func makeCipherRepositories(userId: String?) -> BitwardenSdk.Repositories {
        let resolvedUserId = userId ?? appSettingsStore.cachedActiveUserId ?? ""
        return Repositories(
            cipher: makeCipherRepository(userId: resolvedUserId),
            folder: nil,
            userKeyState: nil,
            localUserDataKeyState: SdkLocalUserDataKeyStateRepository(
                appSettingsStore: appSettingsStore,
                userId: resolvedUserId,
            ),
        )
    }

    func makeCipherRepository(userId: String) -> BitwardenSdk.CipherRepository {
        SdkCipherRepository(
            cipherDataStore: cipherDataStore,
            userId: userId,
        )
    }

    func makeServerCommunicationConfigRepository() -> BitwardenSdk.ServerCommunicationConfigRepository {
        SdkServerCommunicationConfigRepository(
            serverCommunicationConfigStateService: serverCommunicationConfigStateService,
        )
    }
}
