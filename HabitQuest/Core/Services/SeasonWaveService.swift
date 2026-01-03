import Foundation

/// Centralized, calendar-derived wave logic for system season games.
enum SeasonWaveService {
  struct Schedule: Equatable {
    var maxWaves: Int
    /// 1-based wave segments, ordered.
    var waves: [Wave]
    var seasonStart: Date
    var seasonEnd: Date
  }

  struct Wave: Equatable {
    var number: Int               // 1-based
    var start: Date               // inclusive
    var end: Date                 // inclusive (end-of-period, i.e. ...-1s)
  }

  struct WaveStatus: Equatable {
    var currentWave: Wave
    var maxWaves: Int
    /// End of the current wave (the elimination boundary).
    var cutoff: Date
    /// True iff the season is complete (past final cutoff).
    var isSeasonComplete: Bool
  }

  static func scheduleForSystemGame(
    winCondition: GameWinCondition,
    seasonStart: Date,
    seasonEnd: Date,
    calendar: Calendar = .current
  ) -> Schedule? {
    switch winCondition {
    case .kingOfMonth:
      return monthlySchedule(seasonStart: seasonStart, seasonEnd: seasonEnd, calendar: calendar)
    case .kingOfYear:
      return yearlySchedule(seasonStart: seasonStart, seasonEnd: seasonEnd, calendar: calendar)
    default:
      return nil
    }
  }

  static func status(now: Date, schedule: Schedule) -> WaveStatus {
    let waves = schedule.waves
    if now >= schedule.seasonEnd {
      return WaveStatus(
        currentWave: waves.last!,
        maxWaves: schedule.maxWaves,
        cutoff: schedule.seasonEnd,
        isSeasonComplete: true
      )
    }
    let current = waves.last(where: { now >= $0.start }) ?? waves.first!
    return WaveStatus(
      currentWave: current,
      maxWaves: schedule.maxWaves,
      cutoff: current.end,
      isSeasonComplete: false
    )
  }

  static func clampWave(_ wave: Int, maxWaves: Int) -> Int {
    min(max(wave, 1), maxWaves)
  }

  // MARK: Schedules

  private static func monthlySchedule(seasonStart: Date, seasonEnd: Date, calendar: Calendar) -> Schedule {
    // 4 waves, derived from calendar week boundaries, clamped.
    // We define wave boundaries by walking week-of-month starts from the season start.
    let maxWaves = 4
    let seasonStartDay = calendar.startOfDay(for: seasonStart)
    let seasonEndClamped = seasonEnd

    var starts: [Date] = [seasonStartDay]
    for i in 1..<maxWaves {
      // Seed a date ~i weeks into the month, then use calendar week-of-month start.
      let seed = calendar.date(byAdding: .day, value: i * 7, to: seasonStartDay) ?? seasonStartDay
      let weekStart = calendar.dateInterval(of: .weekOfMonth, for: seed)?.start ?? seed
      starts.append(max(weekStart, seasonStartDay))
    }

    // Ensure strictly increasing starts (avoid duplicates from calendar edge cases).
    var normalized: [Date] = []
    for s in starts {
      if let last = normalized.last, s <= last {
        normalized.append(calendar.date(byAdding: .day, value: 1, to: last) ?? last.addingTimeInterval(86_400))
      } else {
        normalized.append(s)
      }
    }

    var waves: [Wave] = []
    for idx in 0..<maxWaves {
      let start = normalized[idx]
      let end: Date
      if idx < maxWaves - 1 {
        // Elimination happens at the end of the wave → last second before next wave start.
        end = (calendar.date(byAdding: .second, value: -1, to: normalized[idx + 1]) ?? normalized[idx + 1].addingTimeInterval(-1))
      } else {
        end = seasonEndClamped
      }
      waves.append(Wave(number: idx + 1, start: start, end: end))
    }

    return Schedule(maxWaves: maxWaves, waves: waves, seasonStart: seasonStartDay, seasonEnd: seasonEndClamped)
  }

  private static func yearlySchedule(seasonStart: Date, seasonEnd: Date, calendar: Calendar) -> Schedule {
    let maxWaves = 12
    let seasonStartMonth = calendar.dateInterval(of: .month, for: seasonStart)?.start ?? calendar.startOfDay(for: seasonStart)
    let seasonEndClamped = seasonEnd

    var waves: [Wave] = []
    for i in 0..<maxWaves {
      let monthStart = calendar.date(byAdding: .month, value: i, to: seasonStartMonth) ?? seasonStartMonth
      let nextMonthStart = calendar.date(byAdding: .month, value: i + 1, to: seasonStartMonth) ?? monthStart
      let end = min(
        seasonEndClamped,
        (calendar.date(byAdding: .second, value: -1, to: nextMonthStart) ?? nextMonthStart.addingTimeInterval(-1))
      )
      waves.append(Wave(number: i + 1, start: monthStart, end: end))
    }

    return Schedule(maxWaves: maxWaves, waves: waves, seasonStart: seasonStartMonth, seasonEnd: seasonEndClamped)
  }
}

