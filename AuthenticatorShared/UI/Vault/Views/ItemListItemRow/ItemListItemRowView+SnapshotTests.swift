// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import SnapshotTesting
import SwiftUI
import XCTest

@testable import AuthenticatorShared

// MARK: - ItemListItemRowViewTests

class ItemListItemRowViewTests: BitwardenTestCase {
    // MARK: Properties

    var processor: MockProcessor<ItemListItemRowState, ItemListItemRowAction, ItemListItemRowEffect>!
    var subject: ItemListItemRowView!
    var timeProvider: MockTimeProvider!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        timeProvider = MockTimeProvider(.mockTime(Date(year: 2023, month: 12, day: 31, hour: 0, minute: 0, second: 25)))
    }

    override func tearDown() {
        super.tearDown()

        processor = nil
        subject = nil
        timeProvider = nil
    }

    // MARK: Tests

    /// Snapshot: next code hidden when `showNextTOTPCode` is `false`, even with a next code available
    /// and time remaining below the preview threshold.
    @MainActor
    func disabletest_snapshot_showNextTOTPCode_hidden() {
        let state = ItemListItemRowState(
            item: ItemListItem(
                id: "1",
                name: "Example",
                accountName: "person@example.com",
                itemType: .totp(
                    model: ItemListTotpItem(
                        itemView: AuthenticatorItemView.fixture(),
                        nextTotpCode: TOTPCodeModel(
                            code: "654321",
                            codeGenerationDate: Date(year: 2023, month: 12, day: 31),
                            period: 30,
                        ),
                        totpCode: TOTPCodeModel(
                            code: "123456",
                            codeGenerationDate: Date(year: 2023, month: 12, day: 31),
                            period: 30,
                        ),
                    ),
                ),
            ),
            hasDivider: false,
            showNextTOTPCode: false,
            showWebIcons: false,
        )
        processor = MockProcessor(state: state)
        subject = ItemListItemRowView(
            store: Store(processor: processor),
            timeProvider: timeProvider,
        )
        assertSnapshot(of: subject, as: .defaultPortrait)
    }

    /// Snapshot: next code visible when `showNextTOTPCode` is `true` and time remaining is below the preview threshold.
    @MainActor
    func disabletest_snapshot_showNextTOTPCode_visible() {
        let state = ItemListItemRowState(
            item: ItemListItem(
                id: "1",
                name: "Example",
                accountName: "person@example.com",
                itemType: .totp(
                    model: ItemListTotpItem(
                        itemView: AuthenticatorItemView.fixture(),
                        nextTotpCode: TOTPCodeModel(
                            code: "654321",
                            codeGenerationDate: Date(year: 2023, month: 12, day: 31),
                            period: 30,
                        ),
                        totpCode: TOTPCodeModel(
                            code: "123456",
                            codeGenerationDate: Date(year: 2023, month: 12, day: 31),
                            period: 30,
                        ),
                    ),
                ),
            ),
            hasDivider: false,
            showNextTOTPCode: true,
            showWebIcons: false,
        )
        processor = MockProcessor(state: state)
        subject = ItemListItemRowView(
            store: Store(processor: processor),
            timeProvider: timeProvider,
        )
        assertSnapshot(of: subject, as: .defaultPortrait)
    }
}
