import SwiftUI
import SwiftData

/// The release ritual: guided breathing while the bucket drains on every
/// exhale. Completing it releases all drops and advances the journey.
struct ReleaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<StressDrop> { $0.released == false }) private var pending: [StressDrop]
    @Query private var sessions: [ReleaseSession]

    private let totalCycles = 4

    private enum Phase: String {
        case ready = "PASIRUOŠK…"
        case inhale = "ĮKVĖPK…"
        case exhale = "IŠKVĖPK…"
        case done = "BANGA NUĖJO."
    }

    @State private var phase: Phase = .ready
    @State private var breath: CGFloat = 0.55
    @State private var fraction = 0.0
    @State private var cycle = 0
    @State private var lastDrained = 0
    @State private var showRipples = false
    @State private var candleDim = false
    @AppStorage("vesselStyle") private var vesselRaw = VesselStyle.kibiras.rawValue

    var body: some View {
        VStack(spacing: 28) {
            topBar

            Text(phase.rawValue)
                .font(.display(30))
                .foregroundStyle(Color.ink)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: phase)

            breathingCircle

            BucketView(fraction: fraction,
                       style: VesselStyle(rawValue: vesselRaw) ?? .kibiras)
                .frame(height: 210)
                .overlay(alignment: .bottom) {
                    if showRipples { RippleView() } // banga, ne sprogimas
                }

            if phase == .done {
                doneFooter
            } else {
                Text("\(min(cycle + 1, totalCycles)) / \(totalCycles)")
                    .font(.mono(13, weight: .medium))
                    .foregroundStyle(Color.sub)
            }
            Spacer(minLength: 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea())
        .overlay { // pabaiga: ekranas trumpam pritemsta kaip žvakė — ir vėl įsižiebia
            Color.black.opacity(candleDim ? 0.55 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 1.4), value: candleDim)
        }
        .task { await run() }
        .onAppear { SoundEngine.droneOn() }   // erdvė tyliai „skamba"
        .onDisappear { SoundEngine.droneOff() }
    }

    private var topBar: some View {
        HStack {
            if phase != .done {
                Button {
                    dismiss()   // cancelling keeps every drop in the bucket
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(Color.sub)
                        .padding(10)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
            }
            Spacer()
        }
    }

    private var breathingCircle: some View {
        ZStack {
            Circle()
                .stroke(Color.acc.opacity(0.25), lineWidth: 1.5)
            Circle()
                .fill(Color.acc.opacity(0.22))
                .scaleEffect(breath)
            Circle()
                .stroke(Color.acc, lineWidth: 2)
                .scaleEffect(breath)
        }
        .frame(width: 190, height: 190)
    }

    private var doneFooter: some View {
        VStack(spacing: 12) {
            MascotView(mood: .palengvejas)
            Text("SODE — NAUJAS AKMUO.")
                .font(.mono(12, weight: .medium))
                .kerning(1.8)
                .foregroundStyle(Color.ink)
            if let next = Journey.next(after: sessions.count) {
                Text("Iki „\(next.title)“ liko \(next.releases - sessions.count)")
                    .font(.subheadline)
                    .foregroundStyle(Color.sub)
            }
            ShareCardButton(
                drainedUnits: lastDrained,
                totalReleases: sessions.count,
                milestoneTitle: Journey.milestones.first { $0.releases == sessions.count }?.title
            )
            Button {
                dismiss()
            } label: {
                Text("GRĮŽTI")
                    .font(.display(20))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.acc, in: Capsule())
                    .foregroundStyle(Color.bg)
            }
            .padding(.top, 4)
        }
        .transition(.opacity)
    }

    // MARK: - Ritual flow

    private func run() async {
        let startFraction = Bucket.fraction(of: pending)
        fraction = startFraction

        try? await Task.sleep(for: .seconds(1.5))
        for c in 1...totalCycles {
            if Task.isCancelled { return }
            cycle = c - 1

            phase = .inhale
            Haptics.tap()
            SoundEngine.breatheIn()
            withAnimation(.easeInOut(duration: 4)) { breath = 1.0 }
            try? await Task.sleep(for: .seconds(4))
            if Task.isCancelled { return }

            phase = .exhale
            Haptics.tap()
            SoundEngine.breatheOut()
            withAnimation(.easeInOut(duration: 6)) { breath = 0.55 }
            // The bucket only drains while breathing out.
            fraction = startFraction * Double(totalCycles - c) / Double(totalCycles)
            try? await Task.sleep(for: .seconds(6))
        }
        if Task.isCancelled { return }
        finish()
    }

    private func finish() {
        lastDrained = Bucket.level(of: pending)
        for drop in pending { drop.released = true }
        context.insert(ReleaseSession(cycles: totalCycles, drainedUnits: lastDrained))
        try? context.save()
        Bucket.syncWidget(fraction: 0)
        Haptics.success()
        SoundEngine.chime() // Tibeto dubens tonas su ilgu gesimu
        withAnimation(.earth) { phase = .done }
        showRipples = true
        // Žvakė (#080): pritemsta ir vėl įsižiebia.
        candleDim = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { candleDim = false }
    }
}

/// Užbaigus kvėpavimą per grindis nueina ratilai — atlygis yra banga,
/// ne konfeti sprogimas.
struct RippleView: View {
    @State private var expand = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Ellipse()
                    .stroke(Color.acc.opacity(expand ? 0 : 0.5), lineWidth: 1.5)
                    .frame(width: 90, height: 26)
                    .scaleEffect(expand ? 3.4 : 0.4)
                    .animation(.easeOut(duration: 2.2).delay(Double(i) * 0.25), value: expand)
            }
        }
        .allowsHitTesting(false)
        .onAppear { expand = true }
    }
}
