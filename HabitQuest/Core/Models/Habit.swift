import Foundation

struct Habit: Codable, Equatable, Identifiable, Hashable {
  var id: String
  var name: String
  var createdAt: Date

  /// Current streak in days.
  var streakDays: Int

  /// Last day the habit was completed (start-of-day in current calendar).
  var lastCompletedDay: Date?

  /// Whether the habit is active (can be used later for archival).
  var isActive: Bool

  init(id: String = UUID().uuidString, name: String, createdAt: Date = Date(), streakDays: Int = 0, lastCompletedDay: Date? = nil, isActive: Bool = true) {
    self.id = id
    self.name = name
    self.createdAt = createdAt
    self.streakDays = streakDays
    self.lastCompletedDay = lastCompletedDay
    self.isActive = isActive
  }
}

