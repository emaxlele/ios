import Foundation

/// A protocol for an object that stores and retrieves `UserKeyData`.
public protocol LocalUserDataKeyAppSettingsStore {
    /// Sets the local `UserKeyData` states for a user ID.
    ///
    /// - Parameters:
    ///   - states: A dictionary mapping key IDs to `UserKeyData`.
    ///   - userId: The user ID associated with the key states.
    ///
    func setLocalUserDataKeyStates(_ states: [String: UserKeyData]?, userId: String)

    /// Gets the local `UserKeyData` states for the user ID.
    ///
    /// - Parameter userId: The user ID associated with the key states.
    /// - Returns: A dictionary mapping key ID to encrypted wrapped key string.
    ///
    func localUserDataKeyStates(userId: String) -> [String: UserKeyData]?
}
