import BitwardenResources
import CryptoKit
import Foundation
import Security

// MARK: - ClientCertificateService

/// A service for managing client certificates used for mTLS authentication.
///
protocol ClientCertificateService: AnyObject {
    /// Import a client certificate from PKCS#12 data.
    ///
    /// - Parameters:
    ///   - data: The PKCS#12 certificate data.
    ///   - password: The password for the certificate.
    ///   - alias: The human-readable label to associate with the certificate for this user.
    ///   - userId: The user ID to associate with the certificate.
    /// - Throws: An error if the certificate cannot be imported.
    ///
    func importCertificate(
        data: Data,
        password: String,
        alias: String,
        userId: String,
    ) async throws

    func getCertificateAlias(userId: String) async -> String?

    /// Remove the client certificate for a user.
    ///
    /// - Parameter userId: The user ID associated with the certificate to remove.
    ///
    func removeCertificate(userId: String) async throws

    /// Get the client certificate identity for mTLS authentication for a user.
    ///
    /// - Parameter userId: The user ID associated with the certificate.
    /// - Returns: A SecIdentity for the certificate, or nil if no certificate is configured.
    ///
    func getClientCertificateIdentity(userId: String) async -> SecIdentity?

    /// Get the client certificate identity for mTLS authentication for the active, or pre-login, user.
    ///
    /// - Returns: A SecIdentity for the certificate, or nil if no certificate is configured.
    ///
    func getClientCertificateIdentity() async -> SecIdentity?

    /// Checks if client certificates are currently enabled and configured for a user.
    ///
    /// - Parameter userId: The user ID to check configuration for.
    /// - Returns: `true` if client certificates should be used for authentication.
    ///
    func shouldUseCertificates(userId: String) async -> Bool

    /// Checks if client certificates are currently enabled and configured for the active, or pre-login, user.
    ///
    /// - Returns: `true` if client certificates should be used for authentication.
    ///
    func shouldUseCertificates() async -> Bool
}

// MARK: - DefaultClientCertificateService

/// Default implementation of the `ClientCertificateService`.
///
final class DefaultClientCertificateService: ClientCertificateService {
    // MARK: Properties

    static let preLoginUserId = "pre_login_client_cert"

    // MARK: Private Properties

    /// The repository used to store certificate data in the keychain.
    private let keychainRepository: KeychainRepository

    /// The service used to manage application state.
    private let stateService: StateService

    // MARK: Initialization

    /// Initialize a `DefaultClientCertificateService`.
    ///
    /// - Parameters:
    ///   - keychainRepository: The repository used to store sensitive certificate data in the Keychain.
    ///   - stateService: The service used to manage application state.
    ///
    init(
        keychainRepository: KeychainRepository,
        stateService: StateService,
    ) {
        self.keychainRepository = keychainRepository
        self.stateService = stateService
    }

    // MARK: Methods

    func importCertificate(
        data: Data,
        password: String,
        alias: String,
        userId: String,
    ) async throws {
        let importOptions: [String: Any] = [
            kSecImportExportPassphrase as String: password,
        ]

        var importResult: CFArray?
        let status = SecPKCS12Import(data as CFData, importOptions as CFDictionary, &importResult)

        if status == errSecAuthFailed {
            throw ClientCertificateError.invalidPassword
        }

        guard status == errSecSuccess,
              let importArray = importResult as? [[String: Any]],
              let firstItem = importArray.first,
              let identityRef = firstItem[kSecImportItemIdentity as String] else {
            throw ClientCertificateError.invalidCertificate
        }

        // SecIdentity is a CoreFoundation type; use CFTypeRef bridge instead of conditional cast.
        let identity = identityRef as! SecIdentity // swiftlint:disable:this force_cast
        let fingerprint = try certificateFingerprint(for: identity)

        // Capture any previous fingerprint before we overwrite state — needed for old cert cleanup below.
        let previousFingerprint = try? await stateService.getCertificateFingerprint(userId: userId)

        // Only add to Keychain if this certificate isn't already stored.
        // Multiple users may share the same certificate — keyed by fingerprint, not userId.
        let existing = try await keychainRepository.getClientCertificateIdentity(fingerprint: fingerprint)
        if existing == nil {
            try await keychainRepository.setClientCertificateIdentity(identity, fingerprint: fingerprint)
        }

        // Associate the certificate with this user via alias + fingerprint in state.
        try await stateService.setClientCertificate(alias, userId: userId)
        try await stateService.setCertificateFingerprint(fingerprint, userId: userId)

        // If the user replaced a different certificate, clean up the old Keychain item
        // as long as no other user still references it.
        if let previousFingerprint, previousFingerprint != fingerprint {
            let oldStillInUse = await isFingerprintInUse(previousFingerprint, excludingUserId: userId)
            if !oldStillInUse {
                try await keychainRepository.deleteClientCertificateIdentity(fingerprint: previousFingerprint)
            }
        }
    }

    func getCertificateAlias(userId: String) async -> String? {
        do {
            guard let alias = try await stateService.getClientCertificate(userId: userId),
                  !alias.isEmpty else {
                return nil
            }

            // Verify the identity still exists in Keychain.
            guard let fingerprint = try await stateService.getCertificateFingerprint(userId: userId),
                try await keychainRepository.getClientCertificateIdentity(fingerprint: fingerprint) != nil else {
                return nil
            }

            return alias
        } catch {
            return nil
        }
    }

    func removeCertificate(userId: String) async throws {
        // Capture the fingerprint before clearing state.
        let fingerprint = try? await stateService.getCertificateFingerprint(userId: userId)

        // Clear per-user state unconditionally.
        try await stateService.setClientCertificate(nil, userId: userId)
        try await stateService.setCertificateFingerprint(nil, userId: userId)

        guard let fingerprint else { return }

        // Only delete the Keychain item if no other user still references this certificate.
        let inUse = await isFingerprintInUse(fingerprint, excludingUserId: userId)
        if !inUse {
            try await keychainRepository.deleteClientCertificateIdentity(fingerprint: fingerprint)
        }
    }

    func getClientCertificateIdentity(userId: String) async -> SecIdentity? {
        do {
            let alias = try await stateService.getClientCertificate(userId: userId)
            guard let alias, !alias.isEmpty else { return nil }

            guard let fingerprint = try await stateService.getCertificateFingerprint(userId: userId) else {
                return nil
            }
            return try await keychainRepository.getClientCertificateIdentity(fingerprint: fingerprint)
        } catch {
            return nil
        }
    }

    func getClientCertificateIdentity() async -> SecIdentity? {
        // Try active user first.
        if let activeUserId = try? await stateService.getActiveAccountId(),
           let identity = await getClientCertificateIdentity(userId: activeUserId) {
            return identity
        }

        return await getClientCertificateIdentity(userId: DefaultClientCertificateService.preLoginUserId)
    }

    func shouldUseCertificates(userId: String) async -> Bool {
        await getClientCertificateIdentity(userId: userId) != nil
    }

    func shouldUseCertificates() async -> Bool {
        await getClientCertificateIdentity() != nil
    }

    // MARK: Private

    /// Computes the SHA-256 fingerprint of the certificate within a SecIdentity.
    ///
    private func certificateFingerprint(for identity: SecIdentity) throws -> String {
        var certificate: SecCertificate?
        let status = SecIdentityCopyCertificate(identity, &certificate)
        guard status == errSecSuccess, let cert = certificate else {
            throw ClientCertificateError.invalidCertificate
        }
        let data = SecCertificateCopyData(cert) as Data
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Returns whether any user (other than the excluded one) still references the given fingerprint.
    ///
    private func isFingerprintInUse(_ fingerprint: String, excludingUserId: String) async -> Bool {
        // Check the pre-login user.
        if excludingUserId != DefaultClientCertificateService.preLoginUserId {
            let preLoginFingerprint = try? await stateService.getCertificateFingerprint(
                userId: DefaultClientCertificateService.preLoginUserId,
            )
            if preLoginFingerprint == fingerprint { return true }
        }

        // Check all regular accounts.
        let accounts = await (try? stateService.getAccounts()) ?? []
        for account in accounts {
            let accountUserId = account.profile.userId
            guard accountUserId != excludingUserId else { continue }
            let accountFingerprint = try? await stateService.getCertificateFingerprint(userId: accountUserId)
            if accountFingerprint == fingerprint { return true }
        }

        return false
    }
}

// MARK: - ClientCertificateError

/// Errors that can occur when working with client certificates.
///
enum ClientCertificateError: Error, LocalizedError {
    /// The certificate data is invalid or cannot be parsed.
    case invalidCertificate

    /// The certificate password is incorrect.
    case invalidPassword

    /// The certificate has expired.
    case certificateExpired

    var errorDescription: String? {
        switch self {
        case .invalidCertificate:
            Localizations.certificateFileInvalidOrCorrupted
        case .invalidPassword:
            Localizations.certificatePasswordIncorrect
        case .certificateExpired:
            Localizations.certificateExpired
        }
    }
}
