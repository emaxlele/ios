// swiftlint:disable:this file_name

import BitwardenSdk

extension BitwardenSdk.LocalUserDataKeyState {
    init(_ value: UserKeyData) {
        self.init(wrappedKey: value.wrappedKey)
    }
}
