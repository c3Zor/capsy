import SwiftUI
import UIKit

// MARK: - Vessel styles

/// The user picks how their stress vessel looks. Every style is transparent
/// glass — the amount of liquid is always visible through it.
enum VesselStyle: String, CaseIterable, Identifiable {
    case kibiras    // blocky voxel bucket
    case eliksyras  // round "mana potion" flask
    case taure      // simple glass tumbler

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kibiras: "Kibirėlis"
        case .eliksyras: "Eliksyras"
        case .taure: "Taurė"
        }
    }

    var symbol: String {
        switch self {
        case .kibiras: "cube"
        case .eliksyras: "flask"
        case .taure: "wineglass"
        }
    }

    /// Where droplets may fall in — the flask has a narrow neck.
    var dropXRange: ClosedRange<Double> {
        self == .eliksyras ? 0.44...0.56 : 0.3...0.7
    }

    /// Interior shape of the vessel, used to clip the liquid and to draw
    /// the glass outline. Coordinates are normalized to the vessel rect.
    func interiorPath(in rect: CGRect) -> Path {
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var p = Path()
        switch self {
        case .kibiras:
            p.addRoundedRect(in: rect, cornerSize: CGSize(width: rect.width * 0.04,
                                                          height: rect.width * 0.04))
        case .eliksyras:
            // Narrow neck flowing into a round body (ellipse traced by points).
            let cx = 0.5, cy = 0.64, rx = 0.38, ry = 0.30
            p.move(to: pt(0.41, 0.05))
            p.addLine(to: pt(0.41, 0.349))
            for deg in stride(from: 256.3, through: -76.3, by: -4.0) {
                let t = deg * .pi / 180
                p.addLine(to: pt(cx + rx * cos(t), cy + ry * sin(t)))
            }
            p.addLine(to: pt(0.59, 0.05))
            p.closeSubpath()
        case .taure:
            // Gently tapered tumbler with a soft bottom.
            p.move(to: pt(0.24, 0.03))
            p.addLine(to: pt(0.76, 0.03))
            p.addLine(to: pt(0.68, 0.90))
            p.addQuadCurve(to: pt(0.32, 0.90), control: pt(0.5, 1.0))
            p.closeSubpath()
        }
        return p
    }
}

// MARK: - Bucket view

/// The heart of Capsy: a live voxel liquid inside a transparent vessel.
///
/// All motion is procedural — two sine waves give the surface life, a
/// damped-spring oscillator gives the liquid inertia (tilt the phone and
/// the water keeps swinging), droplets fall and splash, bubbles rise.
struct BucketView: View {
    /// Target fill level, 0…1. The liquid eases toward it smoothly.
    var fraction: Double
    /// Increment this to make a droplet fall into the vessel.
    var dropSignal: Int = 0
    /// The chosen vessel look.
    var style: VesselStyle = .kibiras

    @State private var sim = LiquidSim()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                sim.step(to: timeline.date.timeIntervalSinceReferenceDate,
                         target: fraction,
                         tilt: MotionManager.shared.roll)
                draw(context, size: size)
            }
        }
        .onChange(of: dropSignal) { _, _ in sim.spawnDrop(in: style.dropXRange) }
        .onAppear { sim.onImpact = { Haptics.splash() } }
    }

    // MARK: - Drawing

    private func draw(_ context: GraphicsContext, size: CGSize) {
        var ctx = context

        // A full vessel trembles gently, asking to be poured out.
        if sim.level > 0.98 {
            ctx.translateBy(x: sin(sim.time * 30) * 1.6, y: 0)
        }

        let cell = min(size.width, size.height) / 15
        let vessel = CGRect(x: cell * 1.6, y: cell * 1.2,
                            width: size.width - cell * 3.2,
                            height: size.height - cell * 2.4)
        let interior = style.interiorPath(in: vessel)

        if style == .kibiras {
            drawVoxelWalls(ctx, bucket: vessel, cell: cell)
        } else {
            ctx.stroke(interior, with: .color(.sand.opacity(0.35)),
                       style: StrokeStyle(lineWidth: cell * 0.24,
                                          lineCap: .round, lineJoin: .round))
        }

        // Everything liquid lives inside the glass.
        var inner = ctx
        inner.clip(to: interior)
        drawLiquid(inner, bucket: vessel, cell: cell)
        drawBubbles(inner, bucket: vessel, cell: cell)
        drawSplash(inner, bucket: vessel, cell: cell)
        drawGlass(inner, interior: interior, bucket: vessel, cell: cell)

        drawDroplet(ctx, bucket: vessel, cell: cell)
    }

    /// Blocky voxel silhouette for the classic bucket: walls, bottom, rim.
    private func drawVoxelWalls(_ ctx: GraphicsContext, bucket: CGRect, cell: CGFloat) {
        let wallColor = Color.sand.opacity(0.28)
        func block(_ x: CGFloat, _ y: CGFloat, scale: CGFloat = 1) {
            let s = cell * 0.92 * scale
            ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: s, height: s),
                          cornerRadius: s * 0.22), with: .color(wallColor))
        }
        var y = bucket.minY
        while y < bucket.maxY {
            block(bucket.minX - cell, y)
            block(bucket.maxX + cell * 0.08, y)
            y += cell
        }
        var x = bucket.minX - cell
        while x < bucket.maxX + cell {
            block(x, bucket.maxY)
            x += cell
        }
        // Rim: one wider block on each side of the opening.
        block(bucket.minX - cell * 1.45, bucket.minY - cell * 0.5, scale: 1.35)
        block(bucket.maxX - cell * 0.05, bucket.minY - cell * 0.5, scale: 1.35)
    }

    /// The vessel is transparent glass: a faint tint and a soft vertical
    /// highlight, so the water amount is always visible through it.
    private func drawGlass(_ ctx: GraphicsContext, interior: Path, bucket: CGRect, cell: CGFloat) {
        ctx.fill(interior, with: .color(.white.opacity(0.035)))
        let highlight = CGRect(x: bucket.minX + bucket.width * 0.16, y: bucket.minY + cell * 0.4,
                               width: cell * 0.55, height: bucket.height - cell * 1.2)
        ctx.fill(Path(roundedRect: highlight, cornerRadius: cell * 0.3),
                 with: .color(.white.opacity(0.06)))
    }

    /// The liquid: a field of voxels under a live wave surface.
    private func drawLiquid(_ ctx: GraphicsContext, bucket: CGRect, cell: CGFloat) {
        guard sim.level > 0.01 else { return }
        let cols = Int(bucket.width / cell)

        for col in 0..<cols {
            let x = bucket.minX + CGFloat(col) * cell
            let u = (Double(col) + 0.5) / Double(cols)
            let surfaceY = bucket.minY + sim.surfaceNorm(atX: u) * bucket.height

            var y = bucket.minY
            var isTopCell = true
            while y + cell <= bucket.maxY + cell * 0.5 {
                let yy = min(y, bucket.maxY - cell)
                if yy + cell * 0.5 > surfaceY {
                    let depth = min(1, (yy - surfaceY) / bucket.height + 0.1)
                    var color = mix(.liquid, .liquidDeep, t: depth)
                    if isTopCell { color = mix(.liquid, .white, t: 0.22); isTopCell = false }
                    ctx.fill(Path(roundedRect: CGRect(x: x + cell * 0.04, y: yy,
                                                      width: cell * 0.92, height: cell * 0.92),
                                  cornerRadius: cell * 0.2),
                             with: .color(color))
                }
                y += cell
            }
        }
    }

    private func drawBubbles(_ ctx: GraphicsContext, bucket: CGRect, cell: CGFloat) {
        for b in sim.bubbles {
            let surface = sim.surfaceNorm(atX: b.x)
            guard b.y > surface + 0.03 else { continue }
            let rect = CGRect(x: bucket.minX + b.x * bucket.width - cell * 0.12,
                              y: bucket.minY + b.y * bucket.height - cell * 0.12,
                              width: cell * 0.24, height: cell * 0.24)
            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.22)))
        }
    }

    private func drawDroplet(_ ctx: GraphicsContext, bucket: CGRect, cell: CGFloat) {
        guard let d = sim.drop else { return }
        let rect = CGRect(x: bucket.minX + d.x * bucket.width - cell * 0.35,
                          y: bucket.minY + d.y * bucket.height - cell * 0.35,
                          width: cell * 0.7, height: cell * 0.7)
        ctx.fill(Path(roundedRect: rect, cornerRadius: cell * 0.18), with: .color(.liquid))
    }

    private func drawSplash(_ ctx: GraphicsContext, bucket: CGRect, cell: CGFloat) {
        for p in sim.splash {
            let s = cell * 0.22
            let rect = CGRect(x: bucket.minX + p.x * bucket.width - s / 2,
                              y: bucket.minY + p.y * bucket.height - s / 2,
                              width: s, height: s)
            ctx.fill(Path(roundedRect: rect, cornerRadius: s * 0.3),
                     with: .color(.liquid.opacity(max(0, p.life))))
        }
    }

    /// Linear blend of two colors in RGB space.
    private func mix(_ a: Color, _ b: Color, t: Double) -> Color {
        let ca = UIColor(a), cb = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ca.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        cb.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(max(0, min(1, t)))
        return Color(red: r1 + (r2 - r1) * t,
                     green: g1 + (g2 - g1) * t,
                     blue: b1 + (b2 - b1) * t)
    }
}

// MARK: - Physics

/// All liquid state, simulated in coordinates normalized to the vessel
/// interior (x: 0…1 across the width, y: 0…1 from rim to bottom).
final class LiquidSim {
    struct Particle { var x, y, vx, vy, life: Double }

    private(set) var level = 0.0          // smoothed fill 0…1
    private(set) var angle = 0.0          // surface tilt (slosh spring)
    private(set) var time = 0.0
    private(set) var drop: (x: Double, y: Double, vy: Double)?
    private(set) var splash: [Particle] = []
    private(set) var bubbles: [(x: Double, y: Double, speed: Double)] = []

    var onImpact: (() -> Void)?

    private var angleVel = 0.0
    private var pendingImpulse = 0.0
    private var lastTime: Double?

    func spawnDrop(in xRange: ClosedRange<Double> = 0.3...0.7) {
        drop = (x: Double.random(in: xRange), y: -0.12, vy: 0)
    }

    /// Surface height at horizontal position x (0…1), in normalized y units.
    func surfaceNorm(atX x: Double) -> Double {
        let base = 1.0 - level * 0.94
        let tiltOffset = angle * (x - 0.5) * 1.2
        let energy = 0.3 + level * 0.7 + min(1.5, abs(angleVel) * 2)
        let wave = 0.012 * energy * sin(x * 9.4 + time * 2.3)
                 + 0.009 * energy * sin(x * 5.1 - time * 1.6)
        return max(0.02, base + tiltOffset + wave)
    }

    func step(to t: Double, target: Double, tilt: Double) {
        defer { lastTime = t }
        time = t
        guard let last = lastTime else { return }
        let dt = min(t - last, 1.0 / 20.0)
        guard dt > 0 else { return }

        // Fill level eases toward its target — nothing ever snaps.
        level += (target - level) * min(1, dt * 3.5)

        // Damped spring: the surface chases the device tilt but overshoots
        // and swings back, like real water with inertia.
        let goal = max(-0.5, min(0.5, tilt)) * 0.5
        angleVel += (22 * (goal - angle) - 3.2 * angleVel) * dt
        angleVel += pendingImpulse
        pendingImpulse = 0
        angle += angleVel * dt

        stepDroplet(dt)
        stepSplash(dt)
        stepBubbles(dt)
    }

    private func stepDroplet(_ dt: Double) {
        guard var d = drop else { return }
        d.vy += 2.6 * dt
        d.y += d.vy * dt
        if d.y >= surfaceNorm(atX: d.x) {
            drop = nil
            burstSplash(x: d.x, y: d.y)
            pendingImpulse += d.x < 0.5 ? 0.4 : -0.4
            onImpact?()
        } else {
            drop = d
        }
    }

    private func burstSplash(x: Double, y: Double) {
        for _ in 0..<10 {
            splash.append(Particle(x: x, y: y,
                                   vx: Double.random(in: -0.5...0.5),
                                   vy: Double.random(in: -1.1 ... -0.3),
                                   life: Double.random(in: 0.4...0.8)))
        }
    }

    private func stepSplash(_ dt: Double) {
        for i in splash.indices {
            splash[i].vy += 2.6 * dt
            splash[i].x += splash[i].vx * dt
            splash[i].y += splash[i].vy * dt
            splash[i].life -= dt * 1.4
        }
        splash.removeAll { $0.life <= 0 }
    }

    private func stepBubbles(_ dt: Double) {
        // Ambient life: a few bubbles slowly rise while there is liquid.
        if level > 0.1, bubbles.count < 3, Double.random(in: 0...1) < dt * 0.4 {
            bubbles.append((x: Double.random(in: 0.15...0.85), y: 0.95,
                            speed: Double.random(in: 0.05...0.12)))
        }
        for i in bubbles.indices {
            bubbles[i].y -= bubbles[i].speed * dt / max(0.2, level)
        }
        bubbles.removeAll { $0.y <= surfaceNorm(atX: $0.x) }
    }
}
