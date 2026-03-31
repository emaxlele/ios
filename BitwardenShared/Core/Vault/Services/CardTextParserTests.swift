import XCTest

@testable import BitwardenShared

// MARK: - CardTextParserTests

class CardTextParserTests: BitwardenTestCase {
    // MARK: Properties

    var subject: DefaultCardTextParser!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()
        subject = DefaultCardTextParser()
    }

    override func tearDown() {
        super.tearDown()
        subject = nil
    }

    // MARK: Tests – Card Number

    /// `parseCard(lines:)` extracts a 16-digit Visa card number from a single line.
    func test_parseCard_extractsCardNumber_visa() {
        let result = subject.parseCard(lines: ["4111111111111111"])
        XCTAssertEqual(result.cardNumber, "4111111111111111")
    }

    /// `parseCard(lines:)` strips spaces from a card number written in 4-digit groups.
    func test_parseCard_extractsCardNumber_withSpaces() {
        let result = subject.parseCard(lines: ["4111 1111 1111 1111"])
        XCTAssertEqual(result.cardNumber, "4111111111111111")
    }

    /// `parseCard(lines:)` strips dashes from a card number written with dashes.
    func test_parseCard_extractsCardNumber_withDashes() {
        let result = subject.parseCard(lines: ["4111-1111-1111-1111"])
        XCTAssertEqual(result.cardNumber, "4111111111111111")
    }

    /// `parseCard(lines:)` extracts a 15-digit Amex card number.
    func test_parseCard_extractsCardNumber_amex() {
        let result = subject.parseCard(lines: ["378282246310005"])
        XCTAssertEqual(result.cardNumber, "378282246310005")
    }

    /// `parseCard(lines:)` extracts a 13-digit Visa card number (minimum length).
    func test_parseCard_extractsCardNumber_minimumLength() {
        let result = subject.parseCard(lines: ["4012888888881"])
        XCTAssertEqual(result.cardNumber, "4012888888881")
    }

    /// `parseCard(lines:)` extracts a 19-digit card number (maximum length).
    func test_parseCard_extractsCardNumber_maximumLength() {
        let result = subject.parseCard(lines: ["6011000990139424000"])
        XCTAssertEqual(result.cardNumber, "6011000990139424000")
    }

    /// `parseCard(lines:)` merges fragment lines when the card number is split across multiple lines.
    func test_parseCard_extractsCardNumber_fromFragments() {
        let result = subject.parseCard(lines: ["4111", "1111", "1111", "1111"])
        XCTAssertEqual(result.cardNumber, "4111111111111111")
    }

    /// `parseCard(lines:)` merges Amex-style fragments (4-6-5 grouping).
    func test_parseCard_extractsCardNumber_amexFragments() {
        let result = subject.parseCard(lines: ["3782", "822463", "10005"])
        XCTAssertEqual(result.cardNumber, "378282246310005")
    }

    /// `parseCard(lines:)` returns nil for the card number when given an 8-digit sequence
    /// (looks like a date — MMDDYYYY or YYYYMMDD).
    func test_parseCard_rejectsEightDigitSequence() {
        let result = subject.parseCard(lines: ["12282028"])
        XCTAssertNil(result.cardNumber)
    }

    /// `parseCard(lines:)` returns nil for the card number when no number is present.
    func test_parseCard_noCardNumber() {
        let result = subject.parseCard(lines: ["JANE DOE", "12/28"])
        XCTAssertNil(result.cardNumber)
    }

    /// `parseCard(lines:)` prefers a single-line match and does not merge fragments
    /// when a valid card number is already found.
    func test_parseCard_prefersSingleLineCardNumber() {
        let result = subject.parseCard(lines: ["4111111111111111", "1234"])
        XCTAssertEqual(result.cardNumber, "4111111111111111")
    }

    // MARK: Tests – Expiry

    /// `parseCard(lines:)` extracts an expiry date in MM/YY format and normalises the year to 4 digits.
    func test_parseCard_extractsExpiry_shortYear() {
        let result = subject.parseCard(lines: ["12/28"])
        XCTAssertEqual(result.expirationMonth, 12)
        XCTAssertEqual(result.expirationYear, "2028")
    }

    /// `parseCard(lines:)` extracts an expiry date already in MM/YYYY format.
    func test_parseCard_extractsExpiry_longYear() {
        let result = subject.parseCard(lines: ["03/2031"])
        XCTAssertEqual(result.expirationMonth, 3)
        XCTAssertEqual(result.expirationYear, "2031")
    }

    /// `parseCard(lines:)` extracts an expiry date with a single-digit month.
    func test_parseCard_extractsExpiry_singleDigitMonth() {
        let result = subject.parseCard(lines: ["1/29"])
        XCTAssertEqual(result.expirationMonth, 1)
        XCTAssertEqual(result.expirationYear, "2029")
    }

    /// `parseCard(lines:)` picks the last expiry match on a line, so a "VALID FROM" date
    /// followed by a "VALID THRU" date resolves to the expiry.
    func test_parseCard_extractsExpiry_picksLastMatch() {
        let result = subject.parseCard(lines: ["01/20  12/28"])
        XCTAssertEqual(result.expirationMonth, 12)
        XCTAssertEqual(result.expirationYear, "2028")
    }

    /// `parseCard(lines:)` returns nil expiry when no date is present.
    func test_parseCard_noExpiry() {
        let result = subject.parseCard(lines: ["4111111111111111"])
        XCTAssertNil(result.expirationMonth)
        XCTAssertNil(result.expirationYear)
    }

    /// `parseCard(lines:)` returns an empty result for empty input.
    func test_parseCard_emptyInput() {
        let result = subject.parseCard(lines: [])
        XCTAssertNil(result.cardNumber)
        XCTAssertNil(result.expirationMonth)
        XCTAssertNil(result.expirationYear)
    }

    /// `parseCard(lines:)` flattens embedded newlines within a single OCR transcript string.
    func test_parseCard_flattensEmbeddedNewlines() {
        let result = subject.parseCard(lines: ["4111111111111111\nJANE DOE\n12/28"])
        XCTAssertEqual(result.cardNumber, "4111111111111111")
        XCTAssertEqual(result.expirationMonth, 12)
    }

    /// `parseCard(lines:)` discards whitespace-only lines.
    func test_parseCard_discardsWhitespaceOnlyLines() {
        let result = subject.parseCard(lines: ["   ", "", "4111111111111111"])
        XCTAssertEqual(result.cardNumber, "4111111111111111")
    }

    /// `parseCard(lines:)` populates card number and expiry from a realistic card scan.
    func test_parseCard_realisticScan_cardNumberAndExpiry() {
        let lines = [
            "4111 1111 1111 1111",
            "JANE DOE",
            "12/28",
        ]
        let result = subject.parseCard(lines: lines)
        XCTAssertEqual(result.cardNumber, "4111111111111111")
        XCTAssertEqual(result.expirationMonth, 12)
        XCTAssertEqual(result.expirationYear, "2028")
    }
}
