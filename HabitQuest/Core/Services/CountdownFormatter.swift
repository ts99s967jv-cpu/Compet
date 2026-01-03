import Foundation

enum CountdownFormatter {
  /// Formats countdowns as `DD:HH:MM:SS`.
  ///
  /// Rules:
  /// - Days are included only when >= 1.
  /// - HH/MM/SS are always 2 digits.
  static func ddHHmmss(to target: Date, now: Date = Date()) -> String {
    let total = max(0, Int(target.timeIntervalSince(now).rounded(.down)))
    let days = total / 86_400
    let hours = (total % 86_400) / 3_600
    let minutes = (total % 3_600) / 60
    let seconds = total % 60

    if days >= 1 {
      return "\(days):" + two(hours) + ":" + two(minutes) + ":" + two(seconds)
    }
    return two(hours) + ":" + two(minutes) + ":" + two(seconds)
  }

  private static func two(_ v: Int) -> String {
    String(format: "%02d", max(0, v))
  }
}

