// swiftlint:disable:this file_name

import BitwardenKit
import BitwardenKitMocks
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

// MARK: - StateServiceBillingStateServiceTests

class StateServiceBillingStateServiceTests: BitwardenTestCase {
    // MARK: Properties

    var appSettingsStore: MockAppSettingsStore!
    var dataStore: DataStore!
    var errorReporter: MockErrorReporter!
    var keychainRepository: MockKeychainRepository!
    var timeProvider: MockTimeProvider!
    var userSessionKeychainRepository: MockUserSessionKeychainRepository!
    var subject: DefaultStateService!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        appSettingsStore = MockAppSettingsStore()
        dataStore = DataStore(errorReporter: MockErrorReporter(), storeType: .memory)
        errorReporter = MockErrorReporter()
        keychainRepository = MockKeychainRepository()
        timeProvider = MockTimeProvider(.currentTime)
        userSessionKeychainRepository = MockUserSessionKeychainRepository()

        subject = DefaultStateService(
            appSettingsStore: appSettingsStore,
            dataStore: dataStore,
            errorReporter: errorReporter,
            keychainRepository: keychainRepository,
            timeProvider: timeProvider,
            userSessionKeychainRepository: userSessionKeychainRepository,
        )
    }

    override func tearDown() {
        super.tearDown()

        appSettingsStore = nil
        dataStore = nil
        errorReporter = nil
        keychainRepository = nil
        subject = nil
        timeProvider = nil
        userSessionKeychainRepository = nil
    }

    // MARK: Tests

    /// `isPremiumUpgradeEligible()` returns `true` when user is free and account is 7+ days old.
    func test_isPremiumUpgradeEligible_true() async {
        let fixedDate = Date(timeIntervalSince1970: 1_000_000_000)
        timeProvider.timeConfig = .mockTime(fixedDate)
        let creationDate = fixedDate.addingTimeInterval(-Constants.premiumUpgradeBannerAccountAge - 1)
        await subject.addAccount(.fixture(profile: .fixture(
            creationDate: creationDate,
            hasPremiumPersonally: false,
        )))

        let isEligible = await subject.isPremiumUpgradeEligible()
        XCTAssertTrue(isEligible)
    }

    /// `isPremiumUpgradeEligible()` returns `false` when user has premium.
    func test_isPremiumUpgradeEligible_hasPremium() async {
        let fixedDate = Date(timeIntervalSince1970: 1_000_000_000)
        timeProvider.timeConfig = .mockTime(fixedDate)
        let creationDate = fixedDate.addingTimeInterval(-Constants.premiumUpgradeBannerAccountAge - 1)
        await subject.addAccount(.fixture(profile: .fixture(
            creationDate: creationDate,
            hasPremiumPersonally: true,
        )))
        appSettingsStore.premiumUpgradeBannerDismissedByUserId["1"] = false

        let shouldShow = await subject.isPremiumUpgradeEligible()
        XCTAssertFalse(shouldShow)
    }

    /// `isPremiumUpgradeEligible()` returns `true` even when the banner has been dismissed,
    /// since dismissal is a separate concern checked via `isPremiumUpgradeBannerDismissed()`.
    func test_isPremiumUpgradeEligible_bannerDismissedDoesNotAffectEligibility() async {
        let fixedDate = Date(timeIntervalSince1970: 1_000_000_000)
        timeProvider.timeConfig = .mockTime(fixedDate)
        let creationDate = fixedDate.addingTimeInterval(-Constants.premiumUpgradeBannerAccountAge - 1)
        await subject.addAccount(.fixture(profile: .fixture(
            creationDate: creationDate,
            hasPremiumPersonally: false,
        )))
        appSettingsStore.premiumUpgradeBannerDismissedByUserId["1"] = true

        let isEligible = await subject.isPremiumUpgradeEligible()
        XCTAssertTrue(isEligible)
    }

    /// `isPremiumUpgradeBannerDismissed()` returns `true` when the banner has been dismissed.
    func test_isPremiumUpgradeBannerDismissed_true() async {
        await subject.addAccount(.fixture())
        appSettingsStore.premiumUpgradeBannerDismissedByUserId["1"] = true

        let isDismissed = await subject.isPremiumUpgradeBannerDismissed()
        XCTAssertTrue(isDismissed)
    }

    /// `isPremiumUpgradeBannerDismissed()` returns `false` when the banner has not been dismissed.
    func test_isPremiumUpgradeBannerDismissed_false() async {
        await subject.addAccount(.fixture())
        appSettingsStore.premiumUpgradeBannerDismissedByUserId["1"] = false

        let isDismissed = await subject.isPremiumUpgradeBannerDismissed()
        XCTAssertFalse(isDismissed)
    }

    /// `isPremiumUpgradeEligible()` returns `false` when account is less than 7 days old.
    func test_isPremiumUpgradeEligible_accountTooNew() async {
        let fixedDate = Date(timeIntervalSince1970: 1_000_000_000)
        timeProvider.timeConfig = .mockTime(fixedDate)
        let creationDate = fixedDate.addingTimeInterval(-Constants.premiumUpgradeBannerAccountAge + 1)
        await subject.addAccount(.fixture(profile: .fixture(
            creationDate: creationDate,
            hasPremiumPersonally: false,
        )))
        appSettingsStore.premiumUpgradeBannerDismissedByUserId["1"] = false

        let shouldShow = await subject.isPremiumUpgradeEligible()
        XCTAssertFalse(shouldShow)
    }

    /// `isPremiumUpgradeEligible()` returns `false` when account has no creation date.
    func test_isPremiumUpgradeEligible_noCreationDate() async {
        await subject.addAccount(.fixture(profile: .fixture(
            creationDate: nil,
            hasPremiumPersonally: false,
        )))
        appSettingsStore.premiumUpgradeBannerDismissedByUserId["1"] = false

        let shouldShow = await subject.isPremiumUpgradeEligible()
        XCTAssertFalse(shouldShow)
    }
}
