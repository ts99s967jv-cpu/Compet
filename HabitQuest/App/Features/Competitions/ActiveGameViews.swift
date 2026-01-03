import SwiftUI

struct IdentifiedID: Identifiable, Hashable {
  let id: String
}

struct ActiveGameCard: View {
  @Environment(\.colorScheme) private var scheme
  @Bindable var store: AppStore
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

        TimelineView(.periodic(from: .now, by: 1)) { ctx in
          let now = ctx.date
          if let wave = nextWaveInfo(now: now) {
            Text("\(wave.label): \(CountdownFormatter.ddHHmmss(to: wave.date, now: now))")
              .font(DS.Typography.caption.weight(.semibold))
              .foregroundStyle(DS.Palette.subtext(scheme))
              .monospacedDigit()
          }
        }

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
            if let endsAt = elim.endsAt,
               let schedule = SeasonWaveService.scheduleForSystemGame(
                winCondition: game.settings.winCondition,
                seasonStart: game.createdAt,
                seasonEnd: endsAt
               ) {
              let st = SeasonWaveService.status(now: now, schedule: schedule)
              Text("Wave \(st.currentWave.number)/\(schedule.maxWaves)")
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(DS.Palette.subtext(scheme))
                .monospacedDigit()
            } else {
              Text("Round \(elim.roundIndex + 1)")
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(DS.Palette.subtext(scheme))
                .monospacedDigit()
            }
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

  private func nextWaveInfo(now: Date) -> (label: String, date: Date)? {
    switch game.settings.winCondition {
    case .levelVsLevelGoal:
      guard let state = game.levelVsLevel else { return nil }
      return ("Next wave", state.turnStartedAt.addingTimeInterval(24 * 60 * 60))
    case .mostPointsAtEnd:
      let endsAt = game.createdAt.addingTimeInterval(TimeInterval(game.settings.timeLimitDays) * 24 * 60 * 60)
      return ("Ends", endsAt)
    case .eliminationLastManStanding, .kingOfMonth, .kingOfYear:
      guard let elim = game.elimination else { return nil }
      if let endsAt = elim.endsAt,
         let schedule = SeasonWaveService.scheduleForSystemGame(
          winCondition: game.settings.winCondition,
          seasonStart: game.createdAt,
          seasonEnd: endsAt
         ) {
        let st = SeasonWaveService.status(now: now, schedule: schedule)
        if st.isSeasonComplete { return ("Final wave", schedule.seasonEnd) }
        return ("Next wave", st.cutoff)
      } else {
        let cutoff = nextCutoff(from: elim.roundStartedAt, cadence: elim.cadence) ?? now
        if let endsAt = elim.endsAt, (cutoff >= endsAt || now >= endsAt) {
          return ("Final wave", endsAt)
        }
        return ("Next wave", cutoff)
      }
    }
  }

  private func nextCutoff(from start: Date, cadence: EliminationCadence) -> Date? {
    let cal = Calendar.current
    switch cadence {
    case .daily:
      return cal.date(byAdding: .day, value: 1, to: start)
    case .weekly:
      return cal.date(byAdding: .day, value: 7, to: start)
    case .monthly:
      return cal.date(byAdding: .month, value: 1, to: start)
    }
  }

  private func timeRemainingText(to cutoff: Date, now: Date) -> String {
    CountdownFormatter.ddHHmmss(to: cutoff, now: now)
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
  @State private var primaryView: ActiveGamePrimaryView = .map

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
          if game == nil {
            missingActiveGameContent
          } else if let game, game.settings.winCondition == .levelVsLevelGoal, let state = game.levelVsLevel {
            levelVsLevelContent(game: game, state: state)
          } else if let game,
                    let elim = game.elimination,
                    (game.settings.winCondition == .eliminationLastManStanding
                     || game.settings.winCondition == .kingOfMonth
                     || game.settings.winCondition == .kingOfYear) {
            eliminationContent(game: game, elim: elim)

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

          } else if let game {
            mostPointsContent(game: game)
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

  private var missingActiveGameContent: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.m) {
      HStack(spacing: 12) {
        Circle()
          .fill(DS.Palette.accent.opacity(0.16))
          .frame(width: 44, height: 44)
          .overlay(
            Image(systemName: "checkmark.circle")
              .foregroundStyle(DS.Palette.accent)
          )

        VStack(alignment: .leading, spacing: 2) {
          Text("This game is no longer available")
            .font(DS.Typography.section)
          Text("It may have ended, or you may have left it.")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
        Spacer()
      }

      Button {
        dismiss()
      } label: {
        Text("Close")
          .frame(maxWidth: .infinity)
          .padding(.vertical, DS.Spacing.m)
      }
      .buttonStyle(.borderedProminent)
      .tint(DS.Palette.accent)
    }
    .dsCard()
    .padding(.horizontal, DS.Spacing.xl)
    .padding(.top, DS.Spacing.l)
    .onAppear {
      // If the backing game vanishes while this sheet is visible, auto-close.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        dismiss()
      }
    }
  }

  private func subtitle(for game: ActiveGame) -> String {
    switch game.settings.winCondition {
    case .eliminationLastManStanding:
      return "Elimination • Bottom removed daily"
    case .kingOfMonth:
      return "Monthly champion • Bottom removed weekly • Join anytime"
    case .kingOfYear:
      return "Yearly champion • Bottom removed monthly • Join anytime"
    case .levelVsLevelGoal:
      return "Level vs level • Beat yesterday’s score"
    default:
      return "Competition"
    }
  }

  @ViewBuilder
  private func levelVsLevelContent(game: ActiveGame, state: LevelVsLevelState) -> some View {
    let svc = ActiveGamesService(store: store)
    let cutoff = state.turnStartedAt.addingTimeInterval(24 * 60 * 60)

    let activeUserID = state.turnOrderUserIDs[safe: state.currentTurnPlayerIndex] ?? ""
    let players: [TowerPlayer] = game.players.map { u in
      let score = svc.leaderboardPointsFor(activeGameID: game.id, userID: u.id, roundIndex: state.turnIndex, seed: state.turnStartedAt)
      return TowerPlayer(
        id: u.id,
        displayName: u.displayName,
        score: score,
        isMe: u.id == store.profile?.id,
        isActiveTurn: u.id == activeUserID
      )
    }

    VStack(alignment: .leading, spacing: DS.Spacing.m) {
      Picker("View", selection: $primaryView) {
        ForEach(ActiveGamePrimaryView.allCases) { t in
          Text(t.title).tag(t)
        }
      }
      .pickerStyle(.segmented)
      .tint(DS.Palette.accent)
      .padding(.horizontal, DS.Spacing.xl)
      .padding(.top, DS.Spacing.l)

      if primaryView == .map {
        LevelVsLevelTowerCard(
          title: game.title,
          subtitle: "Next wave in \(timeRemainingText(to: cutoff, now: now)) • Target \(state.currentTarget)",
          turnIndex: state.turnIndex,
          currentTarget: state.currentTarget,
          lastAchievedScore: state.lastAchievedScore,
          players: players
        )
        .padding(.horizontal, DS.Spacing.xl)

        VStack(alignment: .leading, spacing: DS.Spacing.s) {
          Text("Today’s turn")
            .font(DS.Typography.section)
          let activeName = game.players.first(where: { $0.id == activeUserID })?.displayName ?? "Player"
          Text("Up now: \(activeName)")
            .font(DS.Typography.body.weight(.semibold))
          Text("Target: \(state.currentTarget) • Next wave in \(timeRemainingText(to: cutoff, now: now))")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
          if let last = state.lastAchievedScore {
            Text("Previous score: \(last) → you must beat it")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Palette.subtext(scheme))
          }
        }
        .dsCard()
        .padding(.horizontal, DS.Spacing.xl)
      } else {
        // Leaderboard view for the current turn (prototype).
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
          Text(game.title)
            .font(DS.Typography.title)
          Text(subtitle(for: game))
            .font(DS.Typography.body)
            .foregroundStyle(DS.Palette.subtext(scheme))

          Divider().overlay(DS.Palette.separator(scheme))

          ForEach(players.sorted(by: { $0.score > $1.score })) { p in
            HStack {
              Text(p.displayName)
                .font(DS.Typography.body.weight(.semibold))
              Spacer()
              Text("\(p.score)")
                .font(DS.Typography.body.weight(.semibold))
                .monospacedDigit()
            }
            .foregroundStyle(p.isMe ? DS.Palette.accent : DS.Palette.text(scheme))
          }

          Text("Scoring: \(game.settings.scoringSummary)")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
        .dsCard()
        .padding(.horizontal, DS.Spacing.xl)
      }

      VStack(alignment: .leading, spacing: DS.Spacing.s) {
        Text("Result")
          .font(DS.Typography.section)

        if game.status == .finished {
          let winner = state.winnerUserID.flatMap { id in game.players.first(where: { $0.id == id })?.displayName } ?? "—"
          Text("Winner: \(winner)")
            .font(DS.Typography.body.weight(.semibold))
            .foregroundStyle(DS.Palette.accent)
        } else {
          Text("Round \(state.turnIndex + 1) • Updates at turn end")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
      }
      .dsCard()
      .padding(.horizontal, DS.Spacing.xl)
    }
  }

  @ViewBuilder
  private func eliminationContent(game: ActiveGame, elim: EliminationState) -> some View {
    let svc = ActiveGamesService(store: store)
    let cutoff: Date = {
      if let endsAt = elim.endsAt,
         let schedule = SeasonWaveService.scheduleForSystemGame(
          winCondition: game.settings.winCondition,
          seasonStart: game.createdAt,
          seasonEnd: endsAt
         ) {
        return SeasonWaveService.status(now: now, schedule: schedule).cutoff
      }
      return svc.nextEliminationDate(for: elim) ?? .now
    }()
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

    Picker("View", selection: $primaryView) {
      ForEach(ActiveGamePrimaryView.allCases) { t in
        Text(t.title).tag(t)
      }
    }
    .pickerStyle(.segmented)
    .tint(DS.Palette.accent)
    .padding(.horizontal, DS.Spacing.xl)
    .padding(.top, DS.Spacing.l)

    if primaryView == .map {
      let map = game.settings.mapStyle.resolved(for: game.settings.activity)
    let maxDistance = max(0, rowsDesc.first?.1 ?? 0)
    let visibleMaxDistance = max(1, maxDistance + 5_000)
      let wave = nextWave(for: game, elim: elim, cutoff: cutoff, now: now)
      GameMapExplorerCard(
        title: game.title,
        subtitle: "\(subtitle(for: game)) • \(wave.label) in \(timeRemainingText(to: wave.date, now: now))",
        style: map,
        checkpoints: defaultCheckpoints(maxScore: visibleMaxDistance, activity: game.settings.activity),
        players: rowsDesc.map { (u, s) in
          let raw = Double(max(0, s)) / Double(visibleMaxDistance)
          let minProgress = min(0.04, 120.0 / Double(max(1, visibleMaxDistance)))
          GameMapPlayer(
            id: u.id,
            displayName: u.displayName,
            progress: min(0.995, max(minProgress, raw)),
            isMe: u.id == store.profile?.id
          )
        }
      )
      .padding(.horizontal, DS.Spacing.xl)

      VStack(alignment: .leading, spacing: DS.Spacing.s) {
        if let endsAt = elim.endsAt,
           let schedule = SeasonWaveService.scheduleForSystemGame(
            winCondition: game.settings.winCondition,
            seasonStart: game.createdAt,
            seasonEnd: endsAt
           ) {
          let st = SeasonWaveService.status(now: now, schedule: schedule)
          Text("Wave \(st.currentWave.number)/\(schedule.maxWaves) • \(wave.label) \(waveDisplayDate(wave.date, for: game).formatted(date: .abbreviated, time: .omitted))")
        } else {
          Text("Round \(elim.roundIndex + 1) • \(wave.label) \(waveDisplayDate(wave.date, for: game).formatted(date: .abbreviated, time: .omitted))")
        }
          .font(DS.Typography.caption.weight(.semibold))
          .foregroundStyle(DS.Palette.subtext(scheme))
        if projected > 0 {
          Text("Elimination zone: bottom \(projected) player\(projected == 1 ? "" : "s")")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
      }
      .dsCard()
      .padding(.horizontal, DS.Spacing.xl)

      if let endsAt = elim.endsAt, (game.settings.winCondition == .kingOfMonth || game.settings.winCondition == .kingOfYear) {
        let nextCycle = Calendar.current.date(byAdding: .second, value: 1, to: endsAt) ?? endsAt
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
          Text("Season")
            .font(DS.Typography.section)
          Text("Ends in \(timeRemainingText(to: endsAt, now: now)) • Next cycle \(nextCycle.formatted(date: .abbreviated, time: .omitted))")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
        .dsCard()
        .padding(.horizontal, DS.Spacing.xl)
      }
    } else {
      VStack(alignment: .leading, spacing: DS.Spacing.s) {
        Text("Schedule")
          .font(DS.Typography.section)
        if game.settings.winCondition == .kingOfMonth || game.settings.winCondition == .kingOfYear {
          Text("Season: \(game.createdAt.formatted(date: .abbreviated, time: .omitted)) → \((elim.endsAt ?? .now).formatted(date: .abbreviated, time: .omitted))")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
        }

        if let endsAt = elim.endsAt,
           let schedule = SeasonWaveService.scheduleForSystemGame(
            winCondition: game.settings.winCondition,
            seasonStart: game.createdAt,
            seasonEnd: endsAt
           ) {
          let st = SeasonWaveService.status(now: now, schedule: schedule)
          Text("Wave \(st.currentWave.number)/\(schedule.maxWaves) • \(elim.cadence.title) elimination")
        } else {
          Text("Round \(elim.roundIndex + 1) • \(elim.cadence.title) elimination")
        }
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))

        let wave = nextWave(for: game, elim: elim, cutoff: cutoff, now: now)
        Text("\(wave.label): \(waveDisplayDate(wave.date, for: game).formatted(date: .abbreviated, time: .omitted))")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))

        Text("Time remaining: \(timeRemainingText(to: wave.date, now: now))")
          .font(DS.Typography.caption.weight(.semibold))
          .foregroundStyle(DS.Palette.subtext(scheme))
      }
      .dsCard()
      .padding(.horizontal, DS.Spacing.xl)

      VStack(alignment: .leading, spacing: DS.Spacing.s) {
        Text("Scoreboard")
          .font(DS.Typography.section)

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
    }
  }

  @ViewBuilder
  private func mostPointsContent(game: ActiveGame) -> some View {
    let svc = ActiveGamesService(store: store)
    let meID = store.profile?.id
    let seed = game.createdAt
    let rowsDesc = game.players
      .map { ($0, svc.leaderboardPointsFor(activeGameID: game.id, userID: $0.id, roundIndex: 0, seed: seed)) }
      .sorted { $0.1 > $1.1 }

    let maxDistance = max(0, rowsDesc.first?.1 ?? 0)
    let visibleMaxDistance = max(1, maxDistance + 5_000)
    let endsAt = game.createdAt.addingTimeInterval(TimeInterval(game.settings.timeLimitDays) * 24 * 60 * 60)

    Picker("View", selection: $primaryView) {
      ForEach(ActiveGamePrimaryView.allCases) { t in
        Text(t.title).tag(t)
      }
    }
    .pickerStyle(.segmented)
    .tint(DS.Palette.accent)
    .padding(.horizontal, DS.Spacing.xl)
    .padding(.top, DS.Spacing.l)

    if primaryView == .map {
      let map = game.settings.mapStyle.resolved(for: game.settings.activity)
      GameMapExplorerCard(
        title: game.title,
        subtitle: "\(game.settings.activity.title) • Ends in \(timeRemainingText(to: endsAt, now: now))",
        style: map,
        checkpoints: defaultCheckpoints(maxScore: visibleMaxDistance, activity: game.settings.activity),
        players: rowsDesc.map { (u, s) in
          let raw = Double(max(0, s)) / Double(visibleMaxDistance)
          let minProgress = min(0.04, 120.0 / Double(max(1, visibleMaxDistance)))
          GameMapPlayer(
            id: u.id,
            displayName: u.displayName,
            progress: min(0.995, max(minProgress, raw)),
            isMe: u.id == meID
          )
        }
      )
      .padding(.horizontal, DS.Spacing.xl)

      VStack(alignment: .leading, spacing: DS.Spacing.s) {
        Text("Scoring: \(game.settings.scoringSummary)")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))
      }
      .dsCard()
      .padding(.horizontal, DS.Spacing.xl)
    } else {
      VStack(alignment: .leading, spacing: DS.Spacing.s) {
        Text(game.title)
          .font(DS.Typography.title)
        Text("\(game.settings.activity.title) • \(game.settings.winCondition.title)")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Palette.subtext(scheme))

        Divider().overlay(DS.Palette.separator(scheme))

        ForEach(Array(rowsDesc.enumerated()), id: \.offset) { idx, row in
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
          .foregroundStyle(row.0.id == meID ? DS.Palette.accent : DS.Palette.text(scheme))
          if idx != rowsDesc.count - 1 {
            Divider().overlay(DS.Palette.separator(scheme))
          }
        }

        Text("Ends in \(timeRemainingText(to: endsAt, now: now)) • \(game.settings.scoringSummary)")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))
      }
      .dsCard()
      .padding(.horizontal, DS.Spacing.xl)
    }
  }

  private func defaultCheckpoints(maxScore: Int, activity: GameActivity) -> [GameCheckpoint] {
    let fracs: [Double] = [0.25, 0.5, 0.75, 1.0]
    var lastValue = 0
    let step = stepSizeForCheckpoints(maxScore: maxScore, activity: activity)
    return fracs.map { f in
      let raw = Int((Double(maxScore) * f).rounded())
      let target = (f >= 0.999) ? maxScore : raw
      var rounded = roundForDisplay(target, activity: activity, step: step)
      if rounded <= lastValue, f < 0.999 {
        rounded = min(maxScore, lastValue + step)
      }
      lastValue = max(lastValue, rounded)
      return GameCheckpoint(id: "\(f)", progress: f, label: checkpointLabel(value: rounded, activity: activity))
    }
  }

  private func stepSizeForCheckpoints(maxScore: Int, activity: GameActivity) -> Int {
    switch activity {
    case .steps:
      if maxScore < 400 { return 50 }
      if maxScore < 1200 { return 100 }
      if maxScore < 4000 { return 250 }
      if maxScore < 12000 { return 500 }
      if maxScore < 30000 { return 1000 }
      return 2000
    default:
      return 1
    }
  }

  private func roundForDisplay(_ v: Int, activity: GameActivity, step: Int) -> Int {
    switch activity {
    case .steps:
      return max(step, (v / step) * step)
    case .running, .cycling, .swimming:
      return max(1, v)
    case .strengthTraining, .yoga, .meditation:
      return max(1, v)
    }
  }

  private func checkpointLabel(value: Int, activity: GameActivity) -> String {
    switch activity {
    case .steps:
      if value >= 10_000 { return "\(value / 1000)k" }
      if value >= 1000 { return "\(value / 1000)k" }
      return "\(value)"
    default:
      return "\(value)"
    }
  }

  private func startAutoSyncLoop() async {
    // Update countdown every second; sync score once per minute; tick game waves locally.
    let syncInterval: TimeInterval = 60
    var lastSync: Date = .distantPast
    while !Task.isCancelled {
      now = Date()
      // Advances elimination waves and resolves games on schedule.
      ActiveGamesService(store: store).tick(now: now)
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
    CountdownFormatter.ddHHmmss(to: cutoff, now: now)
  }

  private func nextWave(for game: ActiveGame, elim: EliminationState, cutoff: Date, now: Date) -> (label: String, date: Date) {
    if let endsAt = elim.endsAt,
       let schedule = SeasonWaveService.scheduleForSystemGame(
        winCondition: game.settings.winCondition,
        seasonStart: game.createdAt,
        seasonEnd: endsAt
       ) {
      let st = SeasonWaveService.status(now: now, schedule: schedule)
      if st.isSeasonComplete { return ("Final wave", schedule.seasonEnd) }
      return ("Next wave", st.cutoff)
    }
    if let endsAt = elim.endsAt {
      if now >= endsAt { return ("Final wave", endsAt) }
      if cutoff >= endsAt { return ("Final wave", endsAt) }
    }
    return ("Next wave", cutoff)
  }

  private func waveDisplayDate(_ waveDate: Date, for game: ActiveGame) -> Date {
    // Wave cutoffs for system games are defined as end-of-period already.
    _ = game
    return waveDate
  }
}

