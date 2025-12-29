import Foundation

enum HabitKind: String, Codable, CaseIterable, Identifiable {
  case template
  case custom

  var id: String { rawValue }
}

enum HabitTemplateID: String, Codable, CaseIterable, Identifiable {
  case stopSmoking
  case quitDrinking
  case goToGym
  case moreSteps
  case drinkWater

  var id: String { rawValue }

  var defaultName: String {
    switch self {
    case .stopSmoking: "Stop smoking"
    case .quitDrinking: "Quit drinking"
    case .goToGym: "Go to the gym"
    case .moreSteps: "Get more steps"
    case .drinkWater: "Drink more water"
    }
  }

  var defaultDescription: String {
    switch self {
    case .stopSmoking: "Stay smoke-free each day and build a streak."
    case .quitDrinking: "Stay alcohol-free each day and build a streak."
    case .goToGym: "Hit your gym frequency and keep your streak going."
    case .moreSteps: "Reach your daily step goal."
    case .drinkWater: "Reach your daily water goal."
    }
  }
}

enum HabitVisibility: String, Codable, CaseIterable, Identifiable {
  case `public`
  case `private`
  case secret

  var id: String { rawValue }

  var title: String {
    switch self {
    case .public: "Public"
    case .private: "Private"
    case .secret: "Secret"
    }
  }

  var isHiddenFromOthers: Bool { self != .public }
}

enum HabitBehavior: String, Codable, CaseIterable, Identifiable {
  /// Doing something (build habit).
  case build
  /// Not doing something (break habit).
  case breakHabit

  var id: String { rawValue }
}

enum HabitPeriod: String, Codable, CaseIterable, Identifiable {
  case day
  case week

  var id: String { rawValue }
}

enum HabitMetric: String, Codable, CaseIterable, Identifiable {
  case steps
  case waterLiters
  case workouts
  case custom

  var id: String { rawValue }

  var title: String {
    switch self {
    case .steps: "Steps"
    case .waterLiters: "Water"
    case .workouts: "Workouts"
    case .custom: "Custom"
    }
  }

  var defaultUnit: String {
    switch self {
    case .steps: "steps"
    case .waterLiters: "L"
    case .workouts: "sessions"
    case .custom: "units"
    }
  }
}

enum HabitGoal: Codable, Equatable, Hashable {
  /// Streak-based: one check-in per period (day/week).
  case streak(period: HabitPeriod)
  /// Goal-based: reach a numeric target per period (day/week).
  case target(metric: HabitMetric, unit: String, period: HabitPeriod, target: Double)

  var period: HabitPeriod {
    switch self {
    case .streak(let period): period
    case .target(_, _, let period, _): period
    }
  }
}

struct Habit: Codable, Equatable, Identifiable, Hashable {
  var id: String

  var kind: HabitKind
  var templateID: HabitTemplateID?

  var name: String
  var description: String

  var behavior: HabitBehavior
  var goal: HabitGoal

  var visibility: HabitVisibility
  var createdAt: Date
  var isActive: Bool

  /// Per-day completion (used for streak and for gym/day-based logging).
  var completedDayKeys: Set<String>
  /// Per-day numeric progress (used for target-based habits).
  var progressByDayKey: [String: Double]
  /// Slip days for break-habit templates (optional).
  var slipDayKeys: Set<String>

  init(
    id: String = UUID().uuidString,
    kind: HabitKind,
    templateID: HabitTemplateID? = nil,
    name: String,
    description: String,
    behavior: HabitBehavior,
    goal: HabitGoal,
    visibility: HabitVisibility = .private,
    createdAt: Date = Date(),
    isActive: Bool = true,
    completedDayKeys: Set<String> = [],
    progressByDayKey: [String: Double] = [:],
    slipDayKeys: Set<String> = []
  ) {
    self.id = id
    self.kind = kind
    self.templateID = templateID
    self.name = name
    self.description = description
    self.behavior = behavior
    self.goal = goal
    self.visibility = visibility
    self.createdAt = createdAt
    self.isActive = isActive
    self.completedDayKeys = completedDayKeys
    self.progressByDayKey = progressByDayKey
    self.slipDayKeys = slipDayKeys
  }
}

extension Habit {
  enum Audience {
    case owner
    case otherUser
  }

  /// Whether this habit should be shown to the given audience.
  /// - Public: visible
  /// - Private: hidden
  /// - Secret: visible but masked
  func isVisible(to audience: Audience) -> Bool {
    switch audience {
    case .owner:
      return true
    case .otherUser:
      return visibility != .private
    }
  }

  /// Display name for the given audience. Secret habits are masked.
  func displayName(for audience: Audience) -> String {
    switch audience {
    case .owner:
      return name
    case .otherUser:
      return visibility == .secret ? "Secret habit" : name
    }
  }

  /// Display description for the given audience. Secret habits are masked.
  func displayDescription(for audience: Audience) -> String {
    switch audience {
    case .owner:
      return description
    case .otherUser:
      return visibility == .secret ? "Hidden details" : description
    }
  }

  static func template(_ id: HabitTemplateID) -> Habit {
    switch id {
    case .stopSmoking:
      return Habit(
        kind: .template,
        templateID: id,
        name: id.defaultName,
        description: id.defaultDescription,
        behavior: .breakHabit,
        goal: .streak(period: .day),
        visibility: .private
      )
    case .quitDrinking:
      return Habit(
        kind: .template,
        templateID: id,
        name: id.defaultName,
        description: id.defaultDescription,
        behavior: .breakHabit,
        goal: .streak(period: .day),
        visibility: .private
      )
    case .goToGym:
      // Weekly goal: 3 sessions/week by default.
      return Habit(
        kind: .template,
        templateID: id,
        name: id.defaultName,
        description: id.defaultDescription,
        behavior: .build,
        goal: .target(metric: .workouts, unit: HabitMetric.workouts.defaultUnit, period: .week, target: 3),
        visibility: .private
      )
    case .moreSteps:
      return Habit(
        kind: .template,
        templateID: id,
        name: id.defaultName,
        description: id.defaultDescription,
        behavior: .build,
        goal: .target(metric: .steps, unit: HabitMetric.steps.defaultUnit, period: .day, target: 10_000),
        visibility: .private
      )
    case .drinkWater:
      return Habit(
        kind: .template,
        templateID: id,
        name: id.defaultName,
        description: id.defaultDescription,
        behavior: .build,
        goal: .target(metric: .waterLiters, unit: HabitMetric.waterLiters.defaultUnit, period: .day, target: 2.0),
        visibility: .private
      )
    }
  }
}

// MARK: - Backward-compatible decoding for older Habit schema

extension Habit {
  private enum CodingKeys: String, CodingKey {
    case id
    case kind
    case templateID
    case name
    case description
    case behavior
    case goal
    case visibility
    case createdAt
    case isActive
    case completedDayKeys
    case progressByDayKey
    case slipDayKeys

    // Legacy keys
    case streakDays
    case lastCompletedDay
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)

    // If it looks like the new model, decode it.
    if c.contains(.kind) {
      id = try c.decode(String.self, forKey: .id)
      kind = try c.decode(HabitKind.self, forKey: .kind)
      templateID = try c.decodeIfPresent(HabitTemplateID.self, forKey: .templateID)
      name = try c.decode(String.self, forKey: .name)
      description = try c.decode(String.self, forKey: .description)
      behavior = try c.decode(HabitBehavior.self, forKey: .behavior)
      goal = try c.decode(HabitGoal.self, forKey: .goal)
      visibility = try c.decode(HabitVisibility.self, forKey: .visibility)
      createdAt = try c.decode(Date.self, forKey: .createdAt)
      isActive = try c.decode(Bool.self, forKey: .isActive)
      completedDayKeys = try c.decodeIfPresent(Set<String>.self, forKey: .completedDayKeys) ?? []
      progressByDayKey = try c.decodeIfPresent([String: Double].self, forKey: .progressByDayKey) ?? [:]
      slipDayKeys = try c.decodeIfPresent(Set<String>.self, forKey: .slipDayKeys) ?? []
      return
    }

    // Legacy migration: assume a simple daily streak build habit.
    id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
    name = (try? c.decode(String.self, forKey: .name)) ?? "Habit"
    createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
    isActive = (try? c.decode(Bool.self, forKey: .isActive)) ?? true

    kind = .custom
    templateID = nil
    description = ""
    behavior = .build
    goal = .streak(period: .day)
    visibility = .private

    completedDayKeys = []
    progressByDayKey = [:]
    slipDayKeys = []

    if let last = try? c.decodeIfPresent(Date.self, forKey: .lastCompletedDay), let last {
      let dayKey = Self.dayKey(for: last, calendar: .current)
      completedDayKeys.insert(dayKey)
    }
  }

  static func dayKey(for date: Date, calendar: Calendar) -> String {
    let d = calendar.startOfDay(for: date)
    let comps = calendar.dateComponents([.year, .month, .day], from: d)
    let y = comps.year ?? 0
    let m = comps.month ?? 0
    let day = comps.day ?? 0
    return String(format: "%04d-%02d-%02d", y, m, day)
  }
}

