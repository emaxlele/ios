import BitwardenKit
import SwiftUI

// MARK: - TOTPCountdownTimerView

/// A circular countdown timer view that marks the time remaining for a TOTPCodeState.
///
struct TOTPCountdownTimerView: View {
    // MARK: Static Properties

    /// The interval at which the view should check for expirations and update the time remaining.
    ///
    static let timerInterval: TimeInterval = 0.1

    // MARK: Properties

    /// The TOTPCode used to generate the countdown
    ///
    let totpCode: TOTPCodeModel

    /// A binding updated to reflect whether the countdown is in the final 10 seconds.
    ///
    var isNearExpiration: Binding<Bool>?

    /// The `TOTPCountdownTimer`responsible for updating the view state.
    ///
    @ObservedObject private(set) var timer: TOTPCountdownTimer

    var body: some View {
        ZStack {
            Text("  ")
                .styleGuide(.caption2Monospaced)
                .accessibilityHidden(true)
            Text(timer.displayTime ?? "")
                .styleGuide(.caption2Monospaced, monoSpacedDigit: true)
                .foregroundColor(Asset.Colors.textPrimary.swiftUIColor)
        }
        .padding(6)
        .background {
            CircularProgressShape(progress: timer.remainingFraction, clockwise: true)
                .stroke(lineWidth: 3)
                .foregroundColor(timer.timerColor())
                .animation(
                    .smooth(
                        duration: TOTPCountdownTimerView.timerInterval,
                    ),
                    value: timer.remainingFraction,
                )
        }
        .onAppear {
            isNearExpiration?.wrappedValue = timer.secondsRemaining < 10
        }
        .onChange(of: timer.secondsRemaining) { newValue in
            isNearExpiration?.wrappedValue = newValue < 10
        }
    }

    /// Initializes the view for a TOTPCodeModel and a timer expiration handler.
    ///
    /// - Parameters:
    ///   - timeProvider: A protocol providing the present time as a `Date`.
    ///         Used to calculate time remaining for a present TOTP code.
    ///   - totpCode: The code that the timer represents.
    ///   - isNearExpiration: An optional binding updated when the countdown enters or exits
    ///     the final 10 seconds.
    ///   - onExpiration: A closure called when the code expires.
    ///
    init(
        timeProvider: any TimeProvider,
        totpCode: TOTPCodeModel,
        isNearExpiration: Binding<Bool>? = nil,
        onExpiration: (() -> Void)?,
    ) {
        self.totpCode = totpCode
        self.isNearExpiration = isNearExpiration
        timer = .init(
            timeProvider: timeProvider,
            timerInterval: TOTPCountdownTimerView.timerInterval,
            totpCode: totpCode,
            onExpiration: onExpiration,
        )
    }
}
