import BitwardenSdk
import Foundation

public struct UserKeyData: Codable {
    let wrappedKey: EncString

    init(localUserDataKeyState: LocalUserDataKeyState) {
        wrappedKey = localUserDataKeyState.wrappedKey
    }
}

extension BitwardenSdk.LocalUserDataKeyState {
    init(_ value: UserKeyData) {
        self.init(wrappedKey: value.wrappedKey)
    }
}
