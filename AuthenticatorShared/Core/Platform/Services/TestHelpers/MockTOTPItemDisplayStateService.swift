import Combine

@testable import AuthenticatorShared

class MockTOTPItemDisplayStateService: TOTPItemDisplayStateService {
    // MARK: Properties

    /// The value returned by `getShowNextTotpCode()`, and updated by `setShowNextTotpCode(_:)`.
    var showNextTotpCode = false

    /// The value returned by `getShowWebIcons()`, and updated by `setShowWebIcons(_:)`.
    var showWebIcons = true

    /// Subject used to back `showWebIconsPublisher()`.
    var showWebIconsSubject = CurrentValueSubject<Bool, Never>(true)

    // MARK: TOTPItemDisplayStateService

    func getShowNextTotpCode() async -> Bool {
        showNextTotpCode
    }

    func setShowNextTotpCode(_ value: Bool) async {
        showNextTotpCode = value
    }

    func getShowWebIcons() async -> Bool {
        showWebIcons
    }

    func setShowWebIcons(_ showWebIcons: Bool) async {
        self.showWebIcons = showWebIcons
        showWebIconsSubject.send(showWebIcons)
    }

    func showWebIconsPublisher() async -> AnyPublisher<Bool, Never> {
        showWebIconsSubject.eraseToAnyPublisher()
    }
}
