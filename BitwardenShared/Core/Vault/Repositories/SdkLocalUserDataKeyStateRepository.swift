import BitwardenSdk

/// `LocalUserDataKeyStateRepository` implementation to be used on SDK client-managed state.
/// Stores the wrapped user key in `AppSettingsStore` (UserDefaults) per user, keyed by the
/// SDK-assigned id. Never stores unencrypted key material.
actor SdkLocalUserDataKeyStateRepository: BitwardenSdk.LocalUserDataKeyStateRepository {
    // MARK: Properties

    /// The service for managing account state.
    private let stateService: StateService

    /// The user ID of the SDK instance this repository belongs to.
    nonisolated let userId: String

    // MARK: Initialization

    /// Initializes a `SdkLocalUserDataKeyStateRepository`.
    /// - Parameters:
    ///   - stateService: The service for managing account state.
    ///   - userId: The user ID of the SDK instance this repository belongs to.
    init(stateService: StateService, userId: String) {
        self.stateService = stateService
        self.userId = userId
    }

    // MARK: LocalUserDataKeyStateRepository

    func get(id: String) async throws -> LocalUserDataKeyState? {
        await stateService.getLocalUserDataKeyStates(userId: userId)?[id]
            .map { LocalUserDataKeyState(wrappedKey: $0.wrappedKey) }
    }

    func has(id: String) async throws -> Bool {
        await stateService.getLocalUserDataKeyStates(userId: userId)?[id] != nil
    }

    func list() async throws -> [LocalUserDataKeyState] {
        await (stateService.getLocalUserDataKeyStates(userId: userId) ?? [:])
            .values.map { LocalUserDataKeyState(wrappedKey: $0.wrappedKey) }
    }

    func remove(id: String) async throws {
        var states = await stateService.getLocalUserDataKeyStates(userId: userId) ?? [:]
        states.removeValue(forKey: id)
        await stateService.setLocalUserDataKeyStates(states.isEmpty ? nil : states, userId: userId)
    }

    func removeBulk(keys: [String]) async throws {
        var states = await stateService.getLocalUserDataKeyStates(userId: userId) ?? [:]
        for key in keys {
            states.removeValue(forKey: key)
        }
        await stateService.setLocalUserDataKeyStates(states.isEmpty ? nil : states, userId: userId)
    }

    func removeAll() async throws {
        await stateService.setLocalUserDataKeyStates(nil, userId: userId)
    }

    func set(id: String, value: LocalUserDataKeyState) async throws {
        var states = await stateService.getLocalUserDataKeyStates(userId: userId) ?? [:]
        states[id] = UserKeyData(localUserDataKeyState: value)
        await stateService.setLocalUserDataKeyStates(states, userId: userId)
    }

    func setBulk(values: [String: LocalUserDataKeyState]) async throws {
        var states = await stateService.getLocalUserDataKeyStates(userId: userId) ?? [:]
        for (id, state) in values {
            states[id] = UserKeyData(localUserDataKeyState: state)
        }
        await stateService.setLocalUserDataKeyStates(states, userId: userId)
    }
}
