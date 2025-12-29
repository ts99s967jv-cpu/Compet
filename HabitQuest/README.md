## HabitQuest (SwiftUI iOS habit tracker + gamified challenges)

This repo contains the core Swift code + SwiftUI screens for an iOS app that:

- Tracks **custom habits** (daily check-ins)
- Gamifies progress via **streaks, XP, levels**
- Lets you create **custom competitions** (habits or Apple Health metrics)
- Notifies you when a friend **takes the lead** (local notification)
- Supports **light/dark/system** theme

### What’s included

- `HabitQuest/Core`: Pure app logic (models, scoring, persistence, HealthKit abstraction)
- `HabitQuest/App`: SwiftUI UI layer (tabs, screens, view models)

### How to run in Xcode (macOS)

Because this workspace runs on Linux, the code is provided as a clean SwiftUI codebase you can drop into an Xcode iOS project:

1. On your Mac: Xcode → **File → New → Project → App**
2. Select:
   - Interface: **SwiftUI**
   - Language: **Swift**
3. Copy everything from `HabitQuest/App` and `HabitQuest/Core` into your Xcode project (keep folder structure).
4. In your iOS target:
   - Add capability **HealthKit**
   - Add capability **Push Notifications** is **not required** (we use local notifications), but **Background Modes** are optional if you later want background refresh
5. Add these to your app’s `Info.plist`:
   - `NSHealthShareUsageDescription` = "HabitQuest uses Apple Health data for challenges."
   - `NSHealthUpdateUsageDescription` (optional) = "HabitQuest can write optional workout summaries."
   - `NSUserNotificationUsageDescription` (optional; iOS typically prompts without this, but having a message is helpful)
6. Build & run on a device (HealthKit requires a real device).

### Notes / next steps

- “Friends” are local/sample right now (no backend). The architecture is set up so you can later replace `FriendsService` with a real backend (CloudKit/Firebase/etc).
- “Sleep score” is implemented as **sleep duration** + a computed score mapping (customizable).

