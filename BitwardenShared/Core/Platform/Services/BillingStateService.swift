import Foundation

// MARK: - BillingStateService

/// A service that provides state management functionality around billing.
///
protocol BillingStateService { // sourcery: AutoMockable
    /// Returns whether the premium upgrade banner has been permanently dismissed by the user.
    ///
    /// - Returns: `true` if the user has dismissed the banner.
    ///
    func isPremiumUpgradeBannerDismissed() async -> Bool

    /// Returns whether the user meets the eligibility criteria for the premium upgrade.
    ///
    /// - Returns: `true` if the user is eligible for the premium upgrade.
    ///
    func isPremiumUpgradeEligible() async -> Bool
}
