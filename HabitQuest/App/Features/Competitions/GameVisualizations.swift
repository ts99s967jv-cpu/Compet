import SwiftUI

enum ActiveGamePrimaryView: String, CaseIterable, Identifiable {
  case map
  case leaderboard

  var id: String { rawValue }

  var title: String {
    switch self {
    case .map: "Map"
    case .leaderboard: "Leaderboard"
    }
  }
}

/// Small preview used in game setup UI.
struct GameMapStylePreview: View {
  let style: GameMapStyle
  let activity: GameActivity

  var body: some View {
    let resolved = style.resolved(for: activity)
    GameMapTrack(
      style: resolved,
      checkpoints: [
        GameCheckpoint(id: "c1", progress: 0.25, label: "25%"),
        GameCheckpoint(id: "c2", progress: 0.5, label: "50%"),
        GameCheckpoint(id: "c3", progress: 0.75, label: "75%"),
      ],
      players: [
        GameMapPlayer(id: "p1", displayName: "You", progress: 0.42, isMe: true),
        GameMapPlayer(id: "p2", displayName: "Alex", progress: 0.68, isMe: false),
      ]
    )
    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
    )
  }
}

/// Illustrated “track” with player bubbles positioned by score.
struct GameMapTrackCard: View {
  @Environment(\.colorScheme) private var scheme

  let title: String
  let subtitle: String
  let style: GameMapStyle
  let checkpoints: [GameCheckpoint]
  let players: [GameMapPlayer]

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(DS.Typography.title)
        Text(subtitle)
          .font(DS.Typography.body)
          .foregroundStyle(DS.Palette.subtext(scheme))
      }

      GameMapTrack(
        style: style,
        checkpoints: checkpoints,
        players: players
      )
      .frame(height: 260)
      .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
    }
    .dsCard()
  }
}

struct GameCheckpoint: Identifiable, Hashable {
  let id: String
  let progress: Double // 0...1 along the path
  let label: String
}

struct GameMapPlayer: Identifiable, Hashable {
  let id: String
  let displayName: String
  let progress: Double // 0...1 along the path
  let isMe: Bool
}

private struct GameMapTrack: View {
  @Environment(\.colorScheme) private var scheme

  let style: GameMapStyle
  let checkpoints: [GameCheckpoint]
  let players: [GameMapPlayer]

  var body: some View {
    GeometryReader { geo in
      let rect = geo.frame(in: .local)
      let resolved = style
      let path = pathPolyline(in: rect, style: resolved)

      ZStack {
        background(for: resolved)

        Canvas { ctx, size in
          // Track
          drawTrack(in: &ctx, size: size, style: resolved, polyline: path)
          // Checkpoints
          for cp in checkpoints {
            let p = pointOnPolyline(path, t: cp.progress)
            drawCheckpoint(in: &ctx, at: p, style: resolved)
          }
        }

        // Checkpoint labels
        ForEach(checkpoints) { cp in
          let p = pointOnPolyline(path, t: cp.progress)
          Text(cp.label)
            .font(DS.Typography.caption.weight(.semibold))
            .foregroundStyle(DS.Palette.subtext(scheme))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
              Capsule(style: .continuous)
                .fill(DS.Palette.surface(scheme).opacity(0.92))
            )
            .overlay(
              Capsule(style: .continuous)
                .stroke(DS.Palette.separator(scheme).opacity(0.55), lineWidth: 1)
            )
            .position(x: clamp(p.x + 42, 18, rect.width - 18), y: clamp(p.y - 18, 18, rect.height - 18))
        }

        // Player bubbles
        ForEach(players) { pl in
          let p = pointOnPolyline(path, t: pl.progress)
          PlayerBubble(name: pl.displayName, isMe: pl.isMe)
            .position(x: clamp(p.x, 22, rect.width - 22), y: clamp(p.y, 18, rect.height - 18))
        }
      }
    }
  }

  private func background(for style: GameMapStyle) -> some View {
    switch style {
    case .grassyTrail:
      return AnyView(
        LinearGradient(
          colors: [
            DS.Palette.accent.opacity(scheme == .dark ? 0.18 : 0.12),
            DS.Palette.surface(scheme).opacity(0.92),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    case .road:
      return AnyView(
        LinearGradient(
          colors: [
            DS.Palette.surface(scheme),
            DS.Palette.surface(scheme).opacity(0.80),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    case .pool:
      return AnyView(
        LinearGradient(
          colors: [
            Color(red: 0.20, green: 0.62, blue: 0.92).opacity(scheme == .dark ? 0.25 : 0.18),
            DS.Palette.surface(scheme).opacity(0.90),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    case .generic, .automatic:
      return AnyView(
        LinearGradient(
          colors: [
            DS.Palette.surface(scheme),
            DS.Palette.surface(scheme).opacity(0.86),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }
  }

  private func pathPolyline(in rect: CGRect, style: GameMapStyle) -> [CGPoint] {
    let pad: CGFloat = 18
    let minX = rect.minX + pad
    let maxX = rect.maxX - pad
    let minY = rect.minY + pad
    let maxY = rect.maxY - pad

    switch style {
    case .pool:
      // A gentle vertical lane.
      return [
        CGPoint(x: rect.midX, y: maxY),
        CGPoint(x: rect.midX, y: minY),
      ]
    case .road:
      // Long sweeping road.
      return [
        CGPoint(x: minX, y: maxY - 10),
        CGPoint(x: maxX - 10, y: maxY * 0.70),
        CGPoint(x: minX + 25, y: maxY * 0.42),
        CGPoint(x: maxX, y: minY + 12),
      ]
    case .grassyTrail:
      // Zigzag trail.
      return [
        CGPoint(x: minX, y: maxY),
        CGPoint(x: maxX, y: maxY * 0.80),
        CGPoint(x: minX + 16, y: maxY * 0.62),
        CGPoint(x: maxX - 18, y: maxY * 0.42),
        CGPoint(x: minX + 8, y: maxY * 0.24),
        CGPoint(x: maxX, y: minY),
      ]
    case .generic, .automatic:
      return [
        CGPoint(x: minX, y: maxY),
        CGPoint(x: maxX * 0.84, y: maxY * 0.72),
        CGPoint(x: minX + 14, y: maxY * 0.48),
        CGPoint(x: maxX, y: minY),
      ]
    }
  }

  private func drawTrack(in ctx: inout GraphicsContext, size: CGSize, style: GameMapStyle, polyline: [CGPoint]) {
    guard polyline.count >= 2 else { return }
    var p = Path()
    p.move(to: polyline[0])
    for pt in polyline.dropFirst() { p.addLine(to: pt) }

    switch style {
    case .grassyTrail:
      ctx.stroke(p, with: .color(Color(red: 0.92, green: 0.90, blue: 0.84).opacity(scheme == .dark ? 0.50 : 0.95)), style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))
      ctx.stroke(p, with: .color(DS.Palette.separator(scheme).opacity(0.25)), style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
    case .road:
      let road = Color(red: 0.40, green: 0.42, blue: 0.46).opacity(scheme == .dark ? 0.55 : 0.40)
      ctx.stroke(p, with: .color(road), style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
      // Center dashed line.
      ctx.stroke(p, with: .color(Color.white.opacity(scheme == .dark ? 0.45 : 0.70)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [10, 10]))
    case .pool:
      let lane = Color(red: 0.16, green: 0.56, blue: 0.86).opacity(scheme == .dark ? 0.55 : 0.40)
      ctx.stroke(p, with: .color(lane), style: StrokeStyle(lineWidth: 26, lineCap: .round))
      ctx.stroke(p, with: .color(Color.white.opacity(scheme == .dark ? 0.35 : 0.55)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 8]))
    case .generic, .automatic:
      ctx.stroke(p, with: .color(DS.Palette.separator(scheme).opacity(0.70)), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [4, 8]))
    }
  }

  private func drawCheckpoint(in ctx: inout GraphicsContext, at point: CGPoint, style: GameMapStyle) {
    let ring = Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14))
    ctx.fill(ring, with: .color(DS.Palette.surface(scheme).opacity(0.96)))
    ctx.stroke(ring, with: .color(DS.Palette.accent.opacity(0.65)), lineWidth: 2)
  }
}

private struct PlayerBubble: View {
  @Environment(\.colorScheme) private var scheme
  let name: String
  let isMe: Bool

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(isMe ? DS.Palette.accent : DS.Palette.text(scheme).opacity(0.18))
        .frame(width: 16, height: 16)
        .overlay(
          Circle()
            .stroke(DS.Palette.surface(scheme).opacity(0.9), lineWidth: 2)
        )
      Text(name)
        .font(DS.Typography.caption.weight(.semibold))
        .foregroundStyle(DS.Palette.text(scheme))
        .lineLimit(1)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
      Capsule(style: .continuous)
        .fill(DS.Palette.surface(scheme).opacity(0.94))
    )
    .overlay(
      Capsule(style: .continuous)
        .stroke(isMe ? DS.Palette.accent.opacity(0.60) : DS.Palette.separator(scheme).opacity(0.60), lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(scheme == .dark ? 0.25 : 0.12), radius: 10, x: 0, y: 6)
  }
}

// MARK: - Tower (Level vs Level)

struct LevelVsLevelTowerCard: View {
  @Environment(\.colorScheme) private var scheme

  let title: String
  let subtitle: String
  let turnIndex: Int
  let currentTarget: Int
  let lastAchievedScore: Int?
  let players: [TowerPlayer]

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.s) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(DS.Typography.title)
        Text(subtitle)
          .font(DS.Typography.body)
          .foregroundStyle(DS.Palette.subtext(scheme))
      }

      LevelTower(
        turnIndex: turnIndex,
        currentTarget: currentTarget,
        lastAchievedScore: lastAchievedScore,
        players: players
      )
      .frame(height: 280)
      .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
    }
    .dsCard()
  }
}

struct TowerPlayer: Identifiable, Hashable {
  let id: String
  let displayName: String
  let score: Int
  let isMe: Bool
  let isActiveTurn: Bool
}

private struct LevelTower: View {
  @Environment(\.colorScheme) private var scheme

  let turnIndex: Int
  let currentTarget: Int
  let lastAchievedScore: Int?
  let players: [TowerPlayer]

  var body: some View {
    GeometryReader { geo in
      let rect = geo.frame(in: .local)
      let levels = max(1, turnIndex + 1)

      ZStack(alignment: .bottom) {
        LinearGradient(
          colors: [
            DS.Palette.accent.opacity(scheme == .dark ? 0.18 : 0.12),
            DS.Palette.surface(scheme).opacity(0.92),
          ],
          startPoint: .top,
          endPoint: .bottom
        )

        // Tower blocks (grows with each turn)
        VStack(spacing: 6) {
          ForEach((0..<levels).reversed(), id: \.self) { idx in
            let isCurrent = idx == turnIndex
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(isCurrent ? DS.Palette.accent.opacity(0.22) : DS.Palette.separator(scheme).opacity(0.18))
              .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .stroke(isCurrent ? DS.Palette.accent.opacity(0.55) : DS.Palette.separator(scheme).opacity(0.40), lineWidth: 1)
              )
              .frame(height: blockHeight(totalHeight: rect.height, levels: levels))
              .padding(.horizontal, 30 + CGFloat(idx) * 4)
          }
        }
        .padding(.vertical, 14)

        // Target label
        VStack(spacing: 6) {
          Text("Target \(currentTarget)")
            .font(DS.Typography.caption.weight(.semibold))
            .foregroundStyle(DS.Palette.text(scheme))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
              Capsule(style: .continuous).fill(DS.Palette.surface(scheme).opacity(0.94))
            )
            .overlay(
              Capsule(style: .continuous).stroke(DS.Palette.accent.opacity(0.55), lineWidth: 1)
            )

          if let lastAchievedScore {
            Text("Previous \(lastAchievedScore)")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Palette.subtext(scheme))
          }
        }
        .position(x: rect.midX, y: 24)

        // Player bubbles placed “up” the current level by score vs target.
        ForEach(players) { p in
          let t = currentTarget > 0 ? min(1.0, max(0.0, Double(p.score) / Double(currentTarget))) : 0
          let y = rect.maxY - CGFloat(t) * (rect.height - 54)
          PlayerBubble(name: p.displayName, isMe: p.isMe)
            .overlay(alignment: .topTrailing) {
              if p.isActiveTurn {
                Circle()
                  .fill(DS.Palette.accent)
                  .frame(width: 8, height: 8)
                  .offset(x: 6, y: -6)
              }
            }
            .position(x: p.isMe ? rect.midX - 58 : rect.midX + 58, y: clamp(y, 28, rect.maxY - 24))
        }
      }
    }
  }

  private func blockHeight(totalHeight: CGFloat, levels: Int) -> CGFloat {
    let usable = max(120, totalHeight - 32)
    return max(26, min(48, usable / CGFloat(levels)))
  }
}

// MARK: - Geometry helpers

private func clamp<T: Comparable>(_ x: T, _ lo: T, _ hi: T) -> T {
  min(hi, max(lo, x))
}

private func pointOnPolyline(_ pts: [CGPoint], t: Double) -> CGPoint {
  guard pts.count >= 2 else { return pts.first ?? .zero }
  let tt = max(0, min(1, t))
  let segs = zip(pts, pts.dropFirst()).map { ($0, $1) }
  let lengths = segs.map { hypot($0.1.x - $0.0.x, $0.1.y - $0.0.y) }
  let total = max(0.0001, lengths.reduce(0, +))
  var dist = CGFloat(tt) * total

  for (i, seg) in segs.enumerated() {
    let len = lengths[i]
    if dist <= len || i == segs.count - 1 {
      let u = len > 0 ? dist / len : 0
      return CGPoint(
        x: seg.0.x + (seg.1.x - seg.0.x) * u,
        y: seg.0.y + (seg.1.y - seg.0.y) * u
      )
    }
    dist -= len
  }
  return pts.last ?? .zero
}

