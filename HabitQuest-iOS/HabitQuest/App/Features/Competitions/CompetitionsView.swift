import SwiftUI

struct CompetitionsView: View {
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  @State private var showCreatePublicGame: Bool = false
  @State private var selectedPublicGameID: String?
  @State private var selectedActiveGameID: String?

  @State private var browseSort: BrowseSort = .newest
  @State private var filterMode: GameModeKind? = nil
  @State private var filterWinCondition: GameWinCondition? = nil
  @State private var filterMetric: ScoreMetric? = nil
  @State private var hideFull: Bool = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
          Text("Competitions")
            .font(DS.Typography.title)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)

          Text("Your active games, team battles, and public challenges.")
            .font(DS.Typography.body)
            .foregroundStyle(DS.Palette.subtext(scheme))
            .padding(.horizontal, DS.Spacing.xl)

          // System events pinned at the top (and nowhere else).
          let championshipEvents = store.publicGames
            .filter { $0.visibility == .systemEvent && $0.status != .finished }
            .sorted { ($0.title) < ($1.title) }

          VStack(spacing: DS.Spacing.m) {
            if !championshipEvents.isEmpty {
              Text("Championship events")
                .dsSectionHeader()

              ForEach(championshipEvents) { game in
                PublicGameCard(game: game, variant: .systemEvent) {
                  selectedPublicGameID = game.id
                }
                .padding(.horizontal, DS.Spacing.xl)
              }
            }
          }

          Text("Your games")
            .dsSectionHeader()

          VStack(spacing: DS.Spacing.m) {
            let comps = competitionCards
            // Hide system-season active games here; they are represented above as championship events.
            let activeGames = store.activeGames.filter { !$0.id.hasPrefix("ag_sys_") }

            if comps.isEmpty && activeGames.isEmpty {
              emptyState
                .padding(.horizontal, DS.Spacing.xl)
            } else {
              ForEach(comps) { card in
                CompetitionCardView(card: card)
                  .padding(.horizontal, DS.Spacing.xl)
                  .animation(.easeInOut(duration: 0.25), value: card.leaderName)
              }

              ForEach(activeGames) { game in
                ActiveGameCard(game: game) {
                  selectedActiveGameID = game.id
                }
                .padding(.horizontal, DS.Spacing.xl)
              }
            }
          }

          // Public lobbies (non-system), with filters.
          Text("Public games")
            .dsSectionHeader()

          VStack(spacing: DS.Spacing.m) {
            let meID = store.profile?.id ?? ""
            let privateLobbies = store.publicGames.filter { $0.visibility == .private && ($0.contains(userID: meID) || $0.createdBy.id == meID) }
            let basePublic = store.publicGames.filter { $0.visibility == .public && $0.status != .finished }

            let filtered = basePublic
              .filter { g in
                if hideFull, g.isFull { return false }
                if let filterMode, g.settings.mode != filterMode { return false }
                if let filterWinCondition, g.settings.winCondition != filterWinCondition { return false }
                if let filterMetric, !g.settings.scoringMetrics.contains(filterMetric) { return false }
                return true
              }

            let joined = filtered.filter { meID.isEmpty ? false : $0.contains(userID: meID) }
            let discover = filtered.filter { meID.isEmpty ? true : !$0.contains(userID: meID) }

            HStack(alignment: .firstTextBaseline) {
              Text("Browse")
                .font(DS.Typography.section)
              Spacer()
              Menu {
                Picker("Sort", selection: $browseSort) {
                  ForEach(BrowseSort.allCases) { s in
                    Text(s.title).tag(s)
                  }
                }
                Divider()
                Picker("Mode", selection: Binding(
                  get: { filterMode?.id ?? "all" },
                  set: { newValue in filterMode = (newValue == "all") ? nil : GameModeKind(rawValue: newValue) }
                )) {
                  Text("All").tag("all")
                  ForEach(GameModeKind.allCases) { m in
                    Text(m.title).tag(m.rawValue)
                  }
                }
                Picker("Win condition", selection: Binding(
                  get: { filterWinCondition?.id ?? "all" },
                  set: { newValue in filterWinCondition = (newValue == "all") ? nil : GameWinCondition(rawValue: newValue) }
                )) {
                  Text("All").tag("all")
                  ForEach(GameWinCondition.allCases) { w in
                    // System win conditions are still valid for private/public games, but system events are shown above.
                    Text(w.title).tag(w.rawValue)
                  }
                }
                Picker("Metric", selection: Binding(
                  get: { filterMetric?.shortTitle ?? "all" },
                  set: { newValue in
                    filterMetric = ScoreMetric.allCases.first(where: { $0.shortTitle == newValue })
                    if newValue == "all" { filterMetric = nil }
                  }
                )) {
                  Text("All").tag("all")
                  ForEach(ScoreMetric.allCases) { m in
                    Text(m.shortTitle).tag(m.shortTitle)
                  }
                }
                Toggle("Hide full games", isOn: $hideFull)
                Divider()
                Button("Reset filters") {
                  browseSort = .newest
                  filterMode = nil
                  filterWinCondition = nil
                  filterMetric = nil
                  hideFull = false
                }
              } label: {
                Label("Filter & sort", systemImage: "line.3.horizontal.decrease.circle")
                  .font(DS.Typography.caption.weight(.semibold))
                  .foregroundStyle(DS.Palette.subtext(scheme))
              }
            }
            .padding(.horizontal, DS.Spacing.xl)

            if joined.isEmpty && discover.isEmpty && privateLobbies.isEmpty {
              publicEmptyState
                .padding(.horizontal, DS.Spacing.xl)
            } else {
              if !joined.isEmpty {
                Text("Joined")
                  .dsSectionHeader()
                ForEach(sortedPublic(joined)) { game in
                  PublicGameCard(game: game, variant: .joined) {
                    selectedPublicGameID = game.id
                  }
                  .padding(.horizontal, DS.Spacing.xl)
                }
              }

              if !discover.isEmpty {
                Text("Discover")
                  .dsSectionHeader()
                ForEach(sortedPublic(discover).filter { $0.status == .open }) { game in
                  PublicGameCard(game: game, variant: .discover) {
                    selectedPublicGameID = game.id
                  }
                  .padding(.horizontal, DS.Spacing.xl)
                }
              }

              if !privateLobbies.isEmpty {
                Text("Private lobbies")
                  .dsSectionHeader()
                ForEach(privateLobbies.sorted { $0.createdAt > $1.createdAt }) { game in
                  PublicGameCard(game: game, variant: .privateLobby) {
                    selectedPublicGameID = game.id
                  }
                  .padding(.horizontal, DS.Spacing.xl)
                }
              }
            }
          }

          Spacer(minLength: DS.Spacing.xxl)
        }
        .padding(.bottom, DS.Spacing.xxl)
      }
      .dsScreenBackground()
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showCreatePublicGame = true
          } label: {
            Image(systemName: "plus")
              .foregroundStyle(DS.Palette.accent)
          }
          .accessibilityLabel("Create public game")
        }
      }
      .sheet(isPresented: $showCreatePublicGame) {
        CreatePublicGameSheet(store: store)
      }
      .sheet(item: Binding(
        get: { selectedPublicGameID.map { IdentifiedID(id: $0) } },
        set: { selectedPublicGameID = $0?.id }
      )) { item in
        PublicGameDetailSheet(store: store, gameID: item.id)
      }
      .sheet(item: Binding(
        get: { selectedActiveGameID.map { IdentifiedID(id: $0) } },
        set: { selectedActiveGameID = $0?.id }
      )) { item in
        ActiveGameDetailSheet(store: store, gameID: item.id)
      }
      .onAppear {
        SystemEventsService(store: store).sync()
        seedPublicGamesIfNeeded()
        ActiveGamesService(store: store).tick()
      }
    }
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
      Text("No competitions yet")
        .font(DS.Typography.section)
      Text("Start a competition from an invite or a clan battle.")
        .font(DS.Typography.body)
        .foregroundStyle(DS.Palette.subtext(scheme))
    }
    .dsCard()
  }

  private var publicEmptyState: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
      Text("No public games available")
        .font(DS.Typography.section)
      Text("Create one and let others join.")
        .font(DS.Typography.body)
        .foregroundStyle(DS.Palette.subtext(scheme))
    }
    .dsCard()
  }

  private var competitionCards: [CompetitionCard] {
    // UI adapter: treat accepted invites and clan battles as “competitions”.
    var cards: [CompetitionCard] = []

    for invite in store.invites where invite.status == .accepted {
      let leader = invite.from.displayName
      cards.append(
        CompetitionCard(
          id: "invite:\(invite.id)",
          name: invite.title,
          metric: invite.settings.scoringSummary,
          leaderName: leader,
          yourRank: 2,
          isLeaderYou: false
        )
      )
    }

    for battle in store.clanBattles {
      let leaderClan = battle.clanAScore >= battle.clanBScore ? battle.clanAName : battle.clanBName
      cards.append(
        CompetitionCard(
          id: "clan:\(battle.id)",
          name: battle.title,
          metric: battle.settings.scoringSummary,
          leaderName: leaderClan,
          yourRank: 1,
          isLeaderYou: false
        )
      )
    }

    return cards
  }

  private func seedPublicGamesIfNeeded() {
    // Local prototype: seed a couple of public lobbies for browsing if empty (non-system).
    if store.publicGames.contains(where: { $0.visibility == .public }) { return }
    guard let me = store.profile?.asPublicUser() else { return }

    let other = PublicUser(id: "u_public_host", displayName: "Sam", handle: "samfit", visibility: .public)

    store.publicGames.insert(contentsOf: [
      PublicGame(
        id: "pg_1",
        title: "Weekend Steps Open",
        createdAt: .now,
        createdBy: other,
        visibility: .public,
        isPinned: false,
        isUnlimitedPlayers: false,
        settings: {
          var s = GameSettings.default(mode: .groupFriends)
          s.scoringMetrics = [.steps, .activeEnergyBurned]
          return s
        }(),
        status: .open,
        maxPlayers: 10,
        players: [PublicGamePlayer(user: other, joinedAt: .now)]
      ),
      PublicGame(
        id: "pg_2",
        title: "Cycling Distance Sprint",
        createdAt: .now,
        createdBy: me,
        visibility: .public,
        isPinned: false,
        isUnlimitedPlayers: false,
        settings: {
          var s = GameSettings.default(mode: .groupFriends)
          s.activity = .cycling
          s.scoringMetrics = [.activeEnergyBurned, .sleepScore]
          s.timeLimitDays = 3
          return s
        }(),
        status: .open,
        maxPlayers: 6,
        players: [PublicGamePlayer(user: me, joinedAt: .now)]
      ),
    ], at: 0)
    store.saveAll()
  }

  private func sortedPublic(_ games: [PublicGame]) -> [PublicGame] {
    switch browseSort {
    case .newest:
      return games.sorted { $0.createdAt > $1.createdAt }
    case .playersHighToLow:
      return games.sorted { $0.players.count > $1.players.count }
    case .timeLimitShortToLong:
      return games.sorted { $0.settings.timeLimitDays < $1.settings.timeLimitDays }
    case .titleAZ:
      return games.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
  }
}

private enum BrowseSort: String, CaseIterable, Identifiable {
  case newest
  case playersHighToLow
  case timeLimitShortToLong
  case titleAZ

  var id: String { rawValue }

  var title: String {
    switch self {
    case .newest: "Newest"
    case .playersHighToLow: "Most players"
    case .timeLimitShortToLong: "Shortest duration"
    case .titleAZ: "Title A–Z"
    }
  }
}

private struct CompetitionCard: Identifiable, Hashable {
  let id: String
  let name: String
  let metric: String
  let leaderName: String
  let yourRank: Int
  let isLeaderYou: Bool
}

private struct CompetitionCardView: View {
  @Environment(\.colorScheme) private var scheme
  let card: CompetitionCard

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
      Text(card.name)
        .font(DS.Typography.section)

      Text(card.metric)
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Palette.subtext(scheme))

      Divider()
        .overlay(DS.Palette.separator(scheme))

      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Leader")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
          Text(card.leaderName)
            .font(DS.Typography.body.weight(.semibold))
            .foregroundStyle(DS.Palette.accent)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          Text("Your rank")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
          Text("#\(card.yourRank)")
            .font(DS.Typography.stat)
            .foregroundStyle(DS.Palette.text(scheme))
            .monospacedDigit()
            .contentTransition(.numericText())
        }
      }
    }
    .dsCard()
  }
}

private struct PublicGameCard: View {
  @Environment(\.colorScheme) private var scheme
  let game: PublicGame
  let variant: Variant
  let tapped: () -> Void

  var body: some View {
    Button(action: tapped) {
      VStack(alignment: .leading, spacing: DS.Spacing.s) {
        HStack {
          Text(game.title)
            .font(DS.Typography.section)
            .foregroundStyle(DS.Palette.text(scheme))
          Spacer()
          Text(playerCountText(game))
            .font(DS.Typography.caption.weight(.semibold))
            .foregroundStyle(DS.Palette.subtext(scheme))
            .monospacedDigit()
        }

        Text("\(game.settings.activity.title) • \(game.settings.timeLimitDays)d • \(game.settings.winCondition.title)")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))
          .lineLimit(2)

        HStack {
          Text("Score: \(game.settings.scoringSummary)")
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Palette.subtext(scheme))
          Spacer()
          Text(footerText)
            .font(DS.Typography.caption.weight(.semibold))
            .foregroundStyle(footerColor)
        }
      }
      .dsCard()
      .overlay(
        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
          .fill(overlayColor)
      )
    }
    .buttonStyle(.plain)
  }

  private var footerText: String {
    switch variant {
    case .systemEvent:
      return "Pinned event"
    case .joined:
      return "Joined"
    case .discover:
      return "Host: \(game.createdBy.displayName)"
    case .privateLobby:
      return "Private"
    }
  }

  private var footerColor: Color {
    switch variant {
    case .systemEvent:
      return DS.Palette.accent
    case .joined:
      return DS.Palette.accent
    case .discover:
      return DS.Palette.subtext(scheme)
    case .privateLobby:
      return DS.Palette.subtext(scheme)
    }
  }

  private var overlayColor: Color {
    switch variant {
    case .systemEvent:
      return DS.Palette.accent.opacity(0.06)
    case .joined:
      return DS.Palette.accent.opacity(0.04)
    case .discover:
      return DS.Palette.surface(scheme).opacity(0)
    case .privateLobby:
      return DS.Palette.separator(scheme).opacity(0.06)
    }
  }

  private func playerCountText(_ game: PublicGame) -> String {
    if game.isUnlimitedPlayers { return "\(game.players.count)/∞" }
    return "\(game.players.count)/\(game.maxPlayers)"
  }

  enum Variant: String {
    case systemEvent
    case joined
    case discover
    case privateLobby
  }
}

private struct PublicGameDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  let gameID: String

  private var game: PublicGame? {
    store.publicGames.first(where: { $0.id == gameID })
  }

  private func isEligible(profile: UserProfile, game: PublicGame) -> Bool {
    if game.visibility == .systemEvent { return true }
    switch game.settings.opponentPolicy {
    case .anyone:
      return true
    case .trackerOnly:
      return profile.hasFitnessTracker
    case .noTrackerOnly:
      return !profile.hasFitnessTracker
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
          if let game {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
              Text(game.title)
                .font(DS.Typography.title)

              Text("\(game.settings.activity.title) • \(game.settings.timeLimitDays)d • \(game.settings.winCondition.title) • Score: \(game.settings.scoringSummary)")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Palette.subtext(scheme))
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
              Text("Players")
                .font(DS.Typography.section)
              Text(game.isUnlimitedPlayers ? "\(game.players.count) of ∞" : "\(game.players.count) of \(game.maxPlayers)")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Palette.subtext(scheme))
                .monospacedDigit()

              ForEach(game.players) { p in
                HStack {
                  Text(p.user.displayName)
                    .font(DS.Typography.body.weight(.semibold))
                  Spacer()
                  Text("@\(p.user.handle)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Palette.subtext(scheme))
                }
                if p.id != game.players.last?.id {
                  Divider().overlay(DS.Palette.separator(scheme))
                }
              }
            }
            .dsCard()
            .padding(.horizontal, DS.Spacing.xl)

            let meID = store.profile?.id
            let isIn = meID.map { game.contains(userID: $0) } ?? false
            let isOwner = (store.profile?.id == game.createdBy.id)
            let canStartNow = (game.visibility != .systemEvent) && isOwner && game.status == .open && game.players.count >= 2
            let eligible = store.profile.map { isEligible(profile: $0, game: game) } ?? true

            if canStartNow {
              Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                  PublicGamesService(store: store).startNow(gameID: game.id)
                }
              } label: {
                Text("Start now")
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, DS.Spacing.m)
              }
              .buttonStyle(.borderedProminent)
              .tint(DS.Palette.accent)
              .padding(.horizontal, DS.Spacing.xl)
            }

            Button {
              withAnimation(.easeInOut(duration: 0.25)) {
                let svc = PublicGamesService(store: store)
                if isIn {
                  svc.leave(gameID: game.id)
                } else {
                  svc.join(gameID: game.id)
                }
              }
            } label: {
              Text(isIn ? "Leave game" : "Join game")
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Palette.accent)
            .disabled((game.visibility == .systemEvent ? game.status == .finished : game.status != .open) || (!isIn && game.isFull) || (!isIn && !eligible))
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.s)

            if !eligible && !isIn, let profile = store.profile {
              Text(disabledReason(profile: profile, game: game))
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Palette.subtext(scheme))
                .padding(.horizontal, DS.Spacing.xl)
            }
          }

          Spacer(minLength: DS.Spacing.xxl)
        }
        .padding(.bottom, DS.Spacing.xxl)
      }
      .dsScreenBackground()
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
      }
    }
  }

  private func disabledReason(profile: UserProfile, game: PublicGame) -> String {
    switch game.settings.opponentPolicy {
    case .anyone:
      return ""
    case .trackerOnly:
      return "This game is set to tracker users only. Enable “Fitness tracker” in your Profile to join."
    case .noTrackerOnly:
      return "This game is set to no-tracker users only. Disable “Fitness tracker” in your Profile to join."
    }
  }
}

private struct CreatePublicGameSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  @State private var title: String = "Open Steps Challenge"
  @State private var maxPlayers: Int = 10
  @State private var settings: GameSettings = .default(mode: .groupFriends)
  @State private var visibility: PublicGameVisibility = .public

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
          Text("Create public game")
            .font(DS.Typography.title)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)

          VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Details")
              .font(DS.Typography.section)

            TextField("Game title", text: $title)
              .textInputAutocapitalization(.words)
              .padding(DS.Spacing.l)
              .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                  .fill(DS.Palette.surface(scheme))
              )
              .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                  .stroke(DS.Palette.separator(scheme), lineWidth: 1)
              )

            Stepper(value: $maxPlayers, in: 2...playerCap(settings)) {
              HStack {
                Text("Max players")
                  .font(DS.Typography.body)
                Spacer()
                Text("\(maxPlayers)")
                  .font(DS.Typography.body)
                  .foregroundStyle(DS.Palette.subtext(scheme))
                  .monospacedDigit()
              }
            }

            Picker("Visibility", selection: $visibility) {
              Text("Public").tag(PublicGameVisibility.public)
              Text("Private (friends)").tag(PublicGameVisibility.private)
            }
            .pickerStyle(.segmented)
            .tint(DS.Palette.accent)

            if settings.winCondition == .eliminationLastManStanding {
              Text("Elimination games support up to 12 players. Bottom player is removed every 24h until one remains.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Palette.subtext(scheme))
            }
          }
          .dsCard()
          .padding(.horizontal, DS.Spacing.xl)

          // Reuse existing settings UI
          VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Settings")
              .font(DS.Typography.section)
          }
          .padding(.horizontal, DS.Spacing.xl)

          VStack(spacing: 0) {
            GameSettingsForm(settings: $settings, availableModes: [.groupFriends], inventory: store.profile?.inventory)
          }
          .dsCard()
          .padding(.horizontal, DS.Spacing.xl)

          Button {
            PublicGamesService(store: store).createPublicGame(title: title, settings: settings, maxPlayers: maxPlayers, visibility: visibility)
            dismiss()
          } label: {
            Text("Publish game")
              .frame(maxWidth: .infinity)
              .padding(.vertical, DS.Spacing.m)
          }
          .buttonStyle(.borderedProminent)
          .tint(DS.Palette.accent)
          .padding(.horizontal, DS.Spacing.xl)
          .padding(.top, DS.Spacing.s)
        }
        .padding(.bottom, DS.Spacing.xxl)
      }
      .dsScreenBackground()
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
      }
    }
  }

  private func playerCap(_ settings: GameSettings) -> Int {
    settings.winCondition == .eliminationLastManStanding ? 12 : 50
  }
}

#Preview("Competitions") {
  let store = AppStore(kv: InMemoryStore())
  store.account = Account(userID: "preview@example.com", email: "preview@example.com", username: "preview", createdAt: .now)
  store.profile = UserProfile(
    id: "preview",
    displayName: "Preview",
    handle: "preview",
    age: 28,
    gender: .preferNotToSay,
    fitnessLevel: .intermediate,
    visibility: .public,
    hasFitnessTracker: true,
    fitnessElo: 1750,
    fitnessEloUpdatedAt: .now,
    inventory: .empty,
    createdAt: .now,
    updatedAt: .now
  )
  let settings = GameSettings.default(mode: .oneOnOne)
  store.invites = [
    GameInvite(
      id: "i1",
      from: PublicUser(id: "u1", displayName: "Alex", handle: "alex", visibility: .public),
      to: PublicUser(id: "preview", displayName: "Preview", handle: "preview", visibility: .public),
      title: "7-day Steps Battle",
      settings: settings,
      groupID: nil,
      createdAt: .now,
      status: .accepted
    )
  ]
  store.clanBattles = [
    ClanBattle(
      id: "b1",
      title: "Clan Showdown",
      createdAt: .now,
      status: .active,
      settings: GameSettings.default(mode: .clanVsClan),
      clanAID: "a",
      clanAName: "Green Wolves",
      clanATag: "WOLF",
      clanBID: "b",
      clanBName: "Night Owls",
      clanBTag: "OWL",
      clanAScore: 120_000,
      clanBScore: 110_000
    )
  ]
  return CompetitionsView(store: store)
}

