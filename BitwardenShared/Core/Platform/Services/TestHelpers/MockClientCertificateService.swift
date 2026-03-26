import Foundation
import Security

@testable import BitwardenShared

class MockClientCertificateService: ClientCertificateService {
    // MARK: Properties

    var importCertificateResult: Result<Void, Error> = .success(())
    var removeCertificateResult: Result<Void, Error> = .success(())
    var currentAlias: String?
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
    ) async throws {
        importCertificateCalled = true
        importCertificateData = data
        importCertificatePassword = password
        importCertificateAlias = alias
        importCertificateUserId = userId
        try importCertificateResult.get()
    }

    func getCertificateAlias(userId: String) async -> String? {
        currentAlias
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
