import BitwardenKit
import BitwardenKitMocks
import Testing

@testable import AuthenticatorShared

// MARK: - StateServiceTOTPItemDisplayStateServiceTests

struct StateServiceTOTPItemDisplayStateServiceTests {
    // MARK: Properties

    let appSettingsStore: MockAppSettingsStore
    let subject: DefaultStateService

    // MARK: Initialization

    init() {
        appSettingsStore = MockAppSettingsStore()
        subject = DefaultStateService(
            appSettingsStore: appSettingsStore,
            dataStore: DataStore(errorReporter: MockErrorReporter(), storeType: .memory),
        )
    }

    // MARK: Tests

    /// `getShowNextTotpCode()` returns `false` when no value has been set.
    @Test
    func getShowNextTotpCode_defaultsFalse() async {
        let result = await subject.getShowNextTotpCode()
        #expect(result == false)
    }

    /// `setShowNextTotpCode(_:)` persists the value through `AppSettingsStore`.
    @Test
    func setShowNextTotpCode_persistsToAppSettingsStore() async {
        await subject.setShowNextTotpCode(true)
        #expect(appSettingsStore.showNextTotpCode == true)

        let result = await subject.getShowNextTotpCode()
        #expect(result == true)
    }

    /// `getShowWebIcons()` returns `true` when no value has been set (web icons enabled by default).
    @Test
    func getShowWebIcons_defaultsTrue() async {
        let result = await subject.getShowWebIcons()
        #expect(result == true)
    }

    /// `setShowWebIcons(_:)` persists the value through `AppSettingsStore`.
    @Test
    func setShowWebIcons_persistsToAppSettingsStore() async {
        await subject.setShowWebIcons(false)
        #expect(appSettingsStore.disableWebIcons == true)

        let result = await subject.getShowWebIcons()
        #expect(result == false)
    }
}
