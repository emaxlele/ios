import BitwardenSdk
import Foundation

/// A type mirroring `BitwardenSdk.LocalUserDataKeyState`. Used for serialization.
public struct UserKeyData: Codable, Equatable {
    let wrappedKey: EncString

    init(wrappedKey: EncString) {
        self.wrappedKey = wrappedKey
    }

    init(localUserDataKeyState: LocalUserDataKeyState) {
        self.init(wrappedKey: localUserDataKeyState.wrappedKey)
    }
}
