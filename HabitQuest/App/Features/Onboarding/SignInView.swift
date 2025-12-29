import SwiftUI

struct SignInView: View {
  @Bindable var store: AppStore
  @State private var errorMessage: String?
  @Environment(\.colorScheme) private var scheme
  @State private var email: String = ""
  @State private var username: String = ""

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
        Text("Create account")
          .font(DS.Typography.section)

        TextField("Email address", text: $email)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .keyboardType(.emailAddress)
          .textContentType(.emailAddress)
          .padding(DS.Spacing.l)
          .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
              .fill(DS.Palette.surface(scheme))
          )
          .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
              .stroke(DS.Palette.separator(scheme), lineWidth: 1)
          )

        TextField("Username", text: $username)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .textContentType(.username)
          .padding(DS.Spacing.l)
          .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
              .fill(DS.Palette.surface(scheme))
          )
          .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
              .stroke(DS.Palette.separator(scheme), lineWidth: 1)
          )

        Button {
          createAccount()
        } label: {
          Text("Continue")
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.m)
        }
        .buttonStyle(.borderedProminent)
        .tint(DS.Palette.accent)

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
    .navigationBarBackButtonHidden(true)
  }

  private func createAccount() {
    errorMessage = nil
    let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    guard e.contains("@"), e.contains(".") else {
      errorMessage = "Enter a valid email."
      return
    }
    guard u.count >= 3, u.count <= 20, u.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
      errorMessage = "Username must be 3–20 characters (letters, numbers, underscore)."
      return
    }

    store.account = Account(userID: e, email: e, username: u, createdAt: Date())
    store.saveAll()
  }
}

