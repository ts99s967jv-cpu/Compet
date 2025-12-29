import Foundation

@MainActor
final class SystemEventsService {
  private let store: AppStore

  init(store: AppStore) {
    self.store = store
  }

  func sync(now: Date = Date()) {
    syncKingOfMonth(now: now)
    syncKingOfYear(now: now)
  }

  private func syncKingOfMonth(now: Date) {
    let cal = Calendar.current
    guard let month = cal.dateInterval(of: .month, for: now) else { return }
    let seasonStart = month.start
    let seasonEnd = month.end.addingTimeInterval(-1)
    let id = "sys_kom_" + seasonStart.formatted(.dateTime.year().month(.twoDigits))

    var settings = GameSettings.default(mode: .groupFriends)
    settings.winCondition = .kingOfMonth
    settings.scoringMetrics = [.steps, .activeEnergyBurned]
    settings.opponentPolicy = .anyone
    settings.phoneOnlyMetrics = false

    let systemUser = PublicUser(id: "system", displayName: "HabitQuest", handle: "habitquest", visibility: .public)
    let title = "King of the Month — " + seasonStart.formatted(.dateTime.month(.wide)) + " " + seasonStart.formatted(.dateTime.year())

    let publicGame = upsertSystemPublicGame(
      id: id,
      title: title,
      createdAt: seasonStart,
      createdBy: systemUser,
      settings: settings,
      seasonEnd: seasonEnd,
      now: now
    )

    if now >= seasonStart && now <= seasonEnd {
      ActiveGamesService(store: store).upsertSystemSeasonGame(publicGame: publicGame, seasonStart: seasonStart, seasonEnd: seasonEnd, now: now)
    }
  }

  private func syncKingOfYear(now: Date) {
    let cal = Calendar.current
    guard let year = cal.dateInterval(of: .year, for: now) else { return }
    let seasonStart = year.start
    let seasonEnd = year.end.addingTimeInterval(-1)
    let id = "sys_koy_" + seasonStart.formatted(.dateTime.year())

    var settings = GameSettings.default(mode: .groupFriends)
    settings.winCondition = .kingOfYear
    settings.scoringMetrics = [.steps, .activeEnergyBurned]
    settings.opponentPolicy = .anyone
    settings.phoneOnlyMetrics = false

    let systemUser = PublicUser(id: "system", displayName: "HabitQuest", handle: "habitquest", visibility: .public)
    let title = "King of the Year — " + seasonStart.formatted(.dateTime.year())

    let publicGame = upsertSystemPublicGame(
      id: id,
      title: title,
      createdAt: seasonStart,
      createdBy: systemUser,
      settings: settings,
      seasonEnd: seasonEnd,
      now: now
    )

    if now >= seasonStart && now <= seasonEnd {
      ActiveGamesService(store: store).upsertSystemSeasonGame(publicGame: publicGame, seasonStart: seasonStart, seasonEnd: seasonEnd, now: now)
    }
  }

  private func upsertSystemPublicGame(
    id: String,
    title: String,
    createdAt: Date,
    createdBy: PublicUser,
    settings: GameSettings,
    seasonEnd: Date,
    now: Date
  ) -> PublicGame {
    let status: PublicGameStatus = now > seasonEnd ? .finished : .started

    if var existing = store.publicGames.first(where: { $0.id == id }) {
      existing.title = title
      existing.createdAt = createdAt
      existing.createdBy = createdBy
      existing.visibility = .systemEvent
      existing.isPinned = true
      existing.isUnlimitedPlayers = true
      existing.settings = settings
      existing.status = status
      store.updatePublicGame(existing)
      return existing
    }

    let game = PublicGame(
      id: id,
      title: title,
      createdAt: createdAt,
      createdBy: createdBy,
      visibility: .systemEvent,
      isPinned: true,
      isUnlimitedPlayers: true,
      settings: settings,
      status: status,
      maxPlayers: 0,
      players: []
    )
    store.addPublicGame(game)
    return game
  }
}

