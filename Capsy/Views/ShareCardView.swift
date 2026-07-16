import SwiftUI
import Foundation
import UIKit

// MARK: - Share card

/// A still, poster-like snapshot of a finished release ritual — fixed size
/// so it renders identically no matter where it is captured or shared.
struct ShareCardView: View {
    let drainedUnits: Int
    let totalReleases: Int
    let milestoneTitle: String?

    private let cardWidth: CGFloat = 360
    private let cardHeight: CGFloat = 480

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                header
                Spacer(minLength: 14)
                vessel
                Spacer(minLength: 14)
                statsRow
                Spacer(minLength: 14)
                wordmark
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 28)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.sand.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            Color.moss
            RadialGradient(colors: [Color.liquidDeep.opacity(0.35), .clear],
                           center: UnitPoint(x: 0.5, y: 0.6),
                           startRadius: 8, endRadius: 260)
            voxelAccents
        }
    }

    /// A few faint voxel squares in the bottom corner — a quiet echo of the
    /// bucket's blocky walls, tying the card back to the app.
    private var voxelAccents: some View {
        GeometryReader { geo in
            ForEach(0..<4, id: \.self) { i in
                let s: CGFloat = 9
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.sand.opacity(0.05))
                    .frame(width: s, height: s)
                    .position(x: 20 + CGFloat(i % 2) * (s + 6),
                              y: geo.size.height - 20 - CGFloat(i / 2) * (s + 6))
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("Paleista.")
                .font(.system(size: 40, weight: .light, design: .rounded))
                .foregroundStyle(Color.sand)
            Text(dateLine)
                .font(.subheadline)
                .foregroundStyle(Color.stone)
        }
        .padding(.top, 4)
    }

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "lt_LT")
        formatter.dateFormat = "yyyy 'm.' MMMM d 'd.'"
        return formatter.string(from: .now)
    }

    // MARK: Vessel

    /// A calm, still vessel — the ritual is over, the wave has settled into
    /// a single frozen curve instead of the live simulation on the home screen.
    private var vessel: some View {
        Canvas { context, size in
            drawVessel(context, size: size)
        }
        .frame(width: 150, height: 184)
    }

    private func drawVessel(_ context: GraphicsContext, size: CGSize) {
        let rect = CGRect(x: size.width * 0.16, y: size.height * 0.02,
                          width: size.width * 0.68, height: size.height * 0.96)

        // Gently tapered glass, open at the top.
        var glass = Path()
        glass.move(to: CGPoint(x: rect.minX, y: rect.minY))
        glass.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        glass.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.maxY))
        glass.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.maxY),
                           control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.06))
        glass.closeSubpath()

        context.fill(glass, with: .color(.white.opacity(0.03)))

        // Liquid: a shallow, still pool — most of the stress has been poured out.
        let surfaceY = rect.minY + rect.height * 0.7
        var liquid = Path()
        liquid.move(to: CGPoint(x: rect.minX + rect.width * 0.02, y: surfaceY + 7))
        liquid.addCurve(to: CGPoint(x: rect.midX, y: surfaceY - 5),
                        control1: CGPoint(x: rect.minX + rect.width * 0.22, y: surfaceY - 15),
                        control2: CGPoint(x: rect.minX + rect.width * 0.38, y: surfaceY + 5))
        liquid.addCurve(to: CGPoint(x: rect.maxX - rect.width * 0.02, y: surfaceY + 4),
                        control1: CGPoint(x: rect.minX + rect.width * 0.64, y: surfaceY - 15),
                        control2: CGPoint(x: rect.maxX - rect.width * 0.2, y: surfaceY + 13))
        liquid.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.maxY))
        liquid.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.maxY),
                            control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.06))
        liquid.closeSubpath()

        var inner = context
        inner.clip(to: glass)
        inner.fill(liquid, with: .linearGradient(
            Gradient(colors: [.liquid, .liquidDeep]),
            startPoint: CGPoint(x: rect.midX, y: surfaceY - 12),
            endPoint: CGPoint(x: rect.midX, y: rect.maxY)))

        // Soft vertical highlight for glass depth.
        let highlight = CGRect(x: rect.minX + rect.width * 0.16, y: rect.minY + 6,
                               width: rect.width * 0.09, height: rect.height * 0.7)
        inner.fill(Path(roundedRect: highlight, cornerRadius: highlight.width / 2),
                  with: .color(.white.opacity(0.05)))

        context.stroke(glass, with: .color(.sand.opacity(0.4)),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(value: "\(drainedUnits)", label: "išleista vnt.")
            divider
            stat(value: "\(totalReleases)", label: "išleidimų iš viso")
            divider
            stat(value: milestoneTitle ?? "–", label: "kelio etapas", isName: true)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.sand.opacity(0.12))
            .frame(width: 1, height: 34)
    }

    private func stat(value: String, label: String, isName: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(isName ? .subheadline.weight(.semibold) : .title2.weight(.semibold))
                .foregroundStyle(Color.sand)
                .lineLimit(isName ? 2 : 1)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .frame(height: isName ? 34 : 26)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.stone)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Wordmark

    private var wordmark: some View {
        HStack(spacing: 6) {
            Image(systemName: "drop.fill")
                .font(.caption2)
                .foregroundStyle(Color.liquid.opacity(0.7))
            Text("Capsy")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.stone)
        }
    }
}

// MARK: - Share button

/// Renders `ShareCardView` to an image and offers it via the system share
/// sheet. The image is prepared as soon as this view appears, so the button
/// opens straight into sharing instead of needing a first "prepare" tap.
struct ShareCardButton: View {
    var drainedUnits: Int
    var totalReleases: Int
    var milestoneTitle: String?

    @State private var cardImage: Image?

    var body: some View {
        Group {
            if let cardImage {
                ShareLink(item: cardImage,
                          preview: SharePreview("Capsy — Paleista.", image: cardImage)) {
                    label
                }
            } else {
                label.opacity(0.45)
            }
        }
        .onAppear(perform: renderCard)
    }

    private var label: some View {
        Label("Pasidalinti", systemImage: "square.and.arrow.up")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.moss)
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .background(Color.sand, in: Capsule())
    }

    @MainActor
    private func renderCard() {
        guard cardImage == nil else { return }
        let card = ShareCardView(drainedUnits: drainedUnits,
                                 totalReleases: totalReleases,
                                 milestoneTitle: milestoneTitle)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            cardImage = Image(uiImage: uiImage)
        }
    }
}
