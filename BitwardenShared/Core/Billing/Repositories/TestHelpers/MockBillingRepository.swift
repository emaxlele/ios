@testable import BitwardenShared

class MockBillingRepository: BillingRepository {
    var isInAppUpgradeAvailableCalled = false
    var isInAppUpgradeAvailableReturnValue = false

    func isInAppUpgradeAvailable() async -> Bool {
        isInAppUpgradeAvailableCalled = true
        return isInAppUpgradeAvailableReturnValue
    }
}
