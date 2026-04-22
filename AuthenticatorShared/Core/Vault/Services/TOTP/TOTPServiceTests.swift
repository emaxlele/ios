import BitwardenKit
import BitwardenKitMocks
import XCTest

@testable import AuthenticatorShared

// MARK: - TOTPServiceTests

final class TOTPServiceTests: BitwardenTestCase {
    // MARK: Properties

    var clientService: MockClientService!
    var errorReporter: MockErrorReporter!
    var timeProvider: MockTimeProvider!
    var subject: DefaultTOTPService!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        clientService = MockClientService()
        errorReporter = MockErrorReporter()
        timeProvider = MockTimeProvider(.currentTime)

        subject = DefaultTOTPService(
            clientService: clientService,
            errorReporter: errorReporter,
            timeProvider: timeProvider,
        )
    }

    override func tearDown() {
        super.tearDown()

        clientService = nil
        errorReporter = nil
        timeProvider = nil
        subject = nil
    }

    // MARK: Tests

    func test_default_getTOTPConfiguration_base32() throws {
        let config = try subject
            .getTOTPConfiguration(key: .base32Key)
        XCTAssertNotNil(config)
    }

    func test_default_getTOTPConfiguration_otp() throws {
        let config = try subject
            .getTOTPConfiguration(key: .otpAuthUriKeyComplete)
        XCTAssertNotNil(config)
    }

    func test_default_getTOTPConfiguration_steam() throws {
        let config = try subject
            .getTOTPConfiguration(key: .steamUriKey)
        XCTAssertNotNil(config)
    }

    func test_default_getTOTPConfiguration_failure() {
        XCTAssertThrowsError(
            try subject.getTOTPConfiguration(key: "1234"),
        ) { error in
            XCTAssertEqual(
                error as? TOTPKeyError,
                .invalidKeyFormat,
            )
        }
    }

    /// `getNextTotpCode(for:currentCode:)` passes a date equal to `presentTime + period` to the SDK.
    func test_getNextTotpCode_usesNextPeriodDate() async throws {
        let fixedTime = Date(timeIntervalSince1970: 1000)
        timeProvider.timeConfig = .mockTime(fixedTime)

        let keyModel = try subject.getTOTPConfiguration(key: .base32Key)
        let currentCode = TOTPCodeModel(code: "123456", codeGenerationDate: fixedTime, period: 30)

        let result = try await subject.getNextTotpCode(for: keyModel, currentCode: currentCode)

        XCTAssertEqual(result.codeGenerationDate, fixedTime.addingTimeInterval(30))
    }

    /// `getNextTotpCode(for:currentCode:)` respects non-standard periods.
    func test_getNextTotpCode_usesNextPeriodDate_nonStandardPeriod() async throws {
        let fixedTime = Date(timeIntervalSince1970: 2000)
        timeProvider.timeConfig = .mockTime(fixedTime)
        clientService.mockVault.totpPeriod = 60

        let keyModel = try subject.getTOTPConfiguration(key: .base32Key)
        let currentCode = TOTPCodeModel(code: "123456", codeGenerationDate: fixedTime, period: 60)

        let result = try await subject.getNextTotpCode(for: keyModel, currentCode: currentCode)

        XCTAssertEqual(result.codeGenerationDate, fixedTime.addingTimeInterval(60))
    }
}
