import SwiftUI

struct SettingsView: View {
  @Bindable var store: AppStore

  var body: some View {
    NavigationStack {
      Form {
        if let profile = store.profile {
          Section("Profile") {
            LabeledContent("Name", value: profile.displayName)
            LabeledContent("Handle", value: "@\(profile.handle)")

            Picker("Visibility", selection: $store.profile!.visibility) {
              ForEach(ProfileVisibility.allCases) { v in
                Text(v.title).tag(v)
              }
            }
            .onChange(of: store.profile?.visibility) { _, _ in
              store.profile?.updatedAt = Date()
              store.saveAll()
            }
          }
        }

        Section("Theme") {
          Picker("App theme", selection: $store.theme) {
            ForEach(AppTheme.allCases) { theme in
              Text(theme.title).tag(theme)
            }
          }
          .onChange(of: store.theme) { _, _ in store.saveAll() }
        }

        Section {
          Button("Sign out", role: .destructive) {
            store.signOut()
          }
        }
      }
      .navigationTitle("Settings")
    }
  }
}

