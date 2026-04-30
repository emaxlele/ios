import AuthenticationServices
import BitwardenKit
import BitwardenSdk
import BitwardenShared
import Combine
import OSLog

/// An `ASCredentialProviderViewController` that implements credential autofill.
///
class CredentialProviderViewController: ASCredentialProviderViewController {
    // MARK: Properties

    /// The app's theme.
    var appTheme: AppTheme = .default

    /// A subject containing whether the controller did appear.
    private var didAppearSubject = CurrentValueSubject<Bool, Never>(false)

    /// The processor that manages application level logic.
    private var appProcessor: AppProcessor?

    /// The context of the credential provider to see how the extension is being used.
    private var context: CredentialProviderContext?

    /// Zero-frame text field that holds first responder in `autofillText` mode to keep
    /// InputUI's keyboard session alive across view-controller transitions and search dismissals.
    private var keyboardAnchor: KeyboardAnchorTextField?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        didAppearSubject.send(true)
    }

    // MARK: ASCredentialProviderViewController

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        initializeApp(with: DefaultCredentialProviderContext(.autofillVaultList(serviceIdentifiers)))
    }

    @available(iOSApplicationExtension 17.0, *)
    override func prepareCredentialList(
        for serviceIdentifiers: [ASCredentialServiceIdentifier],
        requestParameters: ASPasskeyCredentialRequestParameters,
    ) {
        initializeApp(with: DefaultCredentialProviderContext(
            .autofillFido2VaultList(serviceIdentifiers, requestParameters),
        ))
    }

    override func prepareInterfaceForExtensionConfiguration() {
        initializeApp(with: DefaultCredentialProviderContext(.configureAutofill))
    }

    @available(iOSApplicationExtension 17.0, *)
    override func prepareInterface(forPasskeyRegistration registrationRequest: any ASCredentialRequest) {
        guard let fido2RegistrationRequest = registrationRequest as? ASPasskeyCredentialRequest else {
            return
        }
        initializeApp(with: DefaultCredentialProviderContext(.registerFido2Credential(fido2RegistrationRequest)))
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        initializeApp(with: DefaultCredentialProviderContext(
            .autofillCredential(credentialIdentity, userInteraction: true),
        ))
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        guard let recordIdentifier = credentialIdentity.recordIdentifier else {
            cancel(error: ASExtensionError(.credentialIdentityNotFound))
            return
        }

        Task {
            await initializeAppWithoutUserInteraction(
                with: DefaultCredentialProviderContext(.autofillCredential(credentialIdentity, userInteraction: false)),
            )
            provideCredential(for: recordIdentifier)
        }
    }

    @available(iOSApplicationExtension 17.0, *)
    override func provideCredentialWithoutUserInteraction(for credentialRequest: any ASCredentialRequest) {
        switch credentialRequest {
        case let passwordRequest as ASPasswordCredentialRequest:
            if let passwordIdentity = passwordRequest.credentialIdentity as? ASPasswordCredentialIdentity {
                provideCredentialWithoutUserInteraction(for: passwordIdentity)
            }
        case let passkeyRequest as ASPasskeyCredentialRequest:
            Task {
                await initializeAppWithoutUserInteraction(
                    with: DefaultCredentialProviderContext(
                        .autofillFido2Credential(passkeyRequest, userInteraction: false),
                    ),
                )
                provideFido2Credential(for: passkeyRequest)
            }
        default:
            if #available(iOSApplicationExtension 18.0, *),
               let otpRequest = credentialRequest as? ASOneTimeCodeCredentialRequest,
               let otpIdentity = otpRequest.credentialIdentity as? ASOneTimeCodeCredentialIdentity {
                provideOTPCredentialWithoutUserInteraction(for: otpIdentity)
            }
        }
    }

    @available(iOSApplicationExtension 17.0, *)
    override func prepareInterfaceToProvideCredential(for credentialRequest: any ASCredentialRequest) {
        switch credentialRequest {
        case let passwordRequest as ASPasswordCredentialRequest:
            if let passwordIdentity = passwordRequest.credentialIdentity as? ASPasswordCredentialIdentity {
                prepareInterfaceToProvideCredential(for: passwordIdentity)
            }
        case let passkeyRequest as ASPasskeyCredentialRequest:
            initializeApp(
                with: DefaultCredentialProviderContext(
                    .autofillFido2Credential(passkeyRequest, userInteraction: true),
                ),
            )
        default:
            if #available(iOSApplicationExtension 18.0, *),
               let otpRequest = credentialRequest as? ASOneTimeCodeCredentialRequest,
               let otpIdentity = otpRequest.credentialIdentity as? ASOneTimeCodeCredentialIdentity {
                initializeApp(with: DefaultCredentialProviderContext(
                    .autofillOTPCredential(otpIdentity, userInteraction: true),
                ))
            }
        }
    }

    // MARK: Private

    /// Cancels the extension request and dismisses the extension's view controller.
    ///
    /// - Parameter error: An optional error describing why the request failed.
    ///
    private func cancel(error: Error? = nil) {
        if let context, context.configuring {
            extensionContext.completeExtensionConfigurationRequest()
        } else if let error {
            extensionContext.cancelRequest(withError: error)
        } else {
            extensionContext.cancelRequest(
                withError: NSError(
                    domain: ASExtensionErrorDomain,
                    code: ASExtensionError.userCanceled.rawValue,
                ),
            )
        }
    }

    /// Installs `keyboardAnchor` as first responder to keep InputUI's keyboard session alive.
    ///
    /// Call before any VC transition in `autofillText` mode. No retries are scheduled:
    /// retries disrupt SwiftUI `@FocusState` sessions (`fromBecomeFirstResponder:0`, no timer),
    /// turning them into explicit sessions (`fromBecomeFirstResponder:1`, 5-second timer) and
    /// causing a visible keyboard flicker. `keyboardWillHide` handles true keyboard dismissals.
    ///
    /// SwiftUI must reclaim focus via `@FocusState` before the RTI 5-second timer fires;
    /// screens without a focusable element remain on the `becomeFirstResponder:1` path.
    private func installKeyboardAnchor() {
        guard let context, case .autofillText = context.extensionMode else { return }

        if keyboardAnchor == nil {
            let anchor = KeyboardAnchorTextField(frame: .zero)
            view.addSubview(anchor)
            keyboardAnchor = anchor
        }

        keyboardAnchor?.becomeFirstResponder()
    }

    /// Sets up and initializes the app and UI.
    ///
    /// - Parameters:
    ///   - with: The context that describes how the extension is being used.
    ///
    private func initializeApp(with context: CredentialProviderContext) {
        self.context = context

        let errorReporter = OSLogErrorReporter()
        let services = ServiceContainer(appContext: .appExtension, errorReporter: errorReporter)
        let appModule = DefaultAppModule(appExtensionDelegate: self, services: services)
        let appProcessor = AppProcessor(appExtensionDelegate: self, appModule: appModule, services: services)
        self.appProcessor = appProcessor

        if context.flowWithUserInteraction {
            Task {
                await appProcessor.start(appContext: .appExtension, navigator: self, window: nil)
            }
        }
    }

    /// Sets up and initializes the app without user interaction.
    /// - Parameter context: The context that describes how the extension is being used.
    private func initializeAppWithoutUserInteraction(
        with context: CredentialProviderContext,
    ) async {
        initializeApp(with: context)
        await appProcessor?.prepareEnvironmentConfig()
    }

    /// Attempts to provide the credential with the specified ID to the extension context to handle
    /// autofill.
    ///
    /// - Parameters:
    ///   - id: The identifier of the user-requested credential to return.
    ///   - repromptPasswordValidated: `true` if master password reprompt was required for the
    ///     cipher and the user's master password was validated.
    ///
    private func provideCredential(
        for id: String,
        repromptPasswordValidated: Bool = false,
    ) {
        guard let appProcessor else {
            cancel(error: ASExtensionError(.failed))
            return
        }

        Task {
            do {
                let credential = try await appProcessor.provideCredential(
                    for: id,
                    repromptPasswordValidated: repromptPasswordValidated,
                )
                extensionContext.completeRequest(withSelectedCredential: credential)
            } catch {
                Logger.appExtension.error("Error providing credential without user interaction: \(error)")
                cancel(error: error)
            }
        }
    }

    /// Provides a Fido2 credential for a passkey request
    /// - Parameters:
    ///   - passkeyRequest: Request to get the credential
    ///   - withUserInteraction: Whether this is called in a flow with user interaction.
    @available(iOSApplicationExtension 17.0, *)
    private func provideFido2Credential(
        for passkeyRequest: ASPasskeyCredentialRequest,
    ) {
        guard let appProcessor else {
            cancel(error: ASExtensionError(.failed))
            return
        }

        Task {
            do {
                let credential = try await appProcessor.provideFido2Credential(
                    for: passkeyRequest,
                )
                await extensionContext.completeAssertionRequest(using: credential)
            } catch Fido2Error.userInteractionRequired {
                cancel(error: ASExtensionError(.userInteractionRequired))
            } catch {
                if let context, context.flowFailedBecauseUserInteractionRequired {
                    return
                }
                Logger.appExtension.error("Error providing credential without user interaction: \(error)")
                cancel(error: error)
            }
        }
    }

    /// Attempts to provide the OTP credential with the specified ID to the extension context to handle
    /// autofill.
    ///
    /// - Parameters:
    ///   - id: The identifier of the user-requested credential to return.
    ///   - repromptPasswordValidated: `true` if master password reprompt was required for the
    ///     cipher and the user's master password was validated.
    ///
    @available(iOSApplicationExtension 18.0, *)
    private func provideOTPCredential(
        for id: String,
        repromptPasswordValidated: Bool = false,
    ) {
        guard let appProcessor else {
            cancel(error: ASExtensionError(.failed))
            return
        }

        Task {
            do {
                let credential = try await appProcessor.provideOTPCredential(
                    for: id,
                    repromptPasswordValidated: repromptPasswordValidated,
                )
                await extensionContext.completeOneTimeCodeRequest(using: credential)
            } catch {
                Logger.appExtension.error("Error providing OTP credential without user interaction: \(error)")
                cancel(error: error)
            }
        }
    }

    @available(iOSApplicationExtension 18.0, *)
    private func provideOTPCredentialWithoutUserInteraction(for otpIdentity: ASOneTimeCodeCredentialIdentity) {
        guard let recordIdentifier = otpIdentity.recordIdentifier else {
            cancel(error: ASExtensionError(.credentialIdentityNotFound))
            return
        }

        Task {
            await initializeAppWithoutUserInteraction(
                with: DefaultCredentialProviderContext(.autofillOTPCredential(otpIdentity, userInteraction: false)),
            )
            provideOTPCredential(for: recordIdentifier)
        }
    }
}

// MARK: - iOS 18

extension CredentialProviderViewController {
    @available(iOSApplicationExtension 18.0, *)
    override func prepareInterfaceForUserChoosingTextToInsert() {
        // Create the anchor directly here — `self.context` is nil at this point so
        // `installKeyboardAnchor`'s context guard would return early. This is the only
        // synchronous call site where the view is in the window, no children exist, and
        // nothing else can steal focus. `initializeApp` launches an async Task, so anchoring
        // inside it would be too late.
        let anchor = KeyboardAnchorTextField(frame: .zero)
        view.addSubview(anchor)
        keyboardAnchor = anchor
        anchor.becomeFirstResponder()

        // Safety net: reclaim anchor when keyboard starts hiding and anchor isn't FR.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil,
        )

        initializeApp(with: DefaultCredentialProviderContext(.autofillText))
    }

    @objc private func keyboardWillHide() {
        guard let context, case .autofillText = context.extensionMode,
              let anchor = keyboardAnchor, !anchor.isFirstResponder else { return }
        Logger.appExtension.debug("KeyboardAnchorTextField: keyboard will hide without anchor as FR — reclaiming")
        anchor.becomeFirstResponder()
    }

    @available(iOSApplicationExtension 18.0, *)
    override func prepareOneTimeCodeCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        initializeApp(with: DefaultCredentialProviderContext(.autofillOTP(serviceIdentifiers)))
    }
}

// MARK: - AppExtensionDelegate

extension CredentialProviderViewController: AppExtensionDelegate {
    var authCompletionRoute: AppRoute? {
        context?.authCompletionRoute
    }

    var canAutofill: Bool { true }

    var isAutofillingOTP: Bool {
        guard case .autofillOTP = context?.extensionMode else {
            return false
        }
        return true
    }

    var isInAppExtension: Bool { true }

    var uri: String? {
        context?.uri
    }

    func completeAutofillRequest(username: String, password: String, fields: [(String, String)]?) {
        let passwordCredential = ASPasswordCredential(user: username, password: password)
        extensionContext.completeRequest(withSelectedCredential: passwordCredential)
    }

    func didCancel() {
        cancel()
    }

    func didCompleteAuth() {
        guard let context else { return }

        switch context.extensionMode {
        case .autofillCredential:
            provideCredentialWithUserInteraction()
        case let .autofillFido2Credential(passkeyRequest, _):
            guard #available(iOSApplicationExtension 17.0, *),
                  let asPasskeyRequest = passkeyRequest as? ASPasskeyCredentialRequest else {
                cancel(error: ASExtensionError(.failed))
                return
            }

            provideFido2Credential(for: asPasskeyRequest)
        case let .autofillOTPCredential(otpIdentity, _):
            guard #available(iOSApplicationExtension 18.0, *),
                  let asOneTimeCodeIdentity = otpIdentity as? ASOneTimeCodeCredentialIdentity else {
                cancel(error: ASExtensionError(.failed))
                return
            }
            provideOTPCredentialWithUserInteraction(for: asOneTimeCodeIdentity)
        default:
            return
        }
    }

    func provideCredentialWithUserInteraction() {
        guard let credential = context?.passwordCredentialIdentity else { return }

        guard let appProcessor, let recordIdentifier = credential.recordIdentifier else {
            cancel(error: ASExtensionError(.failed))
            return
        }

        Task {
            do {
                try await appProcessor.repromptForCredentialIfNecessary(
                    for: recordIdentifier,
                ) { repromptPasswordValidated in
                    self.provideCredential(
                        for: recordIdentifier,
                        repromptPasswordValidated: repromptPasswordValidated,
                    )
                }
            } catch {
                Logger.appExtension.error("Error providing credential: \(error)")
                cancel(error: error)
            }
        }
    }

    /// Provides an OTP credential with user interaction given an `ASOneTimeCodeCredentialIdentity`.
    /// - Parameter otpIdentity: `ASOneTimeCodeCredentialIdentity` to provide the credential for.
    @available(iOSApplicationExtension 18.0, *)
    func provideOTPCredentialWithUserInteraction(for otpIdentity: ASOneTimeCodeCredentialIdentity) {
        guard let appProcessor, let recordIdentifier = otpIdentity.recordIdentifier else {
            cancel(error: ASExtensionError(.failed))
            return
        }

        Task {
            do {
                try await appProcessor.repromptForCredentialIfNecessary(
                    for: recordIdentifier,
                ) { repromptPasswordValidated in
                    self.provideOTPCredential(
                        for: recordIdentifier,
                        repromptPasswordValidated: repromptPasswordValidated,
                    )
                }
            } catch {
                Logger.appExtension.error("Error providing OTP credential: \(error)")
                cancel(error: error)
            }
        }
    }
}

// MARK: - AutofillAppExtensionDelegate

extension CredentialProviderViewController: AutofillAppExtensionDelegate {
    /// The mode in which the autofill extension is running.
    var extensionMode: AutofillExtensionMode {
        context?.extensionMode ?? .configureAutofill
    }

    var flowWithUserInteraction: Bool {
        context?.flowWithUserInteraction ?? false
    }

    @available(iOSApplicationExtension 17.0, *)
    func completeAssertionRequest(assertionCredential: ASPasskeyAssertionCredential) {
        extensionContext.completeAssertionRequest(using: assertionCredential)
    }

    @available(iOSApplicationExtension 18.0, *)
    func completeOTPRequest(code: String) {
        extensionContext.completeOneTimeCodeRequest(using: ASOneTimeCodeCredential(code: code))
    }

    @available(iOSApplicationExtension 17.0, *)
    func completeRegistrationRequest(asPasskeyRegistrationCredential: ASPasskeyRegistrationCredential) {
        extensionContext.completeRegistrationRequest(using: asPasskeyRegistrationCredential)
    }

    @available(iOSApplicationExtension 18.0, *)
    func completeTextRequest(text: String) {
        extensionContext.completeRequest(withTextToInsert: text)
    }

    func getDidAppearPublisher() -> AsyncPublisher<AnyPublisher<Bool, Never>> {
        didAppearSubject
            .eraseToAnyPublisher()
            .values
    }

    func setUserInteractionRequired() {
        context?.flowFailedBecauseUserInteractionRequired = true
        cancel(error: ASExtensionError(.userInteractionRequired))
    }
}

// MARK: - RootNavigator

extension CredentialProviderViewController: RootNavigator {
    var rootViewController: UIViewController? { self }

    func show(child: Navigator) {
        // In autofillText mode, seize the anchor BEFORE the transition so there is no gap
        // where no text-input holds first responder (which would signal useKeyboard=0 to InputUI).
        installKeyboardAnchor()

        removeChildViewController()

        if let toViewController = child.rootViewController {
            addChild(toViewController)
            view.addConstrained(subview: toViewController.view)
            toViewController.didMove(toParent: self)
        }
    }

    // MARK: Private methods

    /// Removes the first child view controller.
    func removeChildViewController() {
        guard let fromViewController = children.first else { return }
        fromViewController.willMove(toParent: nil)
        fromViewController.view.removeFromSuperview()
        fromViewController.removeFromParent()
    }
}

// MARK: - KeyboardAnchorTextField

/// A zero-frame text field used in `autofillText` mode to seed the initial RTI session before the
/// SwiftUI view hierarchy is ready.
///
/// `useKeyboard` is computed as `allowsSystemInputView && !hasCustomInputView && responderRequiresKeyboard`.
/// Any non-nil `inputView` makes `!hasCustomInputView = 0` → `useKeyboard = 0` → `delayEndInputSession:YES`
/// on every delegate transition, firing `endRemoteTextInputSessionWithID` after ~5 seconds.
///
/// With `inputView = nil` (the default), every transition produces `useKeyboard = 1`. Once the
/// SwiftUI view appears it takes over via `@FocusState` (`fromBecomeFirstResponder:0`,
/// `delayEndInputSession:NO`), clearing this anchor's initial timer.
private final class KeyboardAnchorTextField: UITextField {
    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        Logger.appExtension.debug("KeyboardAnchorTextField: becomeFirstResponder → \(result)")
        return result
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        Logger.appExtension.debug("KeyboardAnchorTextField: resignFirstResponder → \(result)")
        return result
    }
} // swiftlint:disable:this file_length
