import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - ItemListItemRowView

/// A view that displays information about an `ItemListItem` as a row in a list.
struct ItemListItemRowView: View {
    // MARK: Properties

    /// The `Store` for this view.
    var store: Store<
        ItemListItemRowState,
        ItemListItemRowAction,
        ItemListItemRowEffect,
    >

    /// The `TimeProvider` used to calculate TOTP expiration.
    var timeProvider: any TimeProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                decorativeImage(
                    store.state.item,
                    iconBaseURL: store.state.iconBaseURL,
                    showWebIcons: store.state.showWebIcons,
                )
                .frame(width: 22, height: 22)
                .foregroundColor(Asset.Colors.textSecondary.swiftUIColor)
                .padding(.vertical, 19)
                .accessibilityHidden(true)

                HStack {
                    if let totpCodeModel = store.state.item.totpCodeModel {
                        totpCodeRow(
                            name: store.state.item.name,
                            accountName: store.state.item.accountName,
                            model: totpCodeModel,
                            nextCode: store.state.item.nextTotpCodeModel,
                            showNextCode: store.state.showNextCode,
                        )
                    } else {
                        EmptyView()
                    }
                }
                .padding(.vertical, 9)
            }
            .padding(.horizontal, 16)

            if store.state.hasDivider {
                Divider()
                    .padding(.leading, 22 + 16 + 16)
            }
        }
    }

    // MARK: - Private Views

    /// The decorative image for the row.
    ///
    /// - Parameters:
    ///   - item: The item in the row.
    ///   - iconBaseURL: The base url used to download decorative images.
    ///   - showWebIcons: Whether to download the web icons.
    ///
    @ViewBuilder
    private func decorativeImage(_ item: ItemListItem, iconBaseURL: URL?, showWebIcons: Bool) -> some View {
        placeholderDecorativeImage(SharedAsset.Icons.globe24)
    }

    /// The placeholder image for the decorative image.
    private func placeholderDecorativeImage(_ icon: SharedImageAsset) -> some View {
        Image(decorative: icon)
            .resizable()
            .scaledToFit()
    }

    /// The row showing the totp code.
    @ViewBuilder
    private func totpCodeRow(
        name: String,
        accountName: String?,
        model: TOTPCodeModel,
        nextCode: TOTPCodeModel?,
        showNextCode: Bool,
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let name = name.nilIfEmpty {
                Text(name)
                    .styleGuide(.headline)
                    .lineLimit(1)
                    .foregroundColor(Asset.Colors.textPrimary.swiftUIColor)
                if let accountName = accountName?.nilIfEmpty {
                    Text(accountName)
                        .styleGuide(.subheadline)
                        .lineLimit(1)
                        .foregroundColor(Asset.Colors.textSecondary.swiftUIColor)
                }
            } else {
                if let accountName = accountName?.nilIfEmpty {
                    Text(accountName)
                        .styleGuide(.headline)
                        .lineLimit(1)
                        .foregroundColor(Asset.Colors.textPrimary.swiftUIColor)
                }
            }
        }
        Spacer()
        TotpCodeRowContent(
            model: model,
            nextCode: nextCode,
            showNextCode: showNextCode,
            timeProvider: timeProvider,
        )
    }
}

// MARK: - TotpCodeRowContent

/// A sub-view that owns the TOTP countdown timer and conditionally displays the next code.
private struct TotpCodeRowContent: View {
    // MARK: Static Properties

    /// The number of seconds remaining below which the next code is revealed.
    static let nextCodeVisibilityThreshold = 10

    // MARK: Properties

    /// The current TOTP code model.
    let model: TOTPCodeModel

    /// The next TOTP code model (one period ahead), or `nil` if unavailable.
    let nextCode: TOTPCodeModel?

    /// Whether the "show next code" feature is enabled in settings.
    let showNextCode: Bool

    /// The `TimeProvider` used to drive the countdown timer.
    let timeProvider: any TimeProvider

    /// The countdown timer that drives the circular progress indicator.
    @StateObject private var timer: TOTPCountdownTimer

    // MARK: View

    var body: some View {
        TOTPCountdownTimerView(totpCode: model, timer: timer)
        VStack(alignment: .trailing, spacing: 0) {
            Text(model.displayCode)
                .styleGuide(.bodyMonospaced, weight: .regular, monoSpacedDigit: true)
                .foregroundColor(Asset.Colors.textPrimary.swiftUIColor)
            if showNextCode,
               timer.secondsRemaining < Self.nextCodeVisibilityThreshold,
               let next = nextCode {
                Text(next.displayCode)
                    .styleGuide(.subheadline, monoSpacedDigit: true)
                    .foregroundColor(Asset.Colors.textSecondary.swiftUIColor)
                    .accessibilityLabel(Localizations.nextCode(next.displayCode))
            }
        }
    }

    // MARK: Initialization

    init(
        model: TOTPCodeModel,
        nextCode: TOTPCodeModel?,
        showNextCode: Bool,
        timeProvider: any TimeProvider,
    ) {
        self.model = model
        self.nextCode = nextCode
        self.showNextCode = showNextCode
        self.timeProvider = timeProvider
        _timer = StateObject(wrappedValue: TOTPCountdownTimer(
            timeProvider: timeProvider,
            timerInterval: TOTPCountdownTimerView.timerInterval,
            totpCode: model,
            onExpiration: nil,
        ))
    }
}

#if DEBUG
#Preview("With account name") {
    ItemListItemRowView(
        store: Store(
            processor: StateProcessor(
                state: ItemListItemRowState(
                    item: ItemListItem(
                        id: UUID().uuidString,
                        name: "Example",
                        accountName: "person@example.com",
                        itemType: .totp(
                            model: ItemListTotpItem(
                                itemView: AuthenticatorItemView.fixture(),
                                totpCode: TOTPCodeModel(
                                    code: "123456",
                                    codeGenerationDate: Date(),
                                    period: 30,
                                ),
                            ),
                        ),
                    ),
                    hasDivider: true,
                    showNextCode: false,
                    showWebIcons: true,
                ),
            ),
        ),
        timeProvider: PreviewTimeProvider(),
    )
}

#Preview("Without account name") {
    ItemListItemRowView(
        store: Store(
            processor: StateProcessor(
                state: ItemListItemRowState(
                    item: ItemListItem(
                        id: UUID().uuidString,
                        name: "Example",
                        accountName: nil,
                        itemType: .totp(
                            model: ItemListTotpItem(
                                itemView: AuthenticatorItemView.fixture(),
                                totpCode: TOTPCodeModel(
                                    code: "123456",
                                    codeGenerationDate: Date(),
                                    period: 30,
                                ),
                            ),
                        ),
                    ),
                    hasDivider: true,
                    showNextCode: false,
                    showWebIcons: true,
                ),
            ),
        ),
        timeProvider: PreviewTimeProvider(),
    )
}

#Preview("With just account name") {
    ItemListItemRowView(
        store: Store(
            processor: StateProcessor(
                state: ItemListItemRowState(
                    item: ItemListItem(
                        id: UUID().uuidString,
                        name: "",
                        accountName: "person@example.com",
                        itemType: .totp(
                            model: ItemListTotpItem(
                                itemView: AuthenticatorItemView.fixture(),
                                totpCode: TOTPCodeModel(
                                    code: "123456",
                                    codeGenerationDate: Date(),
                                    period: 30,
                                ),
                            ),
                        ),
                    ),
                    hasDivider: true,
                    showNextCode: false,
                    showWebIcons: true,
                ),
            ),
        ),
        timeProvider: PreviewTimeProvider(),
    )
}

struct ItemListItemRow_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VStack(spacing: 4) {
                ForEach(ItemListSection.digitsFixture(accountNames: false).items) { item in
                    ItemListItemRowView(
                        store: Store(
                            processor: StateProcessor(
                                state: ItemListItemRowState(
                                    item: item,
                                    hasDivider: true,
                                    showNextCode: false,
                                    showWebIcons: true,
                                ),
                            ),
                        ),
                        timeProvider: PreviewTimeProvider(),
                    )
                }
            }
        }.previewDisplayName(
            "Digits without account",
        )
        NavigationView {
            VStack(spacing: 4) {
                ForEach(ItemListSection.digitsFixture(accountNames: true).items) { item in
                    ItemListItemRowView(
                        store: Store(
                            processor: StateProcessor(
                                state: ItemListItemRowState(
                                    item: item,
                                    hasDivider: true,
                                    showNextCode: false,
                                    showWebIcons: true,
                                ),
                            ),
                        ),
                        timeProvider: PreviewTimeProvider(),
                    )
                }
            }
        }.previewDisplayName(
            "Digits with account",
        )
    }
}
#endif
