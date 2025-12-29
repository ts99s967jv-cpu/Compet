import AuthenticationServices
import SwiftUI

struct SignInView: View {
  @Bindable var store: AppStore
  @State private var errorMessage: String?
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    VStack(spacing: DS.Spacing.xl) {
      Spacer(minLength: DS.Spacing.xxl)

      VStack(alignment: .leading, spacing: DS.Spacing.s) {
        Text("HabitQuest")
          .font(DS.Typography.title)

        Text("A calm, health-focused way to stay consistent — alone or with others.")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Palette.subtext(scheme))
      }
      .padding(.horizontal, DS.Spacing.xl)

      VStack(alignment: .leading, spacing: DS.Spacing.m) {
        SignInWithAppleButton(.signIn) { request in
          request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
          switch result {
          case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
              errorMessage = "Couldn’t read Apple ID credential."
              return
            }
            store.account = Account(appleUserID: credential.user, createdAt: Date())
            store.saveAll()
          case .failure(let error):
            errorMessage = error.localizedDescription
          }
        }
        .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
        .frame(height: 52)

        if let errorMessage {
          Text(errorMessage)
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.danger)
        }
      }
      .dsCard()
      .padding(.horizontal, DS.Spacing.xl)

      Spacer()
    }
    .dsScreenBackground()
    .navigationBarHidden(true)
  }
}

