import BitwardenKitMocks
import TestHelpers
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

class BillingRepositoryTests: BitwardenTestCase {
    // MARK: Properties

    var configService: MockConfigService!
    var errorReporter: MockErrorReporter!
    var stateService: MockStateService!
    var storefrontService: MockStorefrontService!
    var subject: DefaultBillingRepository!
    var vaultRepository: MockVaultRepository!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        configService = MockConfigService()
        errorReporter = MockErrorReporter()
        stateService = MockStateService()
        storefrontService = MockStorefrontService()
        vaultRepository = MockVaultRepository()

        subject = DefaultBillingRepository(
            configService: configService,
            errorReporter: errorReporter,
            stateService: stateService,
            storefrontService: storefrontService,
            vaultRepository: vaultRepository,
        )
    }

    override func tearDown() {
        super.tearDown()

        configService = nil
        errorReporter = nil
        stateService = nil
        storefrontService = nil
        subject = nil
        vaultRepository = nil
    }

    // MARK: Tests

    /// `isInAppUpgradeAvailable()` returns `true` when all conditions are met.
    @MainActor
    func test_isInAppUpgradeAvailable_allConditionsMet() async {
        configService.featureFlagsBool[.premiumUpgradePath] = true
        storefrontService.isUSStorefrontReturnValue = true
        stateService.isPremiumUpgradeEligibleResult = true
        vaultRepository.hasMinimumCipherCountResult = .success(true)

        let result = await subject.isInAppUpgradeAvailable()

        XCTAssertTrue(result)
    }

    /// `isInAppUpgradeAvailable()` returns `false` when the feature flag is disabled.
    @MainActor
    func test_isInAppUpgradeAvailable_featureFlagDisabled() async {
        configService.featureFlagsBool[.premiumUpgradePath] = false
        storefrontService.isUSStorefrontReturnValue = true
        stateService.isPremiumUpgradeEligibleResult = true
        vaultRepository.hasMinimumCipherCountResult = .success(true)

        let result = await subject.isInAppUpgradeAvailable()

        XCTAssertFalse(result)
    }

    /// `isInAppUpgradeAvailable()` returns `false` when the storefront is not US.
    @MainActor
    func test_isInAppUpgradeAvailable_nonUSStorefront() async {
        configService.featureFlagsBool[.premiumUpgradePath] = true
        storefrontService.isUSStorefrontReturnValue = false
        stateService.isPremiumUpgradeEligibleResult = true
        vaultRepository.hasMinimumCipherCountResult = .success(true)

        let result = await subject.isInAppUpgradeAvailable()

        XCTAssertFalse(result)
    }

    /// `isInAppUpgradeAvailable()` returns `false` when the user is not eligible for premium upgrade.
    @MainActor
    func test_isInAppUpgradeAvailable_notEligible() async {
        configService.featureFlagsBool[.premiumUpgradePath] = true
        storefrontService.isUSStorefrontReturnValue = true
        stateService.isPremiumUpgradeEligibleResult = false
        vaultRepository.hasMinimumCipherCountResult = .success(true)

        let result = await subject.isInAppUpgradeAvailable()

        XCTAssertFalse(result)
    }

    /// `isInAppUpgradeAvailable()` returns `false` when the vault has fewer than the minimum cipher count.
    @MainActor
    func test_isInAppUpgradeAvailable_insufficientCipherCount() async {
        configService.featureFlagsBool[.premiumUpgradePath] = true
        storefrontService.isUSStorefrontReturnValue = true
        stateService.isPremiumUpgradeEligibleResult = true
        vaultRepository.hasMinimumCipherCountResult = .success(false)

        let result = await subject.isInAppUpgradeAvailable()

        XCTAssertFalse(result)
    }

    /// `isInAppUpgradeAvailable()` returns `false` and logs the error when `hasMinimumCipherCount` throws.
    @MainActor
    func test_isInAppUpgradeAvailable_cipherCountThrows() async {
        configService.featureFlagsBool[.premiumUpgradePath] = true
        storefrontService.isUSStorefrontReturnValue = true
        stateService.isPremiumUpgradeEligibleResult = true
        vaultRepository.hasMinimumCipherCountResult = .failure(BitwardenTestError.example)

        let result = await subject.isInAppUpgradeAvailable()

        XCTAssertFalse(result)
        XCTAssertEqual(errorReporter.errors as? [BitwardenTestError], [.example])
    }
}
