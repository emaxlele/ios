import Foundation

// MARK: - SelfHostedAction

/// Actions handled by the `SelfHostedProcessor`.
///
enum SelfHostedAction: Equatable {
    // MARK: URL Actions

    /// The API server URL has changed.
    case apiUrlChanged(String)

    /// The view was dismissed.
    case dismiss

    /// The icons server URL has changed.
    case iconsUrlChanged(String)

    /// The identity server URL has changed.
    case identityUrlChanged(String)

    /// The server URL has changed.
    case serverUrlChanged(String)

    /// The web vault server URL has changed.
    case webVaultUrlChanged(String)

    // MARK: Certificate Actions

    /// The user tapped to import a client certificate.
    case importCertificateTapped

    /// A certificate file was selected.
    case certificateFileSelected(Result<URL, Error>)

    /// The user submitted a certificate alias and password.
    case certificateInfoSubmitted(alias: String, password: String)

    /// The user confirmed overwriting an existing certificate alias.
    case confirmOverwriteCertificate

    /// The user tapped to remove the current certificate.
    case removeCertificateTapped

    /// The user dismissed the certificate file importer.
    case dismissCertificateImporter

    /// A dialog was dismissed.
    case dialogDismiss

    // MARK: Equatable

    static func == (lhs: SelfHostedAction, rhs: SelfHostedAction) -> Bool {
        switch (lhs, rhs) {
        case let (.apiUrlChanged(lhsUrl), .apiUrlChanged(rhsUrl)):
            lhsUrl == rhsUrl
        case (.dismiss, .dismiss):
            true
        case let (.iconsUrlChanged(lhsUrl), .iconsUrlChanged(rhsUrl)):
            lhsUrl == rhsUrl
        case let (.identityUrlChanged(lhsUrl), .identityUrlChanged(rhsUrl)):
            lhsUrl == rhsUrl
        case let (.serverUrlChanged(lhsUrl), .serverUrlChanged(rhsUrl)):
            lhsUrl == rhsUrl
        case let (.webVaultUrlChanged(lhsUrl), .webVaultUrlChanged(rhsUrl)):
            lhsUrl == rhsUrl
        case (.importCertificateTapped, .importCertificateTapped):
            true
        case let (.certificateFileSelected(lhsResult), .certificateFileSelected(rhsResult)):
            switch (lhsResult, rhsResult) {
            case let (.success(lhsUrl), .success(rhsUrl)):
                lhsUrl == rhsUrl
            case let (.failure(lhsError), .failure(rhsError)):
                lhsError.localizedDescription == rhsError.localizedDescription
            default:
                false
            }
        case let (.certificateInfoSubmitted(lhsAlias, lhsPassword), .certificateInfoSubmitted(rhsAlias, rhsPassword)):
            lhsAlias == rhsAlias && lhsPassword == rhsPassword
        case (.confirmOverwriteCertificate, .confirmOverwriteCertificate):
            true
        case (.removeCertificateTapped, .removeCertificateTapped):
            true
        case (.dismissCertificateImporter, .dismissCertificateImporter):
            true
        case (.dialogDismiss, .dialogDismiss):
            true
        default:
            false
        }
    }
}
