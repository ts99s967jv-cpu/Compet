import Foundation

enum BackendConfig {
  /// Set these in `HabitQuest/Info.plist` (not committed secrets; use anon key).
  static var supabaseURL: URL? {
    guard let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
          let url = URL(string: s), !s.isEmpty else { return nil }
    return url
  }

  static var supabaseAnonKey: String? {
    guard let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String, !s.isEmpty else { return nil }
    return s
  }

  static var isSupabaseConfigured: Bool {
    supabaseURL != nil && (supabaseAnonKey?.isEmpty == false)
  }
}

