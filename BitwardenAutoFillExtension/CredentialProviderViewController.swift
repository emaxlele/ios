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

    /// The deadline before which UISearchController activation is suppressed.
    ///
    /// After each vault-list transition the search bar is blocked from becoming first responder
    /// until this date passes. This prevents the search bar from sending `stealKB:Y` while vault
    /// data is loading asynchronously, which would compete with the host app for keyboard focus
    /// and cause SafariViewService to invalidate the extension's process assertions.
    private var searchActivationSuppressedUntil: Date?

    /// A zero-size, hidden UITextField used in autofillText mode to maintain first-responder
    /// status so that InputUI does not start its ~5-second session-end timer when no text
    /// field is actively focused (e.g. after transitioning from unlock → vault list,
    /// or after the user cancels a vault-list search).
    ///
    /// Must be a UITextField (not UIView) so that `responderRequiresKeyboard = 1`, which
    /// makes UIKit evaluate `useKeyboard = 1`. Combined with `inputView = UIView()` this
    /// keeps the keyboard session alive without showing any visible keyboard UI.
    private var keyboardAnchorView: KeyboardAnchorTextField?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        didAppearSubject.send(true)
    }

    // MARK: ASCredentialProviderViewController

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        Logger.appExtension.debug("prepareCredentialList: \(serviceIdentifiers.count) service identifiers")
        initializeApp(with: DefaultCredentialProviderContext(.autofillVaultList(serviceIdentifiers)))
    }

    @available(iOSApplicationExtension 17.0, *)
    override func prepareCredentialList(
        for serviceIdentifiers: [ASCredentialServiceIdentifier],
        requestParameters: ASPasskeyCredentialRequestParameters,
    ) {
        Logger.appExtension.debug("prepareCredentialList(fido2): \(serviceIdentifiers.count) service identifiers")
        initializeApp(with: DefaultCredentialProviderContext(
            .autofillFido2VaultList(serviceIdentifiers, requestParameters),
        ))
    }

    override func prepareInterfaceForExtensionConfiguration() {
        Logger.appExtension.debug("prepareInterfaceForExtensionConfiguration")
        initializeApp(with: DefaultCredentialProviderContext(.configureAutofill))
    }

    @available(iOSApplicationExtension 17.0, *)
    override func prepareInterface(forPasskeyRegistration registrationRequest: any ASCredentialRequest) {
        Logger.appExtension.debug("prepareInterface(forPasskeyRegistration): type=\(type(of: registrationRequest))")
        guard let fido2RegistrationRequest = registrationRequest as? ASPasskeyCredentialRequest else {
            return
        }
        initializeApp(with: DefaultCredentialProviderContext(.registerFido2Credential(fido2RegistrationRequest)))
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        Logger.appExtension.debug("prepareInterfaceToProvideCredential(password): \(credentialIdentity.serviceIdentifier.identifier)")
        initializeApp(with: DefaultCredentialProviderContext(
            .autofillCredential(credentialIdentity, userInteraction: true),
        ))
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        Logger.appExtension.debug("provideCredentialWithoutUserInteraction(password): \(credentialIdentity.serviceIdentifier.identifier)")
        guard let recordIdentifier = credentialIdentity.recordIdentifier else {
            Logger.appExtension.debug("provideCredentialWithoutUserInteraction: no recordIdentifier — cancelling")
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
        Logger.appExtension.debug("provideCredentialWithoutUserInteraction: type=\(type(of: credentialRequest))")
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
            Logger.appExtension.debug("provideCredentialWithoutUserInteraction: unhandled type=\(type(of: credentialRequest))")
            if #available(iOSApplicationExtension 18.0, *),
               let otpRequest = credentialRequest as? ASOneTimeCodeCredentialRequest,
               let otpIdentity = otpRequest.credentialIdentity as? ASOneTimeCodeCredentialIdentity {
                provideOTPCredentialWithoutUserInteraction(for: otpIdentity)
            }
        }
    }

    @available(iOSApplicationExtension 17.0, *)
    override func prepareInterfaceToProvideCredential(for credentialRequest: any ASCredentialRequest) {
        Logger.appExtension.debug("prepareInterfaceToProvideCredential: type=\(type(of: credentialRequest))")
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
            Logger.appExtension.debug("prepareInterfaceToProvideCredential: unhandled type=\(type(of: credentialRequest))")
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
            Logger.appExtension.debug("cancel: completeExtensionConfigurationRequest")
            extensionContext.completeExtensionConfigurationRequest()
        } else if let error {
            Logger.appExtension.debug("cancel: cancelRequest(withError:) error=\(error)")
            extensionContext.cancelRequest(withError: error)
        } else {
            Logger.appExtension.debug("cancel: cancelRequest userCanceled")
            extensionContext.cancelRequest(
                withError: NSError(
                    domain: ASExtensionErrorDomain,
                    code: ASExtensionError.userCanceled.rawValue,
                ),
            )
        }
    }

    /// Sets up and initializes the app and UI.
    ///
    /// - Parameters:
    ///   - with: The context that describes how the extension is being used.
    ///
    private func initializeApp(with context: CredentialProviderContext) {
        Logger.appExtension.debug(
            "initializeApp: mode=\(String(describing: context.extensionMode)) flowWithUserInteraction=\(context.flowWithUserInteraction)",
        )
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
        Logger.appExtension.debug("prepareInterfaceForUserChoosingTextToInsert")
        // Install the anchor immediately — the view IS in the window at this call site
        // and nothing else is first responder yet. This is the only guaranteed-safe
        // moment to call becomeFirstResponder() before any child VC is added.
        installKeyboardAnchor(scheduleRetries: false)
        initializeApp(with: DefaultCredentialProviderContext(.autofillText))
    }

    @available(iOSApplicationExtension 18.0, *)
    override func prepareOneTimeCodeCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        Logger.appExtension.debug("prepareOneTimeCodeCredentialList: \(serviceIdentifiers.count) service identifiers")
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
        Logger.appExtension.debug("completeAutofillRequest: completing request")
        let passwordCredential = ASPasswordCredential(user: username, password: password)
        extensionContext.completeRequest(withSelectedCredential: passwordCredential)
    }

    func didCancel() {
        Logger.appExtension.debug("didCancel called")
        cancel()
    }

    func didCompleteAuth() {
        Logger.appExtension.debug("didCompleteAuth: extensionMode=\(String(describing: self.context?.extensionMode))")
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
        Logger.appExtension.debug("provideCredentialWithUserInteraction: starting")
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
        Logger.appExtension.debug("completeAssertionRequest: completing fido2 assertion request")
        extensionContext.completeAssertionRequest(using: assertionCredential)
    }

    @available(iOSApplicationExtension 18.0, *)
    func completeOTPRequest(code: String) {
        Logger.appExtension.debug("completeOTPRequest: completing OTP request")
        extensionContext.completeOneTimeCodeRequest(using: ASOneTimeCodeCredential(code: code))
    }

    @available(iOSApplicationExtension 17.0, *)
    func completeRegistrationRequest(asPasskeyRegistrationCredential: ASPasskeyRegistrationCredential) {
        Logger.appExtension.debug("completeRegistrationRequest: completing passkey registration")
        extensionContext.completeRegistrationRequest(using: asPasskeyRegistrationCredential)
    }

    @available(iOSApplicationExtension 18.0, *)
    func completeTextRequest(text: String) {
        Logger.appExtension.debug("completeTextRequest: completing text insertion request")
        extensionContext.completeRequest(withTextToInsert: text)
    }

    func getDidAppearPublisher() -> AsyncPublisher<AnyPublisher<Bool, Never>> {
        didAppearSubject
            .eraseToAnyPublisher()
            .values
    }

    func setUserInteractionRequired() {
        Logger.appExtension.debug("setUserInteractionRequired called")
        context?.flowFailedBecauseUserInteractionRequired = true
        cancel(error: ASExtensionError(.userInteractionRequired))
    }
}

// MARK: - RootNavigator

extension CredentialProviderViewController: RootNavigator {
    var rootViewController: UIViewController? { self }

    func show(child: Navigator) {
        // In autofillText mode the extension IS the keyboard panel. Calling endEditing(true) here
        // signals to InputUI that keyboard input is no longer needed, causing it to dismiss the
        // panel ~5 seconds later. Search-bar suppression is also irrelevant in this mode.
        let isAutofillText = if case .autofillText = context?.extensionMode { true } else { false }
        Logger.appExtension.debug("show(child:): isAutofillText=\(isAutofillText)")

        if isAutofillText {
            // Seize first responder BEFORE any VC transition. The vault-unlock password field
            // holds focus at this point; calling becomeFirstResponder() synchronously here
            // forces it to resign atomically — no gap where useKeyboard = 0 can fire.
            // Schedule defensive retries only when transitioning FROM an existing screen
            // (e.g. vault unlock → vault list). On the initial show (no prior children)
            // no retries are needed — nothing should steal focus from a screen with no
            // text fields — and retries would fight the vault-unlock password field.
            installKeyboardAnchor(scheduleRetries: !children.isEmpty)
        } else {
            // Resign any active first responder (e.g. the auth screen's password field) before
            // transitioning. Without this, UISearchController in the incoming view can inherit
            // keyboard focus, auto-activate, and leave the scroll view with incorrect insets when
            // it subsequently deactivates.
            view.endEditing(true)
        }

        removeChildViewController()

        if let toViewController = child.rootViewController {
            addChild(toViewController)
            view.addConstrained(subview: toViewController.view)
            toViewController.didMove(toParent: self)
        }

        if isAutofillText {
            // Brief suppression to block the search bar from auto-activating during the
            // asynchronous vault-data load immediately after the transition.
            searchActivationSuppressedUntil = Date().addingTimeInterval(2.0)
            installSearchBarSuppression(for: child)
            return
        }

        // UIKit may re-route keyboard focus to the first text input in the newly added child
        // (e.g. UISearchController's search bar) after didMove(toParent:). Resign again on the
        // next run loop tick to prevent the search bar from auto-activating in the extension.
        DispatchQueue.main.async { [weak self] in
            self?.view.endEditing(true)
        }

        // Arm the suppression deadline immediately, anchored to the vault-list appearance
        // time. This must happen before installSearchBarSuppression so that the deadline is
        // set even if the UISearchController hasn't been created by SwiftUI yet.
        searchActivationSuppressedUntil = Date().addingTimeInterval(5.0)

        // Install the UISearchBarDelegate that enforces the suppression window. The vault
        // list loads items asynchronously; UIKit layout updates triggered by incoming data
        // can cause UISearchController to auto-activate, sending stealKB:Y to the system.
        // If the host app simultaneously requests keyboard focus the race causes
        // SafariViewService to invalidate this extension's process assertions and suspend it.
        installSearchBarSuppression(for: child)
    }

    // MARK: Private methods

    /// Creates (once) and activates the keyboard anchor view so InputUI keeps the
    /// autofillText panel alive when no interactive text field is focused.
    private func installKeyboardAnchor(scheduleRetries: Bool = true) {
        if keyboardAnchorView == nil {
            let anchor = KeyboardAnchorTextField(frame: .zero)
            // isUserInteractionEnabled stays true (default) — zero frame prevents real touches,
            // but the flag must be true for becomeFirstResponder() to succeed.
            view.addSubview(anchor)
            keyboardAnchorView = anchor
        }
        // Synchronous — no async dispatch. The vault-unlock password field must resign in the
        // same UIKit pass, before any newly added child can re-claim focus.
        keyboardAnchorView?.becomeFirstResponder()

        guard scheduleRetries else { return }
        // Defensive retries within the search-suppression window (2 s). On screen
        // transitions (e.g. vault unlock → vault list), SwiftUI @FocusState callbacks and
        // VC-transition completions fire asynchronously and can steal first responder.
        // These retries are NOT scheduled for the initial show (vault unlock) because
        // vault-unlock screens may have their own text fields that legitimately need focus.
        for delay in [0.1, 0.35, 0.7] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let anchor = self?.keyboardAnchorView, !anchor.isFirstResponder else { return }
                anchor.becomeFirstResponder()
            }
        }
    }

    /// Installs `self` as the `UISearchBarDelegate` of the vault list's search bar so that
    /// `searchBarShouldBeginEditing` can enforce the suppression window.
    ///
    /// SwiftUI creates the UISearchController lazily during its deferred rendering pass
    /// (after at least one display-link callback). We therefore retry at short intervals —
    /// 0 ms, 80 ms, 250 ms — so the delegate is in place well before any auto-activation.
    /// The suppression deadline is set by the caller BEFORE this method runs, so the window
    /// is correctly anchored to the vault-list appearance time regardless of which retry
    /// finally finds the search controller.
    ///
    /// SwiftUI hooks search state via `UISearchResultsUpdating` and KVO on
    /// `UISearchController.isActive`, not via `UISearchBarDelegate`, so taking the delegate
    /// is safe.
    private func installSearchBarSuppression(for child: Navigator) {
        for delay in [0.0, 0.08, 0.25] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self,
                      let navController = child.rootViewController as? UINavigationController else { return }
                navController.viewControllers
                    .compactMap(\.navigationItem.searchController)
                    .forEach { searchController in
                        if searchController.isActive { searchController.isActive = false }
                        searchController.searchBar.delegate = self
                    }
            }
        }
    }

    /// Removes the first child view controller taking into account some edge cases.
    func removeChildViewController() {
        let fromViewController = children.first

        // HACK: [PM-28227] When opening this extension on mode `text to insert`
        // We can't use `removeFromSuperview` or the extension closes afterwards after a few seconds.
        // Therefore we have this hack to pop to root on navigation controller.
        // iOS sometimes changes something on the navigation from `prepareInterfaceForUserChoosingTextToInsert`
        // which needs this workaround.
        if let context,
           case .autofillText = context.extensionMode,
           let navController = fromViewController as? UINavigationController {
            // animated: false — prevents the async animation-completion callback from
            // firing viewDidAppear on the vault-unlock VC, which would trigger SwiftUI's
            // @FocusState and steal first responder from the keyboard anchor.
            navController.popToRootViewController(animated: false)
            return
        }

        // Pop to root first to clean up pushed VCs (e.g., autofillListForGroup)
        // and any associated UISearchController state before removing.
        if let navController = fromViewController as? UINavigationController {
            navController.popToRootViewController(animated: false)
        }

        if let fromViewController {
            fromViewController.willMove(toParent: nil)
            fromViewController.view.removeFromSuperview()
            fromViewController.removeFromParent()
        }
    }
}

// MARK: - UISearchBarDelegate

extension CredentialProviderViewController: UISearchBarDelegate {
    /// Blocks the search bar from becoming first responder during the suppression window that
    /// follows each vault-list transition. Once the window expires the search bar behaves
    /// normally so the user can search their vault.
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        guard let suppressedUntil = searchActivationSuppressedUntil,
              Date() < suppressedUntil else {
            return true
        }
        return false
    }

    /// After the user finishes a search (cancel or return key), return first-responder
    /// status to the anchor so InputUI does not start its 5-second session-end timer.
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if case .autofillText = context?.extensionMode {
            // Synchronous — reclaim first responder immediately so InputUI never sees a
            // gap where useKeyboard = 0 would start the 5-second session-end timer.
            keyboardAnchorView?.becomeFirstResponder()
        }
    }
}

// MARK: - KeyboardAnchorTextField

/// A zero-size, hidden UITextField that silently holds first-responder status in
/// `autofillText` mode to keep InputUI's keyboard session alive.
///
/// Using UITextField (rather than UIView) is required: UITextField has
/// `requiresKBWhenFirstResponder = 1`, so UIKit evaluates `useKeyboard = 1` even
/// with a custom `inputView`. Assigning `inputView = UIView()` in `init` sets the
/// backing `_inputView` ivar that UIKit reads internally — a computed-property
/// override is NOT sufficient because `_inputViewsForResponder` reads the ivar
/// directly and would bypass the Swift getter.
private final class KeyboardAnchorTextField: UITextField {
    override init(frame: CGRect) {
        super.init(frame: frame)
        inputView = UIView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }
} // swiftlint:disable:this file_length
