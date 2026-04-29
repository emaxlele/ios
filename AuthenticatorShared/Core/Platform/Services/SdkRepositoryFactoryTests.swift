import Testing

@testable import AuthenticatorShared

// MARK: - SdkRepositoryFactoryTests

struct SdkRepositoryFactoryTests {
    // MARK: Properties

    let appSettingsStore: MockAppSettingsStore
    let subject: SdkRepositoryFactory

    // MARK: Setup

    init() {
        appSettingsStore = MockAppSettingsStore()
        subject = DefaultSdkRepositoryFactory(appSettingsStore: appSettingsStore)
    }

    // MARK: Tests

    /// `makeCipherRepositories(userId:)` returns repositories with a local user data key state repository.
    @Test
    func makeCipherRepositories() {
        let repositories = subject.makeCipherRepositories(userId: "1")
        #expect(repositories.cipher == nil)
        #expect(repositories.folder == nil)
        #expect(repositories.userKeyState == nil)
        #expect(repositories.localUserDataKeyState != nil)
    }
}
