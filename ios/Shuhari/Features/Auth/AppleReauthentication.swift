import AuthenticationServices

/// Runs Sign in with Apple for the sole purpose of collecting a fresh authorization
/// code. Apple requires an app that signs cooks in with Apple to revoke that token
/// when the account goes, and the code is the only thing Firebase can revoke with —
/// it is handed out once, at sign-in, and never stored. So deletion asks for it again.
///
/// Cancelling the sheet throws `.canceled`, which callers treat as "changed their
/// mind", not as a failure worth reporting.
@MainActor
final class AppleReauthentication: NSObject {
    private var continuation: CheckedContinuation<String, Error>?
    /// Held for the lifetime of the request: `ASAuthorizationController` keeps only a
    /// weak reference to its delegate, and a released one silently never answers.
    private var controller: ASAuthorizationController?

    enum Failure: Error { case canceled, noAuthorizationCode }

    func authorizationCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<String, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        controller = nil
    }
}

extension AppleReauthentication: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        let code = (authorization.credential as? ASAuthorizationAppleIDCredential)
            .flatMap(\.authorizationCode)
            .flatMap { String(data: $0, encoding: .utf8) }

        Task { @MainActor in
            guard let code else {
                finish(.failure(Failure.noAuthorizationCode))
                return
            }
            finish(.success(code))
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let canceled = (error as? ASAuthorizationError)?.code == .canceled
        Task { @MainActor in
            finish(.failure(canceled ? Failure.canceled : error))
        }
    }
}

extension AppleReauthentication: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            return scene?.keyWindow ?? ASPresentationAnchor()
        }
    }
}
