import SwiftUI

struct CompetitionsView: View {
  @Bindable var store: AppStore
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DS.Spacing.l) {
        Text("Competitions")
          .font(DS.Typography.title)
          .padding(.horizontal, DS.Spacing.xl)
          .padding(.top, DS.Spacing.l)

        Text("Your active games and team battles.")
          .font(DS.Typography.body)
          .foregroundStyle(DS.Palette.subtext(scheme))
          .padding(.horizontal, DS.Spacing.xl)

        VStack(spacing: DS.Spacing.m) {
          let comps = competitionCards
          if comps.isEmpty {
            emptyState
              .padding(.horizontal, DS.Spacing.xl)
          } else {
            ForEach(comps) { card in
              CompetitionCardView(card: card)
                .padding(.horizontal, DS.Spacing.xl)
                .animation(.easeInOut(duration: 0.25), value: card.leaderName)
            }
          }
        }
        .padding(.top, DS.Spacing.s)
        .padding(.bottom, DS.Spacing.xxl)
      }
    }
    .dsScreenBackground()
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

  private var competitionCards: [CompetitionCard] {
    // UI adapter: treat accepted invites and clan battles as “competitions”.
    var cards: [CompetitionCard] = []

    for invite in store.invites where invite.status == .accepted {
      let leader = invite.from.displayName
      cards.append(
        CompetitionCard(
          id: "invite:\(invite.id)",
          name: invite.title,
          metric: invite.settings.activity.title,
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
          metric: battle.settings.activity.title,
          leaderName: leaderClan,
          yourRank: 1,
          isLeaderYou: false
        )
      )
    }

    return cards
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

