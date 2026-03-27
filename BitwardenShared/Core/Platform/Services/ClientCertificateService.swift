import BitwardenResources
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
    ///   - userId: The user ID to associate with the certificate.
    /// - Returns: The imported certificate configuration.
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

        try await keychainRepository.setClientCertificateIdentity(identity, userId: userId)

        try await stateService.setClientCertificate(
            alias,
            userId: userId,
        )
    }

    func getCertificateAlias(userId: String) async -> String? {
        do {
            guard let alias = try await stateService.getClientCertificate(userId: userId) else {
                return nil
            }

            // We check if the identity actually exists in Keychain to be sure
            let identity = try await keychainRepository.getClientCertificateIdentity(userId: userId)
            if identity == nil {
                // Config says enabled, but keychain is missing it. Revert to disabled?
                // For now, return disabled state effectively, or just return the alias but runtime will fail.
                // Safest is to return nil if missing.
                return nil
            }

            return alias
        } catch {
            return nil
        }
    }

    func removeCertificate(userId: String) async throws {
        try await keychainRepository.deleteClientCertificateIdentity(userId: userId)
        try await stateService.setClientCertificate(nil, userId: userId)
    }

    func getClientCertificateIdentity(userId: String) async -> SecIdentity? {
        do {
            // We could check stateService here, but checking keychain directly is also valid
            // and potentially faster if we just need the identity.
            // However, strictly complying with "enabled" flag is good practice.
            let alias = try await stateService.getClientCertificate(userId: userId)
            guard let alias = alias, !alias.isEmpty else {
                return nil
            }
            return try await keychainRepository.getClientCertificateIdentity(userId: userId)
        } catch {
            return nil
        }
    }

    func getClientCertificateIdentity() async -> SecIdentity? {
        // Try active user first
        if let activeUserId = try? await stateService.getActiveAccountId(),
           let identity = await getClientCertificateIdentity(userId: activeUserId) {
            return identity
        }

        return await getClientCertificateIdentity(userId: DefaultClientCertificateService.preLoginUserId)
    }

    func shouldUseCertificates(userId: String) async -> Bool {
        let identity = await getClientCertificateIdentity(userId: userId)
        return identity != nil
    }

    func shouldUseCertificates() async -> Bool {
        let identity = await getClientCertificateIdentity()
        return identity != nil
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
