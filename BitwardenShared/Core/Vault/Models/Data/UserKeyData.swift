import BitwardenSdk
import Foundation

public struct UserKeyData: Codable, Equatable {
    let wrappedKey: EncString

    init(wrappedKey: EncString) {
        self.wrappedKey = wrappedKey
    }

    init(localUserDataKeyState: LocalUserDataKeyState) {
        self.init(wrappedKey: localUserDataKeyState.wrappedKey)
    }
}
