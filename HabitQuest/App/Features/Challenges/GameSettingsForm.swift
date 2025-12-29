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

    Section("Scoring (Health)") {
      Toggle("Phone-only metrics", isOn: Binding(
        get: { settings.phoneOnlyMetrics },
        set: { newValue in
          settings.phoneOnlyMetrics = newValue
          if newValue {
            // Restrict to phone-friendly metrics.
            settings.scoringMetrics = settings.scoringMetrics.filter { $0 == .steps || $0 == .activeEnergyBurned }
            if settings.scoringMetrics.isEmpty { settings.scoringMetrics = [.steps] }
          }
        }
      ))

      ForEach(ScoreMetric.allCases) { metric in
        Toggle(isOn: Binding(
          get: { settings.scoringMetrics.contains(metric) },
          set: { isOn in
            if settings.phoneOnlyMetrics && !(metric == .steps || metric == .activeEnergyBurned) {
              return
            }
            if isOn {
              if !settings.scoringMetrics.contains(metric) { settings.scoringMetrics.append(metric) }
            } else {
              settings.scoringMetrics.removeAll { $0 == metric }
              if settings.scoringMetrics.isEmpty {
                // Keep at least one metric selected.
                settings.scoringMetrics = [.steps]
              }
            }
          }
        )) {
          Text(metric.title)
        }
        .disabled(settings.phoneOnlyMetrics && !(metric == .steps || metric == .activeEnergyBurned))
      }

      Text("Phone-only games filter HealthKit samples to iPhone-recorded data only (excluding Apple Watch and samples without device attribution). Comparing players still requires syncing scores across devices (backend).")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    Section("Fairness") {
      Picker("Opponents", selection: $settings.opponentPolicy) {
        ForEach(TrackerOpponentPolicy.allCases) { p in
          Text(p.title).tag(p)
        }
      }
      Text("Players can self-report whether they use a fitness tracker. This setting limits who can join.")
        .font(.footnote)
        .foregroundStyle(.secondary)
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

