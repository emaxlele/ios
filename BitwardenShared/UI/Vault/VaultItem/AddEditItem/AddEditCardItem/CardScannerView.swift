import BitwardenResources
import SwiftUI
import VisionKit

// MARK: - CardScannerWrapperView

/// A SwiftUI view that hosts the card scanner with a navigation bar, instruction text,
/// and a Done button. This is the entry point for card scanning presented as a sheet.
///
@available(iOS 16.0, *)
struct CardScannerWrapperView: View {
    // MARK: Properties

    /// The pre-warmed scanner instance created before the sheet was presented.
    let scanner: DataScannerViewController

    /// Called with the parsed card data when the user confirms or sufficient data is detected.
    let onCompletion: (ScannedCardData) -> Void

    /// Drives `startScanning()`/`stopScanning()` via the SwiftUI view lifecycle.
    @SwiftUI.State private var isScanning = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text(Localizations.positionYourCardInTheFrameToScanIt)
                    .styleGuide(.body)
                    .multilineTextAlignment(.center)
                    .padding(12)

                CardScannerView(
                    scanner: scanner,
                    onCompletion: onCompletion,
                    isScanning: $isScanning,
                )
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 35)
                .onAppear { isScanning = true }
                .onDisappear { isScanning = false }
            }
            .navigationTitle(Localizations.scanCard)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(Localizations.cancel) {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - CardScannerView

/// A `UIViewControllerRepresentable` that presents a pre-warmed `DataScannerViewController`.
///
/// - `isScanning` drives `startScanning()`/`stopScanning()` via `updateUIViewController`,
///   toggled by the wrapper's `.onAppear`/`.onDisappear`.
/// - `isDone` triggers completion when the Done button is tapped.
///
@available(iOS 16.0, *)
struct CardScannerView: UIViewControllerRepresentable {
    // MARK: Properties

    /// The pre-warmed scanner, created before the sheet opened to reduce startup latency.
    let scanner: DataScannerViewController

    /// Called with the parsed card data when scanning completes.
    let onCompletion: (ScannedCardData) -> Void

    /// When `true`, scanning is active; when `false`, scanning is stopped.
    @Binding var isScanning: Bool

    // MARK: Factory

    /// Creates and configures a `DataScannerViewController` ready to scan card text.
    /// Call this before presenting the sheet so hardware initialization begins immediately.
    static func makeScanner() -> DataScannerViewController {
        DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: false,
        )
    }

    // MARK: UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        scanner.delegate = context.coordinator
        context.coordinator.scanner = scanner
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isScanning {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
}

// MARK: - Coordinator

@available(iOS 16.0, *)
extension CardScannerView {
    /// Coordinator acting as `DataScannerViewControllerDelegate`.
    /// Accumulates recognized text lines and calls `onCompletion` when ready.
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        // MARK: Properties

        /// Accumulated text lines recognized so far.
        private var recognizedLines: [String] = []

        /// Whether scanning has already finished (prevents double-completion).
        private var hasCompleted = false

        /// The scanner, set in `makeUIViewController`.
        weak var scanner: DataScannerViewController?

        let onCompletion: (ScannedCardData) -> Void

        // MARK: Initialization

        init(onCompletion: @escaping (ScannedCardData) -> Void) {
            self.onCompletion = onCompletion
        }

        // MARK: DataScannerViewControllerDelegate

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem],
        ) {
            updateLines(from: allItems)
            autoCompleteIfReady()
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem],
        ) {
            updateLines(from: allItems)
            autoCompleteIfReady()
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didRemove removedItems: [RecognizedItem],
            allItems: [RecognizedItem],
        ) {
            updateLines(from: allItems)
        }

        // MARK: Internal

        /// Parses the current lines, fires `onCompletion`, and stops scanning.
        /// Safe to call multiple times — only the first call has effect.
        func complete() {
            guard !hasCompleted else { return }
            hasCompleted = true
            let data = CardTextParser.parse(lines: recognizedLines)
            // Clear raw OCR strings immediately after parsing so they don't sit in memory
            // until this class is deallocated.
            recognizedLines = []
            scanner?.stopScanning()
            onCompletion(data)
        }

        // MARK: Private Helpers

        private func updateLines(from items: [RecognizedItem]) {
            recognizedLines = items.compactMap { item -> String? in
                if case let .text(textItem) = item {
                    return textItem.transcript
                }
                return nil
            }
        }

        private func autoCompleteIfReady() {
            guard !hasCompleted else { return }
            let data = CardTextParser.parse(lines: recognizedLines)
            if data.cardNumber != nil, data.expirationMonth != nil, !data.cardholderNameCandidates.isEmpty {
                complete()
            }
        }
    }
}
