import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - ItemListItemRowView

/// A view that displays information about an `ItemListItem` as a row in a list.
struct ItemListItemRowView: View {
    // MARK: Properties

    /// Whether the next code preview should currently be visible based on the countdown timer.
    @State private var shouldShowNextCode = false

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
    private func totpCodeRow(name: String, accountName: String?, model: TOTPCodeModel) -> some View {
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
        TOTPCountdownTimerView(
            timeProvider: timeProvider,
            totpCode: model,
            onExpiration: nil,
        )
        codeColumn(model: model)
    }

    /// A vertical stack showing the current code and, when conditions are met, the next code preview.
    @ViewBuilder
    private func codeColumn(model: TOTPCodeModel) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(model.displayCode)
                .styleGuide(.bodyMonospaced, weight: .regular, monoSpacedDigit: true)
                .foregroundColor(Asset.Colors.textPrimary.swiftUIColor)
            if store.state.showNextCode,
               shouldShowNextCode,
               let nextCode = store.state.item.nextTotpCodeModel {
                Text(nextCode.displayCode)
                    .styleGuide(.subheadline, monoSpacedDigit: true)
                    .foregroundColor(Asset.Colors.textSecondary.swiftUIColor)
                    .accessibilityLabel(
                        Localizations.showNextCode + ": "
                            + nextCode.code.map(String.init).joined(separator: " "),
                    )
            }
        }
        .task(id: model.codeGenerationDate) {
            while !Task.isCancelled {
                let seconds = TOTPExpirationCalculator.remainingSeconds(
                    for: timeProvider.presentTime,
                    using: Int(model.period),
                )
                shouldShowNextCode = seconds <= TOTPCountdownTimer.nextCodeRevealThreshold
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
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
