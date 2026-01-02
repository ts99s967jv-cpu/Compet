import SwiftUI

struct SignInView: View {
  @Bindable var store: AppStore
  @State private var errorMessage: String?
  @Environment(\.colorScheme) private var scheme
  @State private var email: String = ""
  @State private var username: String = ""
  @State private var password: String = ""
  @State private var mode: AuthMode = .signUp
  @State private var isLoading: Bool = false
  @State private var infoMessage: String?

  private enum AuthMode: String, CaseIterable, Identifiable {
    case signUp
    case signIn
    var id: String { rawValue }
    var title: String { self == .signUp ? "Sign up" : "Log in" }
  }

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
        Picker("Mode", selection: $mode) {
          ForEach(AuthMode.allCases) { m in
            Text(m.title).tag(m)
          }
        }
        .pickerStyle(.segmented)
        .tint(DS.Palette.accent)

        Text(mode == .signUp ? "Create account" : "Log in")
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

        if mode == .signUp {
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
        }

        SecureField("Password", text: $password)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .textContentType(mode == .signUp ? .newPassword : .password)
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
          Task { await submit() }
        } label: {
          Text(isLoading ? "Please wait…" : (mode == .signUp ? "Create account" : "Log in"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.m)
        }
        .buttonStyle(.borderedProminent)
        .tint(DS.Palette.accent)
        .disabled(isLoading)

        if let errorMessage {
          Text(errorMessage)
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.danger)
        }

        if let infoMessage {
          Text(infoMessage)
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }

        if !BackendConfig.isSupabaseConfigured {
          Text("Backend not configured: \(BackendConfig.supabaseConfigStatusMessage ?? "Missing required config")")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        } else if !BackendConfig.hasSupabaseSDK {
          Text("Backend config is present, but the Supabase SDK isn't linked. Add the supabase-swift package to the Xcode project to enable real sign up/login.")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        } else if !Backend.shared.isAvailable {
          Text("Backend config is present, but the Supabase SDK isn't linked. Add the supabase-swift package to the Xcode project to enable real sign up/login.")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }

#if DEBUG
        Text(BackendConfig.debugSummary)
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))
#endif
      }
      .dsCard()
      .padding(.horizontal, DS.Spacing.xl)

      Spacer()
    }
    .dsScreenBackground()
    .navigationBarBackButtonHidden(true)
  }

  private func validate() -> (email: String, username: String, password: String)? {
    errorMessage = nil
    infoMessage = nil
    let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let p = password.trimmingCharacters(in: .whitespacesAndNewlines)

    guard e.contains("@"), e.contains(".") else {
      errorMessage = "Enter a valid email."
      return nil
    }
    if mode == .signUp {
      guard u.count >= 3, u.count <= 20, u.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
        errorMessage = "Username must be 3–20 characters (letters, numbers, underscore)."
        return nil
      }
    }
    if mode == .signUp || mode == .signIn {
      guard isPasswordValid(p) else {
        errorMessage = "Password must be 8+ chars and include upper, lower, number, and symbol."
        return nil
      }
    }
    return (e, u, p)
  }

  private func submit() async {
    guard let v = validate() else { return }
    isLoading = true
    defer { isLoading = false }

    // Require real backend auth (no local prototype accounts).
    if !Backend.shared.isAvailable {
      if !BackendConfig.isSupabaseConfigured {
        errorMessage = BackendConfig.supabaseConfigStatusMessage ?? "Backend not configured."
      } else if !BackendConfig.hasSupabaseSDK {
        errorMessage = "Supabase SDK isn't linked (missing Swift Package dependency)."
      } else {
        errorMessage = "Backend unavailable."
      }
      return
    }

    do {
      let userID: String
      switch mode {
      case .signUp:
        _ = try await Backend.shared.signUp(email: v.email, password: v.password)
        // Many Supabase projects require email confirmation. If so, sign-in will fail until confirmed.
        do {
          userID = try await Backend.shared.signIn(email: v.email, password: v.password)
        } catch {
          infoMessage = "Account created. If login fails, your Supabase project likely requires email confirmation before sign-in. Confirm your email in the message Supabase sent, or disable email confirmations in Supabase Auth settings."
          return
        }

        // Ensure a profile exists once we have a session.
        if (try await Backend.shared.fetchMyProfile()) == nil {
          let now = Date()
          let profile = UserProfile(
            id: userID,
            displayName: v.username,
            handle: v.username,
            age: 18,
            gender: .preferNotToSay,
            fitnessLevel: .beginner,
            visibility: .public,
            hasFitnessTracker: false,
            fitnessElo: nil,
            fitnessEloUpdatedAt: nil,
            inventory: .empty,
            createdAt: now,
            updatedAt: now
          )
          try await Backend.shared.upsertMyProfile(profile)
        }
      case .signIn:
        userID = try await Backend.shared.signIn(email: v.email, password: v.password)
      }

      let fetchedProfile = try await Backend.shared.fetchMyProfile()

      // Persist local session marker.
      store.account = Account(
        userID: userID,
        email: v.email,
        username: mode == .signUp ? v.username : (fetchedProfile?.handle ?? ""),
        createdAt: Date()
      )
      store.profile = fetchedProfile
      store.saveAll()
    } catch {
      let ns = error as NSError
      let desc = (ns.userInfo[NSLocalizedDescriptionKey] as? String) ?? error.localizedDescription
      errorMessage = "Auth failed: \(desc)"
    }
  }

  private func isPasswordValid(_ p: String) -> Bool {
    guard p.count >= 8 else { return false }
    let hasUpper = p.contains(where: { $0.isUppercase })
    let hasLower = p.contains(where: { $0.isLowercase })
    let hasDigit = p.contains(where: { $0.isNumber })
    let hasSymbol = p.contains(where: { !($0.isLetter || $0.isNumber) })
    return hasUpper && hasLower && hasDigit && hasSymbol
  }
}

