import Foundation

enum BackendConfig {
  static let hasSupabaseSDK: Bool = {
#if canImport(Supabase)
    return true
#else
    return false
#endif
  }()

  private static func rawStringValue(_ key: String) -> String? {
    if let s = Bundle.main.object(forInfoDictionaryKey: key) as? String { return s }
    if let s = ProcessInfo.processInfo.environment[key] { return s }
    return nil
  }

  private static func normalizedString(_ key: String) -> String? {
    guard let raw = rawStringValue(key) else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  /// Set these in `HabitQuest/Info.plist` (not committed secrets; use anon key).
  static var supabaseURL: URL? {
    guard var s = normalizedString("SUPABASE_URL") else { return nil }
    if !(s.hasPrefix("http://") || s.hasPrefix("https://")) {
      s = "https://\(s)"
    }
    return URL(string: s)
  }

  static var supabaseAnonKey: String? {
    normalizedString("SUPABASE_ANON_KEY")
  }

  static var isSupabaseConfigured: Bool {
    supabaseURL != nil && (supabaseAnonKey?.isEmpty == false)
  }

  static var supabaseConfigStatusMessage: String? {
    var issues: [String] = []
    if normalizedString("SUPABASE_URL") == nil {
      issues.append("Missing SUPABASE_URL")
    } else if supabaseURL == nil {
      issues.append("Invalid SUPABASE_URL")
    }
    if normalizedString("SUPABASE_ANON_KEY") == nil {
      issues.append("Missing SUPABASE_ANON_KEY")
    }
    if issues.isEmpty { return nil }
    return issues.joined(separator: " • ")
  }

#if DEBUG
  static var debugSummary: String {
    let url = rawStringValue("SUPABASE_URL") ?? "(missing)"
    let keyPresent = (normalizedString("SUPABASE_ANON_KEY") != nil)
    let status = supabaseConfigStatusMessage ?? "OK"
    return "hasSupabaseSDK=\(hasSupabaseSDK) supabaseURL=\(url) anonKeyPresent=\(keyPresent) status=\(status)"
  }
#endif
}

