import Foundation

@MainActor
final class PublicGamesService {
  private let store: AppStore

  init(store: AppStore) {
    self.store = store
  }

  func createPublicGame(title: String, settings: GameSettings, maxPlayers: Int) {
    guard let me = store.profile?.asPublicUser() else { return }
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

    let clampedMax = min(50, max(2, maxPlayers))
    let game = PublicGame(
      id: UUID().uuidString,
      title: trimmed.isEmpty ? "Public Challenge" : trimmed,
      createdAt: Date(),
      createdBy: me,
      settings: settings,
      status: .open,
      maxPlayers: clampedMax,
      players: [PublicGamePlayer(user: me, joinedAt: Date())]
    )
    store.addPublicGame(game)
  }

  func join(gameID: String) {
    guard let me = store.profile?.asPublicUser() else { return }
    guard var game = store.publicGames.first(where: { $0.id == gameID }) else { return }

    guard game.status == .open, !game.isFull else { return }
    if game.contains(userID: me.id) { return }

    game.players.append(PublicGamePlayer(user: me, joinedAt: Date()))
    if game.players.count >= game.maxPlayers {
      game.status = .started
    }
    store.updatePublicGame(game)
  }

  func leave(gameID: String) {
    guard let me = store.profile?.asPublicUser() else { return }
    guard var game = store.publicGames.first(where: { $0.id == gameID }) else { return }

    game.players.removeAll { $0.user.id == me.id }
    if game.players.isEmpty {
      store.removePublicGame(gameID: game.id)
      return
    }
    if game.status == .started, game.players.count < game.maxPlayers {
      game.status = .open
    }
    store.updatePublicGame(game)
  }
}

