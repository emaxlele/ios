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

    /// `getNextTotpCode(for:)` returns the code from the SDK for the next period window.
    func test_getNextTotpCode_returnsCode() async throws {
        let keyModel = try XCTUnwrap(TOTPKeyModel(authenticatorKey: .base32Key))
        let result = try await subject.getNextTotpCode(for: keyModel)

        XCTAssertEqual(result.code, "123456")
        XCTAssertEqual(result.period, 30)
    }

    /// `getNextTotpCode(for:)` passes a date one period ahead of the current time to the SDK.
    func test_getNextTotpCode_usesNextPeriodDate() async throws {
        let fixedDate = Date(timeIntervalSinceReferenceDate: 1_000_000)
        timeProvider = MockTimeProvider(.mockTime(fixedDate))
        subject = DefaultTOTPService(
            clientService: clientService,
            errorReporter: errorReporter,
            timeProvider: timeProvider,
        )
        let keyModel = try XCTUnwrap(TOTPKeyModel(authenticatorKey: .base32Key))

        let result = try await subject.getNextTotpCode(for: keyModel)

        // The SDK mock stores the passed date as codeGenerationDate
        let expectedDate = Date(
            timeIntervalSinceReferenceDate: fixedDate.timeIntervalSinceReferenceDate
                + Double(keyModel.period),
        )
        XCTAssertEqual(result.codeGenerationDate, expectedDate)
    }
}
