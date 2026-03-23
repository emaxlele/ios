import Foundation
import Security

@testable import BitwardenShared

class MockClientCertificateService: ClientCertificateService {
    // MARK: Properties

    var importCertificateResult: Result<ClientCertificateConfiguration, Error> = .success(.enabled())
    var removeCertificateResult: Result<Void, Error> = .success(())
    var currentConfiguration: ClientCertificateConfiguration = .disabled
    var clientCertificateIdentity: SecIdentity?
    var shouldUseCertificatesResult: Bool = false

    // MARK: Call Tracking

    var importCertificateCalled = false
    var importCertificateData: Data?
    var importCertificatePassword: String?
    var importCertificateUserId: String?
    var removeCertificateCalled = false
    var removeCertificateUserId: String?

    var importCertificateAlias: String?

    // MARK: Methods

    func importCertificate(
        data: Data,
        password: String,
        alias: String,
        userId: String,
    ) async throws -> ClientCertificateConfiguration {
        importCertificateCalled = true
        importCertificateData = data
        importCertificatePassword = password
        importCertificateAlias = alias
        importCertificateUserId = userId
        return try importCertificateResult.get()
    }

    func getCurrentConfiguration(userId: String) async -> ClientCertificateConfiguration {
        currentConfiguration
    }

    func removeCertificate(userId: String) async throws {
        removeCertificateCalled = true
        removeCertificateUserId = userId
        try removeCertificateResult.get()
    }

    func getClientCertificateIdentity(userId: String) async -> SecIdentity? {
        clientCertificateIdentity
    }

    func getClientCertificateIdentity() async -> SecIdentity? {
        clientCertificateIdentity
    }

    func shouldUseCertificates(userId: String) async -> Bool {
        shouldUseCertificatesResult
    }

    func shouldUseCertificates() async -> Bool {
        shouldUseCertificatesResult
    }
}
