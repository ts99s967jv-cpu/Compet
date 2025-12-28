import SwiftUI

struct GameSettingsForm: View {
  @Binding var settings: GameSettings
  let availableModes: [GameModeKind]

  var body: some View {
    Section("Game mode") {
      Picker("Mode", selection: $settings.mode) {
        ForEach(availableModes) { mode in
          Text(mode.title).tag(mode)
        }
      }
    }

    Section("Activity") {
      Picker("Activity", selection: $settings.activity) {
        ForEach(GameActivity.allCases) { activity in
          Text(activity.title).tag(activity)
        }
      }
    }

    Section("Time limit") {
      Stepper(value: $settings.timeLimitDays, in: 1...90) {
        HStack {
          Text("Days")
          Spacer()
          Text("\(settings.timeLimitDays)")
            .foregroundStyle(.secondary)
        }
      }
    }

    Section("Win condition") {
      Picker("Condition", selection: $settings.winCondition) {
        ForEach(GameWinCondition.allCases) { condition in
          Text(condition.title).tag(condition)
        }
      }
    }

    Section("Custom rules (placeholder)") {
      TextField("Add notes or rules…", text: $settings.customRulesNote, axis: .vertical)
        .lineLimit(3...6)
    }
  }
}

