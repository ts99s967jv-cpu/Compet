import Foundation

enum BackendConfig {
  static let hasSupabaseSDK: Bool = {
#if canImport(Supabase)
    return true
#else
    return false
#endif
  }()

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

  static var supabaseRedirectURL: URL? {
    guard let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_REDIRECT_URL") as? String,
          let url = URL(string: s), !s.isEmpty else { return nil }
    return url
  }

  static var isSupabaseConfigured: Bool {
    supabaseURL != nil && (supabaseAnonKey?.isEmpty == false)
  }

#if DEBUG
  static var debugSummary: String {
    let url = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String) ?? "(missing)"
    let keyPresent = ((Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String)?.isEmpty == false)
    let redirect = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_REDIRECT_URL") as? String) ?? "(missing)"
    return "hasSupabaseSDK=\(hasSupabaseSDK) supabaseURL=\(url) anonKeyPresent=\(keyPresent) redirectURL=\(redirect)"
  }
#endif
}

