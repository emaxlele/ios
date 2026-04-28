import BitwardenSdk

@testable import AuthenticatorShared

final class MockStateClient: StateClientProtocol {
    var initializeStateCalled = false
    var initializeStateError: Error?
    var registerCipherRepositoryReceivedStore: CipherRepository?
    var registerClientManagedRepositoriesReceivedRepositories: BitwardenSdk.Repositories? // swiftlint:disable:this identifier_name line_length

    func initializeState(configuration: BitwardenSdk.SqliteConfiguration) async throws {
        initializeStateCalled = true
        if let initializeStateError {
            throw initializeStateError
        }
    }

    func registerCipherRepository(repository: CipherRepository) {
        registerCipherRepositoryReceivedStore = repository
    }

    func registerClientManagedRepositories(repositories: BitwardenSdk.Repositories) {
        registerClientManagedRepositoriesReceivedRepositories = repositories
    }
}
