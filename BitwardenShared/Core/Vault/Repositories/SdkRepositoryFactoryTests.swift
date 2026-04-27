import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

// MARK: - SdkRepositoryFactoryTests

class SdkRepositoryFactoryTests: BitwardenTestCase {
    // MARK: Properties

    var appSettingsStore: MockAppSettingsStore!
    var cipherDataStore: MockCipherDataStore!
    var serverCommunicationConfigStateService: MockServerCommunicationConfigStateService!
    var subject: SdkRepositoryFactory!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        appSettingsStore = MockAppSettingsStore()
        cipherDataStore = MockCipherDataStore()
        serverCommunicationConfigStateService = MockServerCommunicationConfigStateService()
        subject = DefaultSdkRepositoryFactory(
            appSettingsStore: appSettingsStore,
            cipherDataStore: cipherDataStore,
            serverCommunicationConfigStateService: serverCommunicationConfigStateService,
        )
    }

    override func tearDown() {
        super.tearDown()

        appSettingsStore = nil
        cipherDataStore = nil
        serverCommunicationConfigStateService = nil
        subject = nil
    }

    // MARK: Tests

    /// `makeCipherRepositories(userId:)` returns repositories with a cipher and local user data key state repository.
    func test_makeCipherRepositories() {
        let repositories = subject.makeCipherRepositories(userId: "1")
        XCTAssertNotNil(repositories.cipher)
        XCTAssertNil(repositories.folder)
        XCTAssertNil(repositories.userKeyState)
        XCTAssertNotNil(repositories.localUserDataKeyState)
        XCTAssertNil(repositories.ephemeralPinEnvelopeState)
    }

    /// `makeServerCommunicationConfigRepository()` makes a server communication config repository.
    func test_makeServerCommunicationConfigRepository() {
        let repository = subject.makeServerCommunicationConfigRepository()
        XCTAssertTrue(repository is SdkServerCommunicationConfigRepository)
    }
}
