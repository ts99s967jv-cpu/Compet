import Foundation

enum PublicGameStatus: String, Codable, CaseIterable, Identifiable {
  case open
  case started
  case finished

  var id: String { rawValue }
}

enum PublicGameVisibility: String, Codable, CaseIterable, Identifiable {
  case `public`
  case `private`
  /// System-pinned event (open to anyone, no restrictions).
  case systemEvent

  var id: String { rawValue }

  var title: String {
    switch self {
    case .public: "Public"
    case .private: "Private"
    case .systemEvent: "Event"
    }
  }
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

  var visibility: PublicGameVisibility
  /// Pinned at top (used for system events).
  var isPinned: Bool
  /// If true, the lobby does not have a player limit.
  var isUnlimitedPlayers: Bool

  var settings: GameSettings
  var status: PublicGameStatus

  var maxPlayers: Int
  var players: [PublicGamePlayer]

  var isFull: Bool { isUnlimitedPlayers ? false : (players.count >= maxPlayers) }

  func contains(userID: String) -> Bool {
    players.contains(where: { $0.user.id == userID })
  }

  // MARK: - Backward compatible decoding

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case createdAt
    case createdBy
    case visibility
    case isPinned
    case isUnlimitedPlayers
    case settings
    case status
    case maxPlayers
    case players
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    title = try c.decode(String.self, forKey: .title)
    createdAt = try c.decode(Date.self, forKey: .createdAt)
    createdBy = try c.decode(PublicUser.self, forKey: .createdBy)
    settings = try c.decode(GameSettings.self, forKey: .settings)
    status = try c.decode(PublicGameStatus.self, forKey: .status)
    maxPlayers = try c.decode(Int.self, forKey: .maxPlayers)
    players = try c.decode([PublicGamePlayer].self, forKey: .players)

    visibility = (try? c.decode(PublicGameVisibility.self, forKey: .visibility)) ?? .public
    isPinned = (try? c.decode(Bool.self, forKey: .isPinned)) ?? false
    isUnlimitedPlayers = (try? c.decode(Bool.self, forKey: .isUnlimitedPlayers)) ?? false
  }

  init(
    id: String,
    title: String,
    createdAt: Date,
    createdBy: PublicUser,
    visibility: PublicGameVisibility = .public,
    isPinned: Bool = false,
    isUnlimitedPlayers: Bool = false,
    settings: GameSettings,
    status: PublicGameStatus,
    maxPlayers: Int,
    players: [PublicGamePlayer]
  ) {
    self.id = id
    self.title = title
    self.createdAt = createdAt
    self.createdBy = createdBy
    self.visibility = visibility
    self.isPinned = isPinned
    self.isUnlimitedPlayers = isUnlimitedPlayers
    self.settings = settings
    self.status = status
    self.maxPlayers = maxPlayers
    self.players = players
  }
}

