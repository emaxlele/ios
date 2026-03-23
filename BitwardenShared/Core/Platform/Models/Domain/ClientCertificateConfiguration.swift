import Foundation

// MARK: - ClientCertificateConfiguration

/// Configuration for client certificate authentication.
///
struct ClientCertificateConfiguration: Codable, Equatable {
    // MARK: Type Properties

    /// Creates a disabled client certificate configuration.
    static let disabled = ClientCertificateConfiguration(
        isEnabled: false,
        alias: nil,
        certificateData: nil,
    )

    // MARK: Properties

    /// Whether client certificate authentication is enabled.
    let isEnabled: Bool

    /// The alias associated with the certificate.
    let alias: String?

    /// The certificate data (PKCS#12 format) - stored for UI display only, not used for mTLS.
    let certificateData: Data?

    /// Creates an enabled client certificate configuration.
    ///
    /// - Parameters:
    ///   - alias: The alias associated with the certificate.
    ///   - certificateData: The certificate data in PKCS#12 format, if available.
    ///
    static func enabled(
        alias: String? = nil,
        certificateData: Data? = nil,
    ) -> ClientCertificateConfiguration {
        ClientCertificateConfiguration(
            isEnabled: true,
            alias: alias,
            certificateData: certificateData,
        )
    }
}
