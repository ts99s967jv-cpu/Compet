import SwiftUI

/// Subtle WhatsApp-style doodle background using SF Symbols.
/// Designed to feel calm and “health-themed” without adding clutter.
struct DSFitnessDoodleBackground: View {
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    GeometryReader { geo in
      Canvas { context, size in
        let symbols = doodleSymbols
        guard !symbols.isEmpty else { return }

        // A gentle, soft palette.
        let base = DS.Palette.subtext(scheme).opacity(scheme == .dark ? 0.10 : 0.08)
        let accent = DS.Palette.accent.opacity(scheme == .dark ? 0.10 : 0.08)

        // Tiled grid with slight jitter.
        let step: CGFloat = 84
        let cols = Int((size.width / step).rounded(.up)) + 2
        let rows = Int((size.height / step).rounded(.up)) + 2

        for r in 0..<rows {
          for c in 0..<cols {
            let idx = abs(hash2(c, r)) % symbols.count
            let name = symbols[idx]

            // Deterministic jitter/rotation/scale.
            let jx = CGFloat(hash3(c, r, 1) % 21) - 10
            let jy = CGFloat(hash3(c, r, 2) % 21) - 10
            let rot = Angle(degrees: Double((hash3(c, r, 3) % 25) - 12))
            let s = CGFloat(0.70 + Double((hash3(c, r, 4) % 31)) / 100.0) // 0.70–1.00

            let x = CGFloat(c) * step + jx
            let y = CGFloat(r) * step + jy

            let color = (hash3(c, r, 5) % 3 == 0) ? accent : base
            context.opacity = 1
            let text = Text(Image(systemName: name))
              .font(.system(size: 28, weight: .regular))
              .symbolRenderingMode(.hierarchical)
              .foregroundStyle(color)
            context.draw(text, at: CGPoint(x: x, y: y), anchor: .center)

            // Add a smaller secondary doodle sometimes.
            if hash3(c, r, 6) % 4 == 0 {
              let idx2 = abs(hash3(c, r, 7)) % symbols.count
              let name2 = symbols[idx2]
              let x2 = x + CGFloat((hash3(c, r, 8) % 31) - 15)
              let y2 = y + CGFloat((hash3(c, r, 9) % 31) - 15)
              let text2 = Text(Image(systemName: name2))
                .font(.system(size: 18, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(base.opacity(0.9))
              context.draw(text2, at: CGPoint(x: x2, y: y2), anchor: .center)
            }

            // Apply transforms via a small group (rotation/scale).
            // Canvas doesn’t support per-draw transforms directly, so we approximate by drawing
            // a rotated/scaled symbol using an intermediate resolved image.
            // (Keep it cheap: only for a subset of tiles.)
            if (hash3(c, r, 10) % 5 == 0) && s != 1 {
              context.saveGState()
              context.translateBy(x: x, y: y)
              context.rotate(by: rot)
              context.scaleBy(x: s, y: s)
              context.translateBy(x: -x, y: -y)
              context.draw(text, at: CGPoint(x: x, y: y), anchor: .center)
              context.restoreGState()
            }
          }
        }
      }
      .drawingGroup()
      .ignoresSafeArea()
      .blendMode(scheme == .dark ? .plusLighter : .softLight)
      .opacity(0.75)
      .accessibilityHidden(true)
    }
    .ignoresSafeArea()
  }

  private var doodleSymbols: [String] {
    [
      "dumbbell",
      "figure.walk",
      "figure.run",
      "bicycle",
      "flame",
      "heart",
      "heart.fill",
      "bed.double",
      "drop",
      "waterbottle",
      "stopwatch",
      "crown",
      "trophy",
      "bolt.heart",
      "leaf",
      "figure.strengthtraining.traditional",
      "figure.yoga",
      "figure.mind.and.body",
      "cross.case",
    ]
  }

  private func hash2(_ a: Int, _ b: Int) -> Int {
    var x = a &* 374761393 &+ b &* 668265263
    x = (x ^ (x >> 13)) &* 1274126177
    return x ^ (x >> 16)
  }

  private func hash3(_ a: Int, _ b: Int, _ c: Int) -> Int {
    hash2(hash2(a, b), c)
  }
}

