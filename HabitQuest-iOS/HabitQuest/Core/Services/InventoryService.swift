import Foundation

@MainActor
final class InventoryService {
  private let store: AppStore

  init(store: AppStore) {
    self.store = store
  }

  func grantDemoPack() {
    guard var profile = store.profile else { return }
    var q = profile.inventory.quantities

    q[.pointsBoost12x, default: 0] += 3
    q[.enemyPoints08x, default: 0] += 3
    q[.freezeTime1h, default: 0] += 1
    q[.unoReverseDebuffs, default: 0] += 0

    profile.inventory = UserInventory(quantities: q)
    profile.updatedAt = Date()
    store.profile = profile
    store.saveAll()
  }
}

