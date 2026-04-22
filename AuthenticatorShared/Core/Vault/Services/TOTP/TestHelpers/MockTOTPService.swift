import BitwardenKit
import Foundation

@testable import AuthenticatorShared

class MockTOTPService: TOTPService {
    var getTotpCodeResult: Result<TOTPCodeModel, Error> = .success(
        TOTPCodeModel(code: "123456", codeGenerationDate: .now, period: 30),
    )
    var getTotpCodeConfig: TOTPKeyModel?

    var getTotpCodeAtDateResult: Result<TOTPCodeModel, Error> = .success(
        TOTPCodeModel(code: "654321", codeGenerationDate: .now, period: 30),
    )
    var getTotpCodeAtDateConfig: TOTPKeyModel?
    var capturedDate: Date?

    var capturedKey: String?
    var getTOTPConfigResult: Result<TOTPKeyModel, Error> = .failure(TOTPKeyError.invalidKeyFormat)

    func getTotpCode(for key: TOTPKeyModel) async throws -> TOTPCodeModel {
        getTotpCodeConfig = key
        return try getTotpCodeResult.get()
    }

    func getTotpCode(for key: TOTPKeyModel, date: Date) async throws -> TOTPCodeModel {
        getTotpCodeAtDateConfig = key
        capturedDate = date
        return try getTotpCodeAtDateResult.get()
    }

    func getTOTPConfiguration(key: String?) throws -> TOTPKeyModel {
        capturedKey = key
        return try getTOTPConfigResult.get()
    }
}
