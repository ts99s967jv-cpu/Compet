import AuthenticationServices
import SwiftUI

struct SignInView: View {
  @Bindable var store: AppStore
  @State private var errorMessage: String?

  var body: some View {
    VStack(spacing: 16) {
      Spacer()

      VStack(spacing: 8) {
        Text("HabitQuest")
          .font(.largeTitle.bold())
        Text("Build habits. Compete with friends. Keep it simple.")
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal, 24)

      Spacer()

      SignInWithAppleButton(.signIn) { request in
        request.requestedScopes = [.fullName, .email]
      } onCompletion: { result in
        switch result {
        case .success(let auth):
          guard
            let credential = auth.credential as? ASAuthorizationAppleIDCredential
          else {
            errorMessage = "Couldn’t read Apple ID credential."
            return
          }
          store.account = Account(appleUserID: credential.user, createdAt: Date())
          store.saveAll()
        case .failure(let error):
          errorMessage = error.localizedDescription
        }
      }
      .signInWithAppleButtonStyle(.black)
      .frame(height: 52)
      .padding(.horizontal, 24)

      if let errorMessage {
        Text(errorMessage)
          .font(.footnote)
          .foregroundStyle(.red)
          .padding(.horizontal, 24)
      }

      Spacer()
      Spacer()
    }
    .navigationBarHidden(true)
  }
}

