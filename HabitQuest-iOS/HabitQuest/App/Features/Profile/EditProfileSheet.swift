import SwiftUI

struct EditProfileSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var scheme

  @Bindable var store: AppStore

  @State private var displayName: String = ""
  @State private var handle: String = ""
  @State private var age: Int = 25
  @State private var gender: Gender = .preferNotToSay
  @State private var fitnessLevel: FitnessLevel = .beginner
  @State private var visibility: ProfileVisibility = .public
  @State private var hasFitnessTracker: Bool = false

  @State private var errorMessage: String?

  private var canSave: Bool {
    guard store.profile != nil else { return false }
    return !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && handleIsValid(handle)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
          Text("Edit profile")
            .font(DS.Typography.title)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)

          if let errorMessage {
            Text(errorMessage)
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Palette.danger)
              .padding(.horizontal, DS.Spacing.xl)
          }

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

            Spacer(minLength: DS.Spacing.xl)
          }
        }
      }
      .dsScreenBackground()
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Save") { save() }
            .disabled(!canSave)
        }
      }
      .onAppear { prefill() }
    }
  }

  private func prefill() {
    errorMessage = nil
    guard let p = store.profile else { return }
    displayName = p.displayName
    handle = p.handle
    age = p.age
    gender = p.gender
    fitnessLevel = p.fitnessLevel
    visibility = p.visibility
    hasFitnessTracker = p.hasFitnessTracker
  }

  private func save() {
    errorMessage = nil
    guard var p = store.profile else { return }

    let dn = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !dn.isEmpty else {
      errorMessage = "Display name can’t be empty."
      return
    }
    guard handleIsValid(handle) else {
      errorMessage = "Handle must be 3–20 characters (letters, numbers, underscore)."
      return
    }

    p.displayName = dn
    p.handle = normalizedHandle(handle)
    p.age = age
    p.gender = gender
    p.fitnessLevel = fitnessLevel
    p.visibility = visibility
    p.hasFitnessTracker = hasFitnessTracker
    p.updatedAt = Date()
    store.profile = p
    store.saveAll()
    dismiss()
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

