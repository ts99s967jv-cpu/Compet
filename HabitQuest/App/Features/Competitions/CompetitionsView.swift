import SwiftUI

struct CompetitionsView: View {
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  @State private var showCreatePublicGame: Bool = false
  @State private var selectedPublicGameID: String?
  @State private var selectedActiveGameID: String?

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

          Text("Active")
            .dsSectionHeader()

          VStack(spacing: DS.Spacing.m) {
            let comps = competitionCards
            let activeGames = store.activeGames
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

          Text("Public games")
            .dsSectionHeader()

          VStack(spacing: DS.Spacing.m) {
            if store.publicGames.isEmpty {
              publicEmptyState
                .padding(.horizontal, DS.Spacing.xl)
            } else {
              ForEach(store.publicGames.filter { $0.status == .open }) { game in
                PublicGameCard(game: game) {
                  selectedPublicGameID = game.id
                }
                .padding(.horizontal, DS.Spacing.xl)
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
    // Local prototype: seed a couple of public lobbies for browsing if empty.
    guard store.publicGames.isEmpty else { return }
    guard let me = store.profile?.asPublicUser() else { return }

    let other = PublicUser(id: "u_public_host", displayName: "Sam", handle: "samfit", visibility: .public)

    store.publicGames = [
      PublicGame(
        id: "pg_1",
        title: "Weekend Steps Open",
        createdAt: .now,
        createdBy: other,
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
    ]
    store.saveAll()
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

private struct IdentifiedID: Identifiable, Hashable {
  let id: String
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
  let tapped: () -> Void

  var body: some View {
    Button(action: tapped) {
      VStack(alignment: .leading, spacing: DS.Spacing.s) {
        HStack {
          Text(game.title)
            .font(DS.Typography.section)
            .foregroundStyle(DS.Palette.text(scheme))
          Spacer()
          Text("\(game.players.count)/\(game.maxPlayers)")
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
          Text("Host: \(game.createdBy.displayName)")
            .font(DS.Typography.caption.weight(.semibold))
            .foregroundStyle(DS.Palette.subtext(scheme))
        }
      }
      .dsCard()
    }
    .buttonStyle(.plain)
  }
}

private struct ActiveGameCard: View {
  @Environment(\.colorScheme) private var scheme
  let game: ActiveGame
  let tapped: () -> Void

  var body: some View {
    Button(action: tapped) {
      VStack(alignment: .leading, spacing: DS.Spacing.s) {
        HStack {
          Text(game.title)
            .font(DS.Typography.section)
            .foregroundStyle(DS.Palette.text(scheme))
          Spacer()
          Text(game.status == .active ? "Active" : "Finished")
            .font(DS.Typography.caption.weight(.semibold))
            .foregroundStyle(game.status == .active ? DS.Palette.accent : DS.Palette.subtext(scheme))
        }

        Text("\(game.settings.activity.title) • \(game.settings.winCondition.title)")
          .font(DS.Typography.caption)
          .foregroundStyle(DS.Palette.subtext(scheme))
          .lineLimit(2)

        if game.settings.winCondition == .eliminationLastManStanding, let elim = game.elimination {
          HStack {
            Text("Players: \(remainingCount(game, elim))")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Palette.subtext(scheme))
              .monospacedDigit()
            Spacer()
            Text("Round \(elim.roundIndex + 1)")
              .font(DS.Typography.caption.weight(.semibold))
              .foregroundStyle(DS.Palette.subtext(scheme))
              .monospacedDigit()
          }
        }
      }
      .dsCard()
    }
    .buttonStyle(.plain)
  }

  private func remainingCount(_ game: ActiveGame, _ elim: EliminationState) -> Int {
    game.players.filter { !elim.eliminatedUserIDs.contains($0.id) }.count
  }
}

private struct ActiveGameDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  let gameID: String

  private var game: ActiveGame? { store.activeGames.first(where: { $0.id == gameID }) }
  @State private var myHealthPoints: Double?
  @State private var healthStatusText: String?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
          if let game, let elim = game.elimination, game.settings.winCondition == .eliminationLastManStanding {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
              Text(game.title)
                .font(DS.Typography.title)
              Text("Elimination • Bottom player removed every 24h • Up to 12 players")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Palette.subtext(scheme))
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.l)

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
              Text("Current round")
                .font(DS.Typography.section)
              Text("Round \(elim.roundIndex + 1)")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Palette.subtext(scheme))

              let cutoff = Calendar.current.date(byAdding: .hour, value: elim.roundLengthHours, to: elim.roundStartedAt) ?? .now
              Text("Next elimination: \(cutoff.formatted(date: .abbreviated, time: .shortened))")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Palette.subtext(scheme))
            }
            .dsCard()
            .padding(.horizontal, DS.Spacing.xl)

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
              Text("Leaderboard")
                .font(DS.Typography.section)

              let svc = ActiveGamesService(store: store)
              let remaining = game.players.filter { !elim.eliminatedUserIDs.contains($0.id) }
              let rows = remaining
                .map { ($0, svc.pointsFor(userID: $0.id, roundIndex: elim.roundIndex, seed: elim.roundStartedAt)) }
                .sorted { $0.1 > $1.1 }

              ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack {
                  Text("#\(idx + 1)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Palette.subtext(scheme))
                    .frame(width: 28, alignment: .leading)
                    .monospacedDigit()
                  Text(row.0.displayName)
                    .font(DS.Typography.body.weight(.semibold))
                  Spacer()
                  if let meID = store.profile?.id, row.0.id == meID, let myHealthPoints {
                    Text("\(Int(myHealthPoints.rounded()))")
                      .font(DS.Typography.body.weight(.semibold))
                      .monospacedDigit()
                  } else {
                    Text("\(row.1)")
                      .font(DS.Typography.body.weight(.semibold))
                      .monospacedDigit()
                  }
                }
                if idx != rows.count - 1 {
                  Divider().overlay(DS.Palette.separator(scheme))
                }
              }

              Text(healthStatusText ?? "Your points use Apple Health: \(game.settings.scoringSummary). (Others are placeholder until scores sync.)")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Palette.subtext(scheme))
            }
            .dsCard()
            .padding(.horizontal, DS.Spacing.xl)

            if !elim.eliminatedUserIDs.isEmpty {
              VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Text("Eliminated")
                  .font(DS.Typography.section)
                ForEach(elim.eliminatedUserIDs, id: \.self) { id in
                  Text(game.players.first(where: { $0.id == id })?.displayName ?? "Unknown")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Palette.subtext(scheme))
                }
              }
              .dsCard()
              .padding(.horizontal, DS.Spacing.xl)
            }

            Button {
              withAnimation(.easeInOut(duration: 0.25)) {
                ActiveGamesService(store: store).simulateEndOfRound(gameID: gameID)
              }
            } label: {
              Text("Simulate 24h elimination (prototype)")
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Palette.accent)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.s)
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
    .task { await loadMyHealthPoints() }
  }

  private func loadMyHealthPoints() async {
    guard let game, let elim = game.elimination else { return }
    guard let meID = store.profile?.id else { return }
    guard game.players.contains(where: { $0.id == meID }) else { return }

    let hk = HealthKitScoringService()
    let start = elim.roundStartedAt
    let end = Date()

    do {
      try await hk.requestAuthorization(for: game.settings.scoringMetrics)
      let pts = try await hk.points(metrics: game.settings.scoringMetrics, start: start, end: end)
      myHealthPoints = pts
      healthStatusText = "Your points (Apple Health): \(Int(pts.rounded())) • \(game.settings.scoringSummary)"
    } catch {
      healthStatusText = "Apple Health points unavailable (enable Health permissions)."
    }
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
              Text("\(game.players.count) of \(game.maxPlayers)")
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
            let canStartNow = isOwner && game.status == .open && game.players.count >= 2
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
            .disabled(game.status != .open || (!isIn && game.isFull) || (!isIn && !eligible))
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
            PublicGamesService(store: store).createPublicGame(title: title, settings: settings, maxPlayers: maxPlayers)
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
  store.account = Account(appleUserID: "preview", createdAt: .now)
  store.profile = UserProfile(
    id: "preview",
    displayName: "Preview",
    handle: "preview",
    age: 28,
    gender: .preferNotToSay,
    fitnessLevel: .intermediate,
    visibility: .public,
    hasFitnessTracker: true,
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

