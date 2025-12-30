import SwiftUI

struct ProfileSetupView: View {
  @Bindable var store: AppStore

  @State private var displayName: String = ""
  @State private var handle: String = ""
  @State private var age: Int = 25
  @State private var gender: Gender = .preferNotToSay
  @State private var fitnessLevel: FitnessLevel = .beginner
  @State private var visibility: ProfileVisibility = .public
  @State private var hasFitnessTracker: Bool = false
  @Environment(\.colorScheme) private var scheme
  @State private var errorMessage: String?
  @State private var isSaving: Bool = false

  private var canSave: Bool {
    guard store.account != nil else { return false }
    return !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && handleIsValid(handle)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Spacing.l) {
        Text("Set up your profile")
          .font(DS.Typography.title)
          .padding(.horizontal, DS.Spacing.xl)
          .padding(.top, DS.Spacing.l)

        Text("Used for competitions and friend search. Keep it private if you prefer.")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Palette.subtext(scheme))
          .padding(.horizontal, DS.Spacing.xl)

        VStack(alignment: .leading, spacing: DS.Spacing.m) {
          VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Profile")
              .font(DS.Typography.section)

            TextField("Display name", text: $displayName)
              .textInputAutocapitalization(.words)
              .padding(DS.Spacing.l)
              .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                  .fill(DS.Palette.surface(scheme))
              )
              .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                  .stroke(DS.Palette.separator(scheme), lineWidth: 1)
              )

            TextField("Handle (e.g. samfit)", text: $handle)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
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
          .dsCard()
          .padding(.horizontal, DS.Spacing.xl)

          VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Basics")
              .font(DS.Typography.section)

            Stepper(value: $age, in: 13...100) {
              HStack {
                Text("Age")
                  .font(DS.Typography.body)
                Spacer()
                Text("\(age)")
                  .font(DS.Typography.body)
                  .foregroundStyle(DS.Palette.subtext(scheme))
                  .monospacedDigit()
              }
            }

            Divider().overlay(DS.Palette.separator(scheme))

            Picker("Gender", selection: $gender) {
              ForEach(Gender.allCases) { g in
                Text(g.title).tag(g)
              }
            }

            Picker("Fitness level", selection: $fitnessLevel) {
              ForEach(FitnessLevel.allCases) { level in
                Text(level.title).tag(level)
              }
            }

            Toggle("I use a fitness tracker (e.g. Apple Watch)", isOn: $hasFitnessTracker)
          }
          .dsCard()
          .padding(.horizontal, DS.Spacing.xl)

          VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Visibility")
              .font(DS.Typography.section)
            Picker("Profile", selection: $visibility) {
              ForEach(ProfileVisibility.allCases) { v in
                Text(v.title).tag(v)
              }
            }
            .pickerStyle(.segmented)
            .tint(DS.Palette.accent)
          }
          .dsCard()
          .padding(.horizontal, DS.Spacing.xl)

          Button {
            Task { await save() }
          } label: {
            Text(isSaving ? "Saving…" : "Create profile")
              .frame(maxWidth: .infinity)
              .padding(.vertical, DS.Spacing.m)
          }
          .buttonStyle(.borderedProminent)
          .tint(DS.Palette.accent)
          .disabled(!canSave)
          .padding(.horizontal, DS.Spacing.xl)
          .padding(.top, DS.Spacing.s)

          if let errorMessage {
            Text(errorMessage)
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Palette.danger)
              .padding(.horizontal, DS.Spacing.xl)
          }

          Spacer(minLength: DS.Spacing.xxl)
        }
      }
    }
    .dsScreenBackground()
    .onAppear { prefillIfNeeded() }
  }

  private func prefillIfNeeded() {
    guard store.profile == nil else { return }
    if displayName.isEmpty { displayName = store.account?.username.isEmpty == false ? store.account!.username : "You" }
    if handle.isEmpty { handle = store.account?.username.isEmpty == false ? store.account!.username : "user\(Int.random(in: 1000...9999))" }
  }

  private func save() async {
    guard let account = store.account else { return }
    let now = Date()
    errorMessage = nil
    isSaving = true
    defer { isSaving = false }

    let profile = UserProfile(
      id: account.userID,
      displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
      handle: normalizedHandle(handle),
      age: age,
      gender: gender,
      fitnessLevel: fitnessLevel,
      visibility: visibility,
      hasFitnessTracker: hasFitnessTracker,
      inventory: .empty,
      createdAt: now,
      updatedAt: now
    )

    // Write to backend if available, then persist locally.
    if Backend.shared.isAvailable {
      do {
        try await Backend.shared.upsertMyProfile(profile)
        store.profile = try await Backend.shared.fetchMyProfile() ?? profile
      } catch {
        errorMessage = "Couldn’t save to backend. Check Supabase setup and try again."
        return
      }
    } else {
      store.profile = profile
    }

    store.saveAll()
  }

  private func normalizedHandle(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private func handleIsValid(_ s: String) -> Bool {
    let h = normalizedHandle(s)
    guard h.count >= 3 && h.count <= 20 else { return false }
    return h.allSatisfy { ch in
      ch.isLetter || ch.isNumber || ch == "_"
    }
  }
}

