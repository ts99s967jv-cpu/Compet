import SwiftUI

struct IdentifiedID: Identifiable, Hashable {
  let id: String
}

struct ActiveGameCard: View {
  @Environment(\.colorScheme) private var scheme
  let game: ActiveGame
  let tapped: () -> Void

  var body: some View {
    Button(action: tapped) {
      VStack(alignment: .leading, spacing: DS.Spacing.s) {
        HStack {
          Text(game.title)
            .font(DS.Typography.section)
            .foregroundStyle(DS.Palette.text(scheme))
          Spacer()
          Text(game.status == .active ? "Active" : "Finished")
            .font(DS.Typography.caption.weight(.semibold))
            .foregroundStyle(game.status == .active ? DS.Palette.accent : DS.Palette.subtext(scheme))
        }

        Text("\(game.settings.activity.title) • \(game.settings.winCondition.title)")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))
          .lineLimit(2)

        if (game.settings.winCondition == .eliminationLastManStanding
            || game.settings.winCondition == .kingOfMonth
            || game.settings.winCondition == .kingOfYear),
           let elim = game.elimination {
          HStack {
            Text("Players: \(remainingCount(game, elim))")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Palette.subtext(scheme))
              .monospacedDigit()
            Spacer()
            Text("Round \(elim.roundIndex + 1)")
              .font(DS.Typography.caption.weight(.semibold))
              .foregroundStyle(DS.Palette.subtext(scheme))
              .monospacedDigit()
          }
        }
      }
      .dsCard()
    }
    .buttonStyle(.plain)
  }

  private func remainingCount(_ game: ActiveGame, _ elim: EliminationState) -> Int {
    game.players.filter { !elim.eliminatedUserIDs.contains($0.id) }.count
  }
}

struct ActiveGameDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  let gameID: String

  private var game: ActiveGame? { store.activeGames.first(where: { $0.id == gameID }) }
  @State private var now: Date = Date()
  @State private var isSyncing: Bool = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
          if let game,
             let elim = game.elimination,
             (game.settings.winCondition == .eliminationLastManStanding
              || game.settings.winCondition == .kingOfMonth
              || game.settings.winCondition == .kingOfYear) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
              Text(game.title)
                .font(DS.Typography.title)
              Text(subtitle(for: game))
                .font(DS.Typography.body)
                .foregroundStyle(DS.Palette.subtext(scheme))
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
              Text("Schedule")
                .font(DS.Typography.section)
              if game.settings.winCondition == .kingOfMonth || game.settings.winCondition == .kingOfYear {
                Text("Season: \(game.createdAt.formatted(date: .abbreviated, time: .omitted)) → \((elim.endsAt ?? .now).formatted(date: .abbreviated, time: .omitted))")
                  .font(DS.Typography.caption)
                  .foregroundStyle(DS.Palette.subtext(scheme))
              }

              Text("Round \(elim.roundIndex + 1) • \(elim.cadence.title) elimination")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Palette.subtext(scheme))

              let svc = ActiveGamesService(store: store)
              let cutoff = svc.nextEliminationDate(for: elim) ?? .now
              Text("Next elimination: \(cutoff.formatted(date: .abbreviated, time: .shortened))")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Palette.subtext(scheme))

              Text("Time remaining: \(timeRemainingText(to: cutoff, now: now))")
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(DS.Palette.subtext(scheme))

              let projected = svc.projectedEliminationsThisRound(game: game)
              if projected > 0 {
                Text("Elimination zone: bottom \(projected) player\(projected == 1 ? "" : "s")")
                  .font(DS.Typography.caption)
                  .foregroundStyle(DS.Palette.subtext(scheme))
              }
            }
            .dsCard()
            .padding(.horizontal, DS.Spacing.xl)

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
              Text("Scoreboard")
                .font(DS.Typography.section)

              let svc = ActiveGamesService(store: store)
              let remaining = game.players.filter { !elim.eliminatedUserIDs.contains($0.id) }
              let rowsDesc = remaining
                .map { ($0, svc.leaderboardPointsFor(activeGameID: game.id, userID: $0.id, roundIndex: elim.roundIndex, seed: elim.roundStartedAt)) }
                .sorted { $0.1 > $1.1 }

              let projected = svc.projectedEliminationsThisRound(game: game)
              let eliminationZoneIDs: Set<String> = Set(
                rowsDesc
                  .suffix(max(0, min(projected, rowsDesc.count)))
                  .map { $0.0.id }
              )

              ForEach(Array(rowsDesc.enumerated()), id: \.offset) { idx, row in
                let isInZone = eliminationZoneIDs.contains(row.0.id)
                HStack {
                  Text("#\(idx + 1)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Palette.subtext(scheme))
                    .frame(width: 28, alignment: .leading)
                    .monospacedDigit()
                  Text(row.0.displayName)
                    .font(DS.Typography.body.weight(.semibold))
                  Spacer()
                  Text("\(row.1)")
                    .font(DS.Typography.body.weight(.semibold))
                    .monospacedDigit()
                }
                .foregroundStyle(isInZone ? DS.Palette.danger : DS.Palette.text(scheme))
                if idx != rowsDesc.count - 1 {
                  Divider().overlay(DS.Palette.separator(scheme))
                }
              }

              if let meID = store.profile?.id,
                 let score = store.gameScore(activeGameID: game.id, roundIndex: elim.roundIndex, userID: meID) {
                Text("Synced \(score.updatedAt.formatted(date: .abbreviated, time: .shortened)) • \(game.settings.scoringSummary)")
                  .font(DS.Typography.caption)
                  .foregroundStyle(DS.Palette.subtext(scheme))
              } else {
                Text("Syncing uses Apple Health: \(game.settings.scoringSummary).")
                  .font(DS.Typography.caption)
                  .foregroundStyle(DS.Palette.subtext(scheme))
              }

              if let meID = store.profile?.id, eliminationZoneIDs.contains(meID) {
                Text("You’re currently in the elimination zone. Increase your points before the cutoff.")
                  .font(DS.Typography.caption.weight(.semibold))
                  .foregroundStyle(DS.Palette.danger)
              }
            }
            .dsCard()
            .padding(.horizontal, DS.Spacing.xl)

            if !elim.eliminatedUserIDs.isEmpty {
              VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Text("Eliminated")
                  .font(DS.Typography.section)
                ForEach(elim.eliminatedUserIDs, id: \.self) { id in
                  Text(game.players.first(where: { $0.id == id })?.displayName ?? "Unknown")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Palette.subtext(scheme))
                }
              }
              .dsCard()
              .padding(.horizontal, DS.Spacing.xl)
            }

            Button {
              withAnimation(.easeInOut(duration: 0.25)) {
                ActiveGamesService(store: store).simulateEndOfRound(gameID: gameID)
              }
            } label: {
              Text("Simulate next elimination (prototype)")
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Palette.accent)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.s)
          }

          Spacer(minLength: DS.Spacing.xxl)
        }
        .padding(.bottom, DS.Spacing.xxl)
      }
      .dsScreenBackground()
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
      }
    }
    .task { await startAutoSyncLoop() }
  }

  private func subtitle(for game: ActiveGame) -> String {
    switch game.settings.winCondition {
    case .eliminationLastManStanding:
      return "Elimination • Bottom removed daily"
    case .kingOfMonth:
      return "Monthly champion • Bottom removed weekly • Join anytime"
    case .kingOfYear:
      return "Yearly champion • Bottom removed monthly • Join anytime"
    default:
      return "Competition"
    }
  }

  private func startAutoSyncLoop() async {
    // Update countdown every second; sync score once per minute.
    let syncInterval: TimeInterval = 60
    var lastSync: Date = .distantPast
    while !Task.isCancelled {
      now = Date()
      if now.timeIntervalSince(lastSync) >= syncInterval, let game {
        lastSync = now
        if !isSyncing {
          isSyncing = true
          await GameScoreSyncService(store: store).syncMyScore(for: game, now: now)
          isSyncing = false
        }
      }
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
  }

  private func timeRemainingText(to cutoff: Date, now: Date) -> String {
    let s = max(0, Int(cutoff.timeIntervalSince(now)))
    let h = s / 3600
    let m = (s % 3600) / 60
    let sec = s % 60
    if h > 0 { return "\(h)h \(m)m" }
    if m > 0 { return "\(m)m \(sec)s" }
    return "\(sec)s"
  }
}

