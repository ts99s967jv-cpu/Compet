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

        if let profile = store.profile {
          Section("Power-ups inventory") {
            ForEach(PowerUpID.allCases) { id in
              HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                  HStack {
                    Text(id.title)
                    Spacer()
                    Text(id.rarity.title)
                      .font(.footnote)
                      .foregroundStyle(.secondary)
                  }
                  Text(id.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                Text("×\(profile.inventory.count(of: id))")
                  .font(.headline)
                  .monospacedDigit()
              }
              .padding(.vertical, 2)
            }

            Button("Grant demo power-ups") {
              InventoryService(store: store).grantDemoPack()
            }
          }
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

