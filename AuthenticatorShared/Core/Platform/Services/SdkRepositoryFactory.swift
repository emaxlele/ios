import BitwardenKit
import BitwardenSdk

/// A factory to create SDK repositories for the Authenticator target.
protocol SdkRepositoryFactory { // sourcery: AutoMockable
    /// Makes a `BitwardenSdk.Repositories` for the given `userId`.
    /// - Parameter userId: The user ID to use in the repository which belongs to the SDK instance
    /// the repository will be registered in.
    /// - Returns: The repositories for the given `userId`.
    func makeCipherRepositories(userId: String?) -> BitwardenSdk.Repositories
}

/// Default implementation of `SdkRepositoryFactory`.
struct DefaultSdkRepositoryFactory: SdkRepositoryFactory {
    // MARK: Properties

    /// The store for persisting local user data key states.
    private let appSettingsStore: AppSettingsStore

    // MARK: Init

    /// Initializes a `DefaultSdkRepositoryFactory`.
    /// - Parameter appSettingsStore: The store for persisting local user data key states.
    init(appSettingsStore: AppSettingsStore) {
        self.appSettingsStore = appSettingsStore
    }

    // MARK: Methods

    func makeCipherRepositories(userId: String?) -> BitwardenSdk.Repositories {
        let resolvedUserId = userId ?? appSettingsStore.localUserId
        return Repositories(
            cipher: nil,
            folder: nil,
            userKeyState: nil,
            localUserDataKeyState: SdkLocalUserDataKeyStateRepository(
                appSettingsStore: appSettingsStore,
                userId: resolvedUserId,
            ),
            ephemeralPinEnvelopeState: nil,
        )
    }
}
