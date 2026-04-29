import BitwardenSdk

@testable import AuthenticatorShared

final class MockClientBuilder: ClientBuilder {
    var clients = [MockClient]()
    var setupClientOnCreation: ((MockClient) -> Void)?

    func buildClient() -> BitwardenSdkClient {
        let client = MockClient()
        setupClientOnCreation?(client)
        clients.append(client)
        return client
    }
}

class MockClient: BitwardenSdkClient {
    var authClient = MockAuthClient()
    var cryptoClient = MockCryptoClient()
    var exporterClient = MockExporterClient()
    var generatorClient = MockGeneratorClient()
    var platformClient = MockPlatformClientService()
    var sendClient = MockSendClient()
    var vaultClient = MockVaultClientService()

    func auth() -> AuthClientProtocol {
        authClient
    }

    func crypto() -> CryptoClientProtocol {
        cryptoClient
    }

    func exporters() -> ExporterClientProtocol {
        exporterClient
    }

    func generators() -> GeneratorClientsProtocol {
        generatorClient
    }

    func platform() -> PlatformClientService {
        platformClient
    }

    func sends() -> SendClientProtocol {
        sendClient
    }

    func vault() -> VaultClientService {
        vaultClient
    }
}
