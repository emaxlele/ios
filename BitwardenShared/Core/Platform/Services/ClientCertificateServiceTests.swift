import TestHelpers
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

final class ClientCertificateServiceTests: BitwardenTestCase {
    // MARK: Properties

    var keychainRepository: MockKeychainRepository!
    var stateService: MockStateService!
    var subject: DefaultClientCertificateService!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        keychainRepository = MockKeychainRepository()
        stateService = MockStateService()
        subject = DefaultClientCertificateService(
            keychainRepository: keychainRepository,
            stateService: stateService,
        )
    }

    override func tearDown() {
        super.tearDown()

        keychainRepository = nil
        stateService = nil
        subject = nil
    }

    // MARK: Tests

    /// `removeCertificate(userId:)` keeps the keychain identity when another account references
    /// the same certificate fingerprint.
    func test_removeCertificate_sharedFingerprintAcrossAccounts_doesNotDeleteKeychainIdentity() async throws {
        let user1 = "1"
        let user2 = "2"
        let fingerprint = "shared-fingerprint"

        stateService.accounts = [
            .fixture(profile: .fixture(userId: user1)),
            .fixture(profile: .fixture(userId: user2)),
        ]
        stateService.activeAccount = .fixture(profile: .fixture(userId: user1))
        stateService.clientCertificateAliasByUserId[user1] = "Cert A"
        stateService.clientCertificateAliasByUserId[user2] = "Cert B"
        stateService.clientCertificateFingerprintByUserId[user1] = fingerprint
        stateService.clientCertificateFingerprintByUserId[user2] = fingerprint

        try await subject.removeCertificate(userId: user1)

        XCTAssertNil(stateService.clientCertificateAliasByUserId[user1])
        XCTAssertNil(stateService.clientCertificateFingerprintByUserId[user1])
        XCTAssertEqual(stateService.clientCertificateAliasByUserId[user2], "Cert B")
        XCTAssertEqual(stateService.clientCertificateFingerprintByUserId[user2], fingerprint)
        XCTAssertEqual(keychainRepository.deleteClientCertIdentityFingerprints, [])
    }

    /// `removeCertificate(userId:)` deletes the keychain identity when the removed user is the
    /// last reference to the certificate fingerprint.
    func test_removeCertificate_lastFingerprintReference_deletesKeychainIdentity() async throws {
        let user1 = "1"
        let fingerprint = "only-fingerprint"

        stateService.accounts = [
            .fixture(profile: .fixture(userId: user1)),
        ]
        stateService.activeAccount = .fixture(profile: .fixture(userId: user1))
        stateService.clientCertificateAliasByUserId[user1] = "Cert A"
        stateService.clientCertificateFingerprintByUserId[user1] = fingerprint

        try await subject.removeCertificate(userId: user1)

        XCTAssertEqual(keychainRepository.deleteClientCertIdentityFingerprints, [fingerprint])
    }

    /// `removeCertificate(userId:)` keeps the keychain identity when the pre-login profile still
    /// references the same certificate fingerprint.
    func test_removeCertificate_sharedWithPreLogin_doesNotDeleteKeychainIdentity() async throws {
        let user1 = "1"
        let fingerprint = "shared-with-prelogin"

        stateService.accounts = [
            .fixture(profile: .fixture(userId: user1)),
        ]
        stateService.activeAccount = .fixture(profile: .fixture(userId: user1))
        stateService.clientCertificateAliasByUserId[user1] = "Cert A"
        stateService.clientCertificateFingerprintByUserId[user1] = fingerprint
        stateService.clientCertificateAliasByUserId[DefaultClientCertificateService.preLoginUserId] = "PreLogin Cert"
        stateService.clientCertificateFingerprintByUserId[DefaultClientCertificateService.preLoginUserId] = fingerprint

        try await subject.removeCertificate(userId: user1)

        XCTAssertEqual(keychainRepository.deleteClientCertIdentityFingerprints, [])
    }

    /// `removeCertificate(userId:)` succeeds gracefully when no certificate is configured.
    func test_removeCertificate_noCertConfigured_succeeds() async throws {
        let user1 = "1"

        stateService.accounts = [
            .fixture(profile: .fixture(userId: user1)),
        ]
        stateService.activeAccount = .fixture(profile: .fixture(userId: user1))
        // No certificate configured for user1

        try await subject.removeCertificate(userId: user1)

        XCTAssertEqual(keychainRepository.deleteClientCertIdentityFingerprints, [])
    }

    /// `getClientCertificateIdentity(userId:)` returns nil when no alias is configured.
    func test_getClientCertificateIdentity_noAliasConfigured_returnsNil() async {
        let user1 = "1"

        stateService.accounts = [
            .fixture(profile: .fixture(userId: user1)),
        ]
        stateService.activeAccount = .fixture(profile: .fixture(userId: user1))
        // No certificate alias set

        let result = await subject.getClientCertificateIdentity(userId: user1)

        XCTAssertNil(result)
    }

    /// `getClientCertificateIdentity(userId:)` returns nil when the state has a fingerprint
    /// but the keychain identity is missing.
    func test_getClientCertificateIdentity_fingerprintInStateMissingFromKeychain_returnsNil() async {
        let user1 = "1"
        let fingerprint = "missing-from-keychain"

        stateService.accounts = [
            .fixture(profile: .fixture(userId: user1)),
        ]
        stateService.activeAccount = .fixture(profile: .fixture(userId: user1))
        stateService.clientCertificateAliasByUserId[user1] = "My Cert"
        stateService.clientCertificateFingerprintByUserId[user1] = fingerprint
        // Intentionally not adding to keychainRepository.storedIdentities

        let result = await subject.getClientCertificateIdentity(userId: user1)

        XCTAssertNil(result)
    }

    /// `getCertificateAlias(userId:)` returns nil when the alias is set but the keychain
    /// identity is missing.
    func test_getCertificateAlias_aliasSetButKeychainMissing_returnsNil() async {
        let user1 = "1"
        let fingerprint = "missing-from-keychain"

        stateService.accounts = [
            .fixture(profile: .fixture(userId: user1)),
        ]
        stateService.activeAccount = .fixture(profile: .fixture(userId: user1))
        stateService.clientCertificateAliasByUserId[user1] = "My Cert"
        stateService.clientCertificateFingerprintByUserId[user1] = fingerprint
        // Intentionally not adding to keychainRepository.storedIdentities (simulates external keychain wipe)

        let result = await subject.getCertificateAlias(userId: user1)

        XCTAssertNil(result)
    }

}
