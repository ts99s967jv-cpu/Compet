import Foundation

enum PublicGameStatus: String, Codable, CaseIterable, Identifiable {
  case open
  case started
  case finished

  var id: String { rawValue }
}

struct PublicGamePlayer: Codable, Equatable, Hashable, Identifiable {
  var id: String { user.id }
  var user: PublicUser
  var joinedAt: Date
}

/// Public lobby that anyone can browse and join (local prototype).
struct PublicGame: Codable, Equatable, Identifiable, Hashable {
  var id: String

  var title: String
  var createdAt: Date
  var createdBy: PublicUser

  var settings: GameSettings
  var status: PublicGameStatus

  var maxPlayers: Int
  var players: [PublicGamePlayer]

  var isFull: Bool { players.count >= maxPlayers }

  func contains(userID: String) -> Bool {
    players.contains(where: { $0.user.id == userID })
  }
}

