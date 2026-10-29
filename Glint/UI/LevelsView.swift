import SwiftUI

/// The level map: three illustrated world tabs, ten sun medallions per world on a winding path, stars under each,
/// locks with "x more ★" on a closed world.
struct LevelsView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let canvas: AppCanvas

    var body: some View {
        let data = store.data
        let world = min(max(controller.levelsWorld, 1), LevelBook.worldCount)
        let c = canvas.compact
        let total = ProgressRules.totalStars(data)
        let open = ProgressRules.isWorldOpen(world, data)
        ZStack {
            MenuScrim(tint: GlintTheme.worldTint(world))
            // R2: on a Duo the header and tabs sit on the mirror half, the map on the garden half (off the crease).
            SplitMenu(canvas: canvas, scrolls: false, maxWidth: 980) {
                VStack(spacing: c ? 10 : 16) {
                    MenuHeader(title: "Levels", compact: c, trailing: AnyView(starTotal(total, compact: c))) {
                        controller.back()
                    }
                    worldTabs(selected: world, data: data, compact: c)
                    if canvas.isDuo {
                        WorldArt(world: world)
                            .frame(maxWidth: 260, maxHeight: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: 980)
            } bottom: {
                ZStack {
                    LevelMap(levels: Array(LevelBook.levels(inWorld: world)), data: data,
                             next: ProgressRules.nextLevel(data), tint: GlintTheme.worldTint(world),
                             reduceMotion: controller.reduceMotion) { n in
                        controller.playLevel(n)
                    }
                    .opacity(open ? 1 : 0.35)
                    .allowsHitTesting(open)
                    if !open {
                        WorldLockCard(world: world, missing: ProgressRules.starsMissing(toOpen: world, data),
                                      needed: ProgressRules.gate(world: world), compact: c)
                            .padding(.horizontal, 24)
                    }
                }
                .frame(maxWidth: 980, maxHeight: .infinity)
            }
        }
        .frame(width: canvas.size.width, height: canvas.size.height)
    }

    private func starTotal(_ total: Int, compact: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill").foregroundStyle(GlintTheme.gold)
            Text("\(total)")
                .foregroundStyle(GlintTheme.cream)
        }
        .font(GlintType.number(compact ? 17 : 20))
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Capsule().fill(GlintTheme.cardDeep.opacity(0.85)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(total) stars")
    }

    private func worldTabs(selected: Int, data: ProgressData, compact: Bool) -> some View {
        HStack(spacing: 10) {
            ForEach(1...LevelBook.worldCount, id: \.self) { w in
                let open = ProgressRules.isWorldOpen(w, data)
                let isSelected = w == selected
                Button {
                    controller.selectWorld(w)
                } label: {
                    // R2: two short lines ("Meadow" / "★ 24/30"), never truncated at 402 pt. The world art sits
                    // beside them only when there is room (not on a phone).
                    let status = AppRules.worldTabStatus(open: open, stars: ProgressRules.stars(data, world: w),
                                                         max: ProgressRules.maxStars(world: w),
                                                         gate: ProgressRules.gate(world: w))
                    HStack(spacing: 8) {
                        if !compact {
                            WorldArt(world: w)
                                .frame(width: 44, height: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        VStack(alignment: compact ? .center : .leading, spacing: 1) {
                            Text(LevelBook.worldName(w))
                                .font(GlintType.body(compact))
                                .foregroundStyle(isSelected ? GlintTheme.ink : GlintTheme.cream)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            HStack(spacing: 3) {
                                if !open {
                                    Image(systemName: "lock.fill")
                                }
                                Text(status)
                            }
                            .font(GlintType.caption(true))
                            .foregroundStyle(isSelected ? GlintTheme.ink.opacity(0.8) : GlintTheme.haze)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        if !compact { Spacer(minLength: 0) }
                    }
                    .padding(.horizontal, compact ? 4 : 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, minHeight: GlintTheme.minTap)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(GlintTheme.goldFace)
                            } else {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(GlintTheme.cardDeep.opacity(0.85))
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(GlintTheme.stroke, lineWidth: 1)
                            }
                        }
                    )
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel("\(LevelBook.worldName(w))\(open ? "" : ", locked")")
            }
        }
    }
}

/// The path and the medallions (positions from `LevelMapGeometry`).
struct LevelMap: View {
    let levels: [Int]
    let data: ProgressData
    let next: Int
    let tint: Color
    let reduceMotion: Bool
    let onPick: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let points = LevelMapGeometry.points(count: levels.count, in: geo.size)
            let node = LevelMapGeometry.nodeSize(count: levels.count, in: geo.size)
            ZStack {
                LevelPath(points: points, bulge: node * 1.25)
                    .stroke(GlintTheme.goldLight.opacity(0.45),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [1, 12]))
                ForEach(0..<min(levels.count, points.count), id: \.self) { i in
                    let n = levels[i]
                    let unlocked = ProgressRules.isUnlocked(level: n, data)
                    Button {
                        onPick(n)
                    } label: {
                        SunMedallion(number: n, stars: ProgressRules.stars(data, level: n), unlocked: unlocked,
                                     isNext: unlocked && n == next, size: node, reduceMotion: reduceMotion,
                                     title: LevelBook.level(n).title,
                                     target: AppRules.starTargetLine(GameController.starScore(for: .level(n))))
                    }
                    .buttonStyle(PressScaleStyle())
                    .position(points[i])
                    .accessibilityLabel(unlocked
                        ? "Level \(n), \(LevelBook.level(n).title), \(ProgressRules.stars(data, level: n)) stars"
                        : "Level \(n), locked")
                }
            }
        }
    }
}

/// The dotted path between medallions. R3b: where it drops from one row to the next (a row's end), it swings out
/// sideways (`bulge` beyond the node, towards the nearer edge) so it never runs through that medallion's labels.
struct LevelPath: Shape {
    let points: [CGPoint]
    var bulge: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        if points.count == 1 { return p }
        for i in 1..<points.count {
            let a = points[i - 1]
            let b = points[i]
            if abs(a.x - b.x) < 1 && bulge > 0 {
                let side: CGFloat = a.x >= rect.midX ? 1 : -1
                let c1 = CGPoint(x: a.x + side * bulge, y: a.y)
                let c2 = CGPoint(x: b.x + side * bulge, y: b.y)
                p.addCurve(to: b, control1: c1, control2: c2)
                continue
            }
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            p.addQuadCurve(to: mid, control: CGPoint(x: a.x, y: mid.y))
            p.addQuadCurve(to: b, control: CGPoint(x: b.x, y: mid.y))
        }
        return p
    }
}

/// A level: a little gold sun, its number, its stars, its name (R3) and, until it has ★★★, the 3rd-star target
/// ("★★★ 1,400"); a closed level is a dark disc with a shadow peeking and a lock; the next one glows.
struct SunMedallion: View {
    let number: Int
    let stars: Int
    let unlocked: Bool
    let isNext: Bool
    let size: CGFloat
    let reduceMotion: Bool
    var title: String = ""
    var target: String? = nil
    @State private var pulse = false

    var body: some View {
        VStack(spacing: size * 0.06) {
            ZStack {
                if isNext {
                    Circle()
                        .fill(GlintTheme.gold.opacity(0.35))
                        .frame(width: size * 1.35, height: size * 1.35)
                        .scaleEffect(pulse ? 1.08 : 0.92)
                        .opacity(pulse ? 0.5 : 1)
                }
                if unlocked && stars >= 3 {
                    MenuSunArt(rays: 12, glow: true)
                        .frame(width: size * 1.45, height: size * 1.45)
                }
                Circle()
                    .fill(unlocked ? AnyShapeStyle(face) : AnyShapeStyle(lockedFace))
                    .frame(width: size, height: size)
                Circle()
                    .strokeBorder(unlocked ? GlintTheme.brassFace : LinearGradient(colors: [GlintTheme.haze.opacity(0.5),
                                  GlintTheme.cardDeep], startPoint: .top, endPoint: .bottom), lineWidth: size * 0.07)
                    .frame(width: size, height: size)
                if unlocked {
                    Text("\(number)")
                        .font(.system(size: size * 0.38, weight: .black, design: .rounded))
                        .foregroundStyle(GlintTheme.ink)
                        .minimumScaleFactor(0.5)
                } else {
                    // R3 (REVIEW-2 fix 15): a shadow peeks out of a closed level.
                    MenuGloomArt(squint: 0.5)
                        .frame(width: size * 0.62, height: size * 0.62)
                        .opacity(0.55)
                        .saturation(0.3)
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.2, weight: .black))
                        .foregroundStyle(GlintTheme.cream.opacity(0.85))
                        .offset(x: size * 0.3, y: size * 0.3)
                }
            }
            .frame(width: size * 1.2, height: size * 1.2)
            if unlocked {
                MenuStarRow(filled: stars, size: size * 0.18)
            } else {
                Color.clear.frame(height: size * 0.18)
            }
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(unlocked ? GlintTheme.cream : GlintTheme.haze)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: size * 1.6)
            }
            if let shownTarget = (unlocked && stars < 3 ? target : nil) {
                Text(shownTarget)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(GlintTheme.goldLight.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .onAppear {
            guard isNext, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var face: LinearGradient {
        let warm: [Color]
        switch stars {
        case 3: warm = [GlintTheme.goldLight, GlintTheme.gold]
        case 0: warm = [GlintTheme.goldLight, Color(appHex: 0xF2C46A)]
        default: warm = [GlintTheme.goldLight, Color(appHex: 0xF6BE55)]
        }
        return LinearGradient(colors: warm, startPoint: .top, endPoint: .bottom)
    }

    private var lockedFace: LinearGradient {
        LinearGradient(colors: [GlintTheme.cardRaised, GlintTheme.cardDeep], startPoint: .top, endPoint: .bottom)
    }
}

struct WorldLockCard: View {
    let world: Int
    let missing: Int
    let needed: Int
    let compact: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                WorldArt(world: world)
                    .frame(width: 120, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .saturation(0.4)
                Image(systemName: "lock.fill")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(GlintTheme.cream)
                    .padding(12)
                    .background(Circle().fill(GlintTheme.cardDeep.opacity(0.9)))
            }
            Text("\(LevelBook.worldName(world)) opens at \(needed) ★ in \(LevelBook.worldName(world - 1))")
                .font(GlintType.headline(compact))
                .foregroundStyle(GlintTheme.cream)
                .multilineTextAlignment(.center)
            Text("\(missing) more ★ to go")
                .font(GlintType.body(compact))
                .foregroundStyle(GlintTheme.goldLight)
        }
        .padding(20)
        .frame(maxWidth: 440)
        .background(CardBackground())
    }
}
