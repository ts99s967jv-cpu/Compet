import SwiftUI

struct ProfileSetupView: View {
  @Bindable var store: AppStore

  @State private var displayName: String = ""
  @State private var handle: String = ""
  @State private var age: Int = 25
  @State private var gender: Gender = .preferNotToSay
  @State private var fitnessLevel: FitnessLevel = .beginner
  @State private var visibility: ProfileVisibility = .public

  private var canSave: Bool {
    guard store.account != nil else { return false }
    return !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && handleIsValid(handle)
  }

  var body: some View {
    Form {
      Section {
        TextField("Display name", text: $displayName)
          .textInputAutocapitalization(.words)

        TextField("Handle (e.g. samfit)", text: $handle)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
      } header: {
        Text("Profile")
      } footer: {
        Text("Your handle is used for friend search. You can keep your profile private.")
      }

      Section("Basics") {
        Stepper(value: $age, in: 13...100) {
          HStack {
            Text("Age")
            Spacer()
            Text("\(age)")
              .foregroundStyle(.secondary)
          }
        }

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
      }

      Section("Visibility") {
        Picker("Profile", selection: $visibility) {
          ForEach(ProfileVisibility.allCases) { v in
            Text(v.title).tag(v)
          }
        }
        .pickerStyle(.segmented)
      }

      Section {
        Button("Create profile") { save() }
          .disabled(!canSave)
      }
    }
    .navigationTitle("Set up your profile")
    .onAppear { prefillIfNeeded() }
  }

  private func prefillIfNeeded() {
    guard store.profile == nil else { return }
    if displayName.isEmpty { displayName = "You" }
    if handle.isEmpty { handle = "user\(Int.random(in: 1000...9999))" }
  }

  private func save() {
    guard let account = store.account else { return }
    let now = Date()
    store.profile = UserProfile(
      id: account.appleUserID,
      displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
      handle: normalizedHandle(handle),
      age: age,
      gender: gender,
      fitnessLevel: fitnessLevel,
      visibility: visibility,
      inventory: .empty,
      createdAt: now,
      updatedAt: now
    )
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

