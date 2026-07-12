import AuthenticationServices
import FirebaseAuth
import SwiftUI

struct LoginView: View {
    @State private var nonce: String = ""
    @State private var error: String?
    @State private var isSigningIn = false
    @ScaledMetric(relativeTo: .largeTitle) private var logoSize: CGFloat = 64

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: logoSize))
                    .foregroundStyle(Color.accentColor)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                Text("Shuhari")
                    .font(.largeTitle.bold())
                Text("Ton carnet d'expérimentation. Connecte-toi pour commencer.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            SignInWithAppleButton(.signIn) { request in
                let raw = AppleNonce.random()
                nonce = raw
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleNonce.sha256(raw)
            } onCompletion: { result in
                Task { await handle(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 32)
            .disabled(isSigningIn)
            .accessibilityIdentifier("sign-in-apple")
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }
            Spacer().frame(height: 40)
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) async {
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let auth = try result.get()
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else {
                error = "Apple n'a pas renvoyé de jeton."
                return
            }
            let oauth = OAuthProvider.appleCredential(
                withIDToken: token,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            _ = try await Auth.auth().signIn(with: oauth)
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}

#Preview {
    LoginView()
}
