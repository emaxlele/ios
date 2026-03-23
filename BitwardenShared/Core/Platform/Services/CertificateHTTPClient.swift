import Foundation
import Networking

/// An HTTP client that supports client certificate authentication for mTLS.
///
final class CertificateHTTPClient: NSObject, HTTPClient, @unchecked Sendable {
    // MARK: Properties

    /// The certificate service for retrieving client certificates.
    private let certificateService: ClientCertificateService

    /// The underlying URL session.
    private var urlSession: URLSession!

    // MARK: Initialization

    /// Initialize a `CertificateHTTPClient`.
    ///
    /// - Parameter certificateService: The service used to retrieve client certificates.
    ///
    init(certificateService: ClientCertificateService) {
        self.certificateService = certificateService
        super.init()

        // Create a session configuration with a delegate
        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil,
        )
    }

    // MARK: HTTPClient

    func download(from urlRequest: URLRequest) async throws -> URL {
        // Use the URLSession extension method
        try await urlSession.download(from: urlRequest)
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        // Use the URLSession extension method
        try await urlSession.send(request)
    }
}

// MARK: - URLSessionDelegate

extension CertificateHTTPClient: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void,
    ) {
        // Handle client certificate authentication challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        Task {
            guard let identity = await certificateService.getClientCertificateIdentity() else {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            // Create the credential with the identity
            let credential = URLCredential(
                identity: identity,
                certificates: nil,
                persistence: .forSession,
            )
            completionHandler(.useCredential, credential)
        }
    }
}
