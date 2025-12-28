import SwiftUI

struct GameSettingsForm: View {
  @Binding var settings: GameSettings
  let availableModes: [GameModeKind]
  let inventory: UserInventory?

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

    if settings.winCondition == .levelVsLevelGoal {
      Section("Level vs level") {
        Stepper(value: $settings.levelVsLevelStartingTarget, in: 1...1_000_000, step: stepForActivity(settings.activity)) {
          HStack {
            Text("Starting target")
            Spacer()
            Text("\(settings.levelVsLevelStartingTarget)")
              .foregroundStyle(.secondary)
          }
        }
        Text("Each day the turn switches. You must beat the previous day’s score or you’re eliminated.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }

    Section("Power-ups") {
      if let inventory {
        ForEach(PowerUpID.allCases) { id in
          Toggle(isOn: Binding(
            get: { settings.enabledPowerUps.contains(id) },
            set: { isOn in
              if isOn {
                if !settings.enabledPowerUps.contains(id) { settings.enabledPowerUps.append(id) }
              } else {
                settings.enabledPowerUps.removeAll { $0 == id }
              }
            }
          )) {
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
          }
          .disabled(inventory.count(of: id) == 0)
        }

        if PowerUpID.allCases.allSatisfy({ inventory.count(of: $0) == 0 }) {
          Text("Win games to earn power-ups, then enable them here for future matches.")
            .foregroundStyle(.secondary)
        }
      } else {
        Text("Sign in and create a profile to enable power-ups.")
          .foregroundStyle(.secondary)
      }
    }

    Section("Custom rules (placeholder)") {
      TextField("Add notes or rules…", text: $settings.customRulesNote, axis: .vertical)
        .lineLimit(3...6)
    }
  }

  private func stepForActivity(_ activity: GameActivity) -> Int {
    switch activity {
    case .steps: 500
    case .running, .cycling, .swimming: 1
    case .strengthTraining, .yoga, .meditation: 5
    }
  }
}

