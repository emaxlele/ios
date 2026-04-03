import Foundation
import Security

@testable import BitwardenShared

class MockClientCertificateService: ClientCertificateService {
    // MARK: Properties

    var importCertificateResult: Result<Void, Error> = .success(())
    var removeCertificateResult: Result<Void, Error> = .success(())
    var removeCertificateByUserIdResult: Result<Void, Error> = .success(())
    var currentAlias: String?
    var clientCertificateIdentity: SecIdentity?
    var shouldUseCertificatesResult: Bool = false

    // MARK: Call Tracking

    var importCertificateCalled = false
    var importCertificateData: Data?
    var importCertificatePassword: String?
    var importCertificateAlias: String?
    var removeCertificateCalled = false
    var removeCertificateByUserIdCalled = false
    var removeCertificateUserId: String?

    // MARK: Methods

    func importCertificate(
        data: Data,
        password: String,
        alias: String,
    ) async throws {
        importCertificateCalled = true
        importCertificateData = data
        importCertificatePassword = password
        importCertificateAlias = alias
        try importCertificateResult.get()
    }

    func getCertificateAlias() async -> String? {
        currentAlias
    }

    func removeCertificate() async throws {
        removeCertificateCalled = true
        try removeCertificateResult.get()
    }

    func removeCertificate(userId: String) async throws {
        removeCertificateByUserIdCalled = true
        removeCertificateUserId = userId
        try removeCertificateByUserIdResult.get()
    }

    func getClientCertificateIdentity() async -> SecIdentity? {
        clientCertificateIdentity
    }

    func shouldUseCertificates() async -> Bool {
        shouldUseCertificatesResult
    }
}
