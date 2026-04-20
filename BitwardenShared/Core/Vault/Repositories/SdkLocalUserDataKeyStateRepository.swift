import BitwardenKit
import BitwardenSdk

/// `LocalUserDataKeyStateRepository` implementation to be used on SDK client-managed state.
/// Stores the wrapped user key in `AppSettingsStore` (UserDefaults) per user, keyed by the
/// SDK-assigned id. Never stores unencrypted key material.
final class SdkLocalUserDataKeyStateRepository: BitwardenSdk.LocalUserDataKeyStateRepository, @unchecked Sendable {
    // MARK: Properties

    /// The store for persisting local user data key states.
    private let appSettingsStore: AppSettingsStore

    /// The user ID of the SDK instance this repository belongs to.
    let userId: String

    // MARK: Initialization

    /// Initializes a `SdkLocalUserDataKeyStateRepository`.
    /// - Parameters:
    ///   - appSettingsStore: The store for persisting local user data key states.
    ///   - userId: The user ID of the SDK instance this repository belongs to.
    init(appSettingsStore: AppSettingsStore, userId: String) {
        self.appSettingsStore = appSettingsStore
        self.userId = userId
    }

    // MARK: LocalUserDataKeyStateRepository

    func get(id: String) async throws -> LocalUserDataKeyState? {
        appSettingsStore.localUserDataKeyStates(userId: userId)?[id]
            .map { LocalUserDataKeyState(wrappedKey: $0) }
    }

    func has(id: String) async throws -> Bool {
        appSettingsStore.localUserDataKeyStates(userId: userId)?[id] != nil
    }

    func list() async throws -> [LocalUserDataKeyState] {
        (appSettingsStore.localUserDataKeyStates(userId: userId) ?? [:])
            .values.map { LocalUserDataKeyState(wrappedKey: $0) }
    }

    func remove(id: String) async throws {
        var states = appSettingsStore.localUserDataKeyStates(userId: userId) ?? [:]
        states.removeValue(forKey: id)
        appSettingsStore.setLocalUserDataKeyStates(states.isEmpty ? nil : states, userId: userId)
    }

    func removeBulk(keys: [String]) async throws {
        var states = appSettingsStore.localUserDataKeyStates(userId: userId) ?? [:]
        for key in keys {
            states.removeValue(forKey: key)
        }
        appSettingsStore.setLocalUserDataKeyStates(states.isEmpty ? nil : states, userId: userId)
    }

    func removeAll() async throws {
        appSettingsStore.setLocalUserDataKeyStates(nil, userId: userId)
    }

    func set(id: String, value: LocalUserDataKeyState) async throws {
        var states = appSettingsStore.localUserDataKeyStates(userId: userId) ?? [:]
        states[id] = value.wrappedKey
        appSettingsStore.setLocalUserDataKeyStates(states, userId: userId)
    }

    func setBulk(values: [String: LocalUserDataKeyState]) async throws {
        var states = appSettingsStore.localUserDataKeyStates(userId: userId) ?? [:]
        for (id, state) in values {
            states[id] = state.wrappedKey
        }
        appSettingsStore.setLocalUserDataKeyStates(states, userId: userId)
    }
}
