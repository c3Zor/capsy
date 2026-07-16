import SwiftUI

/// First-run welcome flow: what Capsy is, how to look, how it works.
/// Three swipeable pages. Sets `hasOnboarded` when the user taps "Pradėti".
struct OnboardingView: View {
    @AppStorage("vesselStyle") private var vesselRaw = VesselStyle.kibiras.rawValue
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var page = 0

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ConceptPage().tag(0)
                    VesselChoicePage(vesselRaw: $vesselRaw).tag(1)
                    ReadyPage(hasOnboarded: $hasOnboarded).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                pageDots
            }
        }
        .onChange(of: page) { _, _ in Haptics.tap() }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Color.acc : Color.sub.opacity(0.4))
                    .frame(width: i == page ? 22 : 8, height: 8)
            }
        }
        .animation(.spring(duration: 0.4), value: page)
        .padding(.bottom, 28)
    }
}

// MARK: - Page 1: Concept

private struct ConceptPage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            WavingDroplet()
                .frame(height: 140)
            VStack(spacing: 10) {
                Text("Capsy")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                Text("Stresas — tai skystis. Jis kaupiasi lašas po lašo.")
                    .font(.title3)
                    .foregroundStyle(Color.sub)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            Spacer()
            Spacer()
        }
    }
}

/// A gently bobbing droplet with two soft ripple rings — pure shapes, no
/// simulation. Just enough motion to feel alive before the real bucket does.
private struct WavingDroplet: View {
    @State private var bob = false

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .stroke(Color.acc.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 92 + CGFloat(i) * 36, height: 92 + CGFloat(i) * 36)
                    .scaleEffect(bob ? 1.08 : 0.92)
                    .opacity(bob ? 0.12 : 0.5)
                    .animation(
                        .easeInOut(duration: 2.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.4),
                        value: bob)
            }
            DropletShape()
                .fill(LinearGradient(colors: [.acc, .accDeep],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 60, height: 78)
                .rotationEffect(.degrees(bob ? 4 : -4))
                .offset(y: bob ? -6 : 6)
                .shadow(color: .acc.opacity(0.3), radius: 20)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: bob)
        }
        .onAppear { bob = true }
    }
}

/// Classic raindrop silhouette: pointed top, round bottom.
private struct DropletShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let center = CGPoint(x: rect.midX, y: rect.minY + h * 0.62)

        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.maxX, y: center.y),
                   control1: CGPoint(x: rect.midX + w * 0.1, y: rect.minY + h * 0.05),
                   control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.32))
        p.addArc(center: center, radius: w * 0.5,
                 startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                   control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.32),
                   control2: CGPoint(x: rect.midX - w * 0.1, y: rect.minY + h * 0.05))
        p.closeSubpath()
        return p
    }
}

// MARK: - Page 2: Vessel choice

private struct VesselChoicePage: View {
    @Binding var vesselRaw: String
    private var selected: VesselStyle { VesselStyle(rawValue: vesselRaw) ?? .kibiras }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                Text("Pasirink indą")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Text("Kur kaupsis tavo lašai?")
                    .font(.subheadline)
                    .foregroundStyle(Color.sub)
            }
            VStack(spacing: 14) {
                ForEach(VesselStyle.allCases) { style in
                    vesselCard(style)
                }
            }
            .padding(.horizontal, 28)
            Spacer()
            Spacer()
        }
    }

    private func vesselCard(_ style: VesselStyle) -> some View {
        let isOn = selected == style
        return Button {
            Haptics.tap()
            withAnimation(.spring(duration: 0.4)) { vesselRaw = style.rawValue }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: style.symbol)
                    .font(.system(size: 28))
                    .foregroundStyle(isOn ? Color.bg : Color.acc)
                    .frame(width: 52, height: 52)
                    .background(isOn ? Color.acc : Color.white.opacity(0.05), in: Circle())
                Text(style.title)
                    .font(.title3.weight(isOn ? .semibold : .regular))
                    .foregroundStyle(Color.ink)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.acc)
                }
            }
            .padding(18)
            .background(Color.white.opacity(isOn ? 0.08 : 0.03),
                        in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20)
                .stroke(isOn ? Color.acc.opacity(0.6) : .clear, lineWidth: 1.5))
        }
    }
}

// MARK: - Page 3: Ready

private struct ReadyPage: View {
    @Binding var hasOnboarded: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 18) {
                Text("Kaip tai veikia")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Color.ink)
                loopStep(symbol: "drop.fill", text: "Lašas — pažymi, kas slegia")
                loopStep(symbol: "cube.fill", text: "Indas pilnėja")
                loopStep(symbol: "wind", text: "Kvėpavimo ritualas jį ištuština")
            }
            .padding(.horizontal, 32)
            Spacer()
            Button {
                Haptics.success()
                hasOnboarded = true
            } label: {
                Text("Pradėti")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.acc, in: Capsule())
                    .foregroundStyle(Color.bg)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
        }
    }

    private func loopStep(symbol: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.acc)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.05), in: Circle())
            Text(text)
                .font(.body)
                .foregroundStyle(Color.ink)
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
