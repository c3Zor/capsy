import SwiftUI
import UIKit

// MARK: - Mood

/// Capsy's mood mirrors how full the bucket is. Raw values are the asset
/// names for the generated voxel art (see Assets.xcassets).
enum MascotMood: String {
    case calm       = "MascotCalm"
    case busy  = "MascotBusy"
    case heavy      = "MascotHeavy"
    case relieved = "MascotRelief"

    static func forFraction(_ f: Double) -> MascotMood {
        switch f {
        case ..<0.4: .calm
        case ..<0.8: .busy
        default:     .heavy
        }
    }
}

// MARK: - Mascot

/// Capsy the droplet: a small, quiet companion on the home screen.
///
/// Uses the generated voxel art when it's in the asset catalog; otherwise
/// falls back to a hand-drawn vector droplet so the app never ships a
/// missing-image gap. Either way it idles with a gentle bob and blink.
struct MascotView: View {
    var mood: MascotMood

    @State private var bob = false
    @State private var blink = false

    var body: some View {
        Group {
            if let art = UIImage(named: mood.rawValue) {
                Image(uiImage: art)
                    .resizable()
                    .scaledToFit()
            } else {
                DropletFace(mood: mood, blink: blink)
            }
        }
        .frame(height: 72)
        .offset(y: bob ? -3 : 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                bob = true
            }
        }
        .task { await blinkLoop() }
    }

    /// A quick blink every few seconds — calmer than a mechanical blink rate.
    private func blinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3.2))
            withAnimation(.easeInOut(duration: 0.1)) { blink = true }
            try? await Task.sleep(for: .seconds(0.12))
            withAnimation(.easeInOut(duration: 0.1)) { blink = false }
        }
    }
}

// MARK: - Vector fallback

/// Teal teardrop silhouette with a simple face. No third-party assets —
/// just paths, so it always renders even before the art lands.
private struct DropletFace: View {
    var mood: MascotMood
    var blink: Bool

    private let size = CGSize(width: 58, height: 72)

    var body: some View {
        ZStack {
            DropletShape()
                .fill(LinearGradient(colors: [.acc, .accDeep],
                                      startPoint: .top, endPoint: .bottom))
            DropletShape()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
            face
        }
        .frame(width: size.width, height: size.height)
    }

    private var face: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) { eye; eye }
            mouth
        }
        .offset(y: size.height * 0.14)
    }

    /// Eyes go flat for a happy squint (relief) or a brief blink.
    private var eye: some View {
        Capsule()
            .fill(Color.bg)
            .frame(width: 5, height: mood == .relieved || blink ? 1.5 : 7)
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .calm:
            SmileArc(curveUp: true)
                .stroke(Color.bg, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 16, height: 6)
        case .busy:
            Capsule().fill(Color.bg).frame(width: 13, height: 2)
        case .heavy:
            SmileArc(curveUp: false)
                .stroke(Color.bg, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 16, height: 6)
        case .relieved:
            SmileArc(curveUp: true)
                .stroke(Color.bg, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .frame(width: 19, height: 8)
        }
    }
}

/// A rounded teardrop: pointed top, full round bottom.
private struct DropletShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.62),
                   control1: CGPoint(x: rect.midX + w * 0.32, y: rect.minY + h * 0.18),
                   control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.4))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + h * 0.66),
                 radius: w * 0.5, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                   control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.4),
                   control2: CGPoint(x: rect.midX - w * 0.32, y: rect.minY + h * 0.18))
        p.closeSubpath()
        return p
    }
}

/// A single curved stroke: smile when it bulges down, worried arc when it
/// bulges up.
private struct SmileArc: Shape {
    var curveUp: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: curveUp ? rect.minY : rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: curveUp ? rect.minY : rect.maxY),
                       control: CGPoint(x: rect.midX, y: curveUp ? rect.maxY : rect.minY))
        return p
    }
}
