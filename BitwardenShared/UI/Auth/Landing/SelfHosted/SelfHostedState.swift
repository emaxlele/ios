import Foundation

/// The storage host type for a mutual TLS client certificate key.
///
enum MutualTlsKeyHost: String {
    /// The certificate identity was imported and is stored in the app's keychain.
    case keychain = "KEYCHAIN"
}

// MARK: - SelfHostedState

/// An object that defines the current state of a `SelfHostedView`.
///
struct SelfHostedState: Equatable {
    // MARK: Subtypes

    /// Represents the possible dialog states for the client certificate section.
    ///
    enum DialogState: Equatable {
        /// The alias and password input dialog shown after a certificate file is selected.
        case setCertificateData(certificateData: Data)

        /// An error dialog.
        case error(message: String)

        /// A confirmation dialog presented when the entered alias matches an existing certificate.
        case confirmOverwriteAlias(alias: String, certificateData: Data, password: String)
    }

    // MARK: Environment URLs

    /// The API server URL.
    var apiServerUrl: String = ""

    /// The icons server URL.
    var iconsServerUrl: String = ""

    /// The identity server URL.
    var identityServerUrl: String = ""

    /// The server URL.
    var serverUrl: String = ""

    /// The web vault server URL.
    var webVaultServerUrl: String = ""

    // MARK: Client Certificate

    /// The client certificate configuration.
    var clientCertificateConfiguration: ClientCertificateConfiguration = .disabled

    /// The alias of the currently configured client certificate.
    var keyAlias: String = ""

    /// The storage host for the currently configured client certificate key.
    var keyHost: MutualTlsKeyHost?

    /// A URI encoding the key host and alias (e.g. `cert://KEYCHAIN/myAlias`).
    var keyUri: String? {
        guard let keyHost, !keyAlias.isEmpty else { return nil }
        return "cert://\(keyHost.rawValue)/\(keyAlias)"
    }

    // MARK: Certificate Import Dialog

    /// The active dialog state for the client certificate section.
    var dialog: DialogState?

    /// Whether the certificate file importer is showing.
    var showingCertificateImporter: Bool = false

    /// The certificate data temporarily stored while waiting for password input.
    var pendingCertificateData: Data?
}
