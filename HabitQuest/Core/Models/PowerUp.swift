import Foundation

enum PowerUpRarity: String, Codable, CaseIterable, Identifiable {
  case common
  case rare
  case veryRare

  var id: String { rawValue }

  var title: String {
    switch self {
    case .common: "Common"
    case .rare: "Rare"
    case .veryRare: "Very rare"
    }
  }
}

/// Power-ups / debuffs that can be enabled in match settings and consumed in-game.
/// Local prototype: just defines the catalog + inventory storage; game runtime effects come later.
enum PowerUpID: String, Codable, CaseIterable, Identifiable, Hashable {
  /// Buff: increase your points by 1.2x
  case pointsBoost12x
  /// Debuff: decrease enemy points earned by 0.8x
  case enemyPoints08x
  /// Rare: freeze time for 1 hour
  case freezeTime1h
  /// Very rare: reverses enemy debuffs back onto them
  case unoReverseDebuffs

  var id: String { rawValue }

  var title: String {
    switch self {
    case .pointsBoost12x: "Points Boost"
    case .enemyPoints08x: "Enemy Slow"
    case .freezeTime1h: "Time Freeze"
    case .unoReverseDebuffs: "UNO Reverse"
    }
  }

  var rarity: PowerUpRarity {
    switch self {
    case .pointsBoost12x, .enemyPoints08x: .common
    case .freezeTime1h: .rare
    case .unoReverseDebuffs: .veryRare
    }
  }

  var isDebuff: Bool {
    switch self {
    case .enemyPoints08x: true
    default: false
    }
  }

  var description: String {
    switch self {
    case .pointsBoost12x:
      "Increase your points earned by 1.2×."
    case .enemyPoints08x:
      "Decrease the opponent’s points earned by 0.8×."
    case .freezeTime1h:
      "Freeze the match timer for 1 hour."
    case .unoReverseDebuffs:
      "Reflect enemy debuffs so they affect the caster instead."
    }
  }
}

struct UserInventory: Codable, Equatable, Hashable {
  /// Quantity by power-up.
  var quantities: [PowerUpID: Int]

  static let empty = UserInventory(quantities: [:])

  func count(of id: PowerUpID) -> Int {
    max(0, quantities[id] ?? 0)
  }

  func has(_ id: PowerUpID) -> Bool {
    count(of: id) > 0
  }
}

