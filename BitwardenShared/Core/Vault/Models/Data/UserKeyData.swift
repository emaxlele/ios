import BitwardenSdk
import Foundation

public struct UserKeyData: Codable {
    let wrappedKey: EncString

    init(localUserDataKeyState: LocalUserDataKeyState) {
        wrappedKey = localUserDataKeyState.wrappedKey
    }
}
