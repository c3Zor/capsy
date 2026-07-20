import SwiftUI

/// First-run welcome flow: what Capsy is, how to look, a soft Plus intro,
/// how it works. Four swipeable pages. Sets `hasOnboarded` on "Begin".
struct OnboardingView: View {
    @AppStorage("vesselStyle") private var vesselRaw = VesselStyle.bucket.rawValue
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var page = 0

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ConceptPage().tag(0)
                    VesselChoicePage(vesselRaw: $vesselRaw).tag(1)
                    PlusIntroPage(page: $page).tag(2)
                    ReadyPage(hasOnboarded: $hasOnboarded).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                pageDots
            }
        }
        .onChange(of: page) { _, _ in Haptics.tap() }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
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
                Text("CAPSY")
                    .font(.display(46))
                    .foregroundStyle(Color.ink)
                Text("Stress is liquid. It gathers drop by drop.")
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
    private var selected: VesselStyle { VesselStyle(rawValue: vesselRaw) ?? .bucket }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                Text("PICK YOUR BODY")
                    .font(.display(28))
                    .foregroundStyle(Color.ink)
                Text("Where will your drops gather?")
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

// MARK: - Page 3: Plus intro

/// Soft, skippable glimpse of Capsy Plus. No pressure — just a door left open.
private struct PlusIntroPage: View {
    @Binding var page: Int
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Color.acc)
                .frame(width: 84, height: 84)
                .background(Color.white.opacity(0.05), in: Circle())
            VStack(spacing: 10) {
                Text("CAPSY PLUS")
                    .font(.display(32))
                    .foregroundStyle(Color.ink)
                Text("A little more room, if you'd like it.")
                    .font(.subheadline)
                    .foregroundStyle(Color.sub)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 14) {
                benefitRow(symbol: "paintpalette.fill", text: "All cosmetics, unlocked")
                benefitRow(symbol: "heart.fill", text: "Deeper Health insights")
                benefitRow(symbol: "infinity", text: "Unlimited habits")
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
            VStack(spacing: 14) {
                Button {
                    Haptics.tap()
                    showPaywall = true
                } label: {
                    Text("TRY FREE FOR 7 DAYS")
                        .font(.display(20))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.acc, in: Capsule())
                        .foregroundStyle(Color.bg)
                }
                Button {
                    Haptics.tap()
                    withAnimation(.earth) { page = 3 }
                } label: {
                    Text("MAYBE LATER")
                        .font(.subheadline)
                        .foregroundStyle(Color.sub)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func benefitRow(symbol: String, text: String) -> some View {
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

// MARK: - Page 4: Ready

private struct ReadyPage: View {
    @Binding var hasOnboarded: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 18) {
                Text("HOW IT WORKS")
                    .font(.display(28))
                    .foregroundStyle(Color.ink)
                loopStep(symbol: "drop.fill", text: "A drop marks what weighs on you")
                loopStep(symbol: "cube.fill", text: "Capsy fills up")
                loopStep(symbol: "wind", text: "A breathing ritual empties it")
            }
            .padding(.horizontal, 32)
            Spacer()
            Button {
                Haptics.success()
                hasOnboarded = true
                Reminders.requestAndScheduleEvening()
                Health.requestAuthorization()
            } label: {
                Text("BEGIN")
                    .font(.display(20))
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
