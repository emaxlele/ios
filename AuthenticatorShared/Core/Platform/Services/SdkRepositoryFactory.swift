import BitwardenKit
import BitwardenSdk

/// A factory to create SDK repositories for the Authenticator target.
protocol SdkRepositoryFactory { // sourcery: AutoMockable
    /// Makes a `BitwardenSdk.Repositories` for the given `userId`.
    /// - Parameter userId: The user ID to use in the repository which belongs to the SDK instance
    /// the repository will be registered in.
    /// - Returns: The repositories for the given `userId`.
    func makeCipherRepositories(userId: String) -> Repositories
}

/// Default implementation of `SdkRepositoryFactory`.
struct DefaultSdkRepositoryFactory: SdkRepositoryFactory {
    // MARK: Properties

    /// The service for managing account state.
    private let stateService: StateService

    // MARK: Init

    /// Initializes a `DefaultSdkRepositoryFactory`.
    /// - Parameter stateService: The service for managing account state.
    init(stateService: StateService) {
        self.stateService = stateService
    }

    // MARK: Methods

    func makeCipherRepositories(userId: String) -> Repositories {
        Repositories(
            cipher: nil,
            folder: nil,
            userKeyState: nil,
            localUserDataKeyState: SdkLocalUserDataKeyStateRepository(
                stateService: stateService,
                userId: userId,
            ),
        )
    }
}
