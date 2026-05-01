import Foundation

/// A service that provides state management functionality for `UserKeyData`.
public protocol LocalUserDataStateService {
    /// Gets the local user data keys for the user ID
    ///
    /// - Parameters:
    ///   - userId: The user ID of the account.
    ///
    /// - Returns: A dictionary mapping SDK-assigned key identifiers to `UserKeyData`.
    ///
    func getLocalUserDataKeyStates(userId: String) async -> [String: UserKeyData]?

    /// Removes a single `UserKeyData` state for the user.
    ///
    /// - Parameters:
    ///   - id: The SDK-assigned key identifier.
    ///   - userId: The user ID of the account.
    ///
    func removeLocalUserDataKeyState(id: String, userId: String) async

    /// Removes all local user data key states for the user.
    ///
    /// - Parameter userId: The user ID of the account.
    ///
    func removeAllLocalUserDataKeyStates(userId: String) async

    /// Removes multiple `UserKeyData` states for the user.
    ///
    /// - Parameters:
    ///   - keys: The SDK-assigned key identifiers to remove.
    ///   - userId: The user ID of the account.
    ///
    func removeBulkLocalUserDataKeyStates(keys: [String], userId: String) async

    /// Sets a single `UserKeyData` state for the user.
    /// ///
    /// - Parameters:
    ///   - id: The SDK-assigned key identifier.
    ///   - value: The `UserKeyData` to store.
    ///   - userId: The user ID of the account.
    ///
    func setLocalUserDataKeyState(id: String, value: UserKeyData, userId: String) async

    /// Merges multiple `UserKeyData` states for the user.
    ///
    /// - Parameters:
    ///   - values: A dictionary mapping SDK-assigned key identifiers to `UserKeyData`.
    ///   - userId: The user ID of the account.
    ///
    func setBulkLocalUserDataKeyStates(_ values: [String: UserKeyData], userId: String) async
}
