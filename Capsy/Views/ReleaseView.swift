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
        case ready = "Pasiruošk…"
        case inhale = "Įkvėpk"
        case exhale = "Iškvėpk"
        case done = "Paleista."
    }

    @State private var phase: Phase = .ready
    @State private var breath: CGFloat = 0.55
    @State private var fraction = 0.0
    @State private var cycle = 0
    @AppStorage("vesselStyle") private var vesselRaw = VesselStyle.kibiras.rawValue

    var body: some View {
        VStack(spacing: 28) {
            topBar

            Text(phase.rawValue)
                .font(.title.weight(.light))
                .foregroundStyle(Color.sand)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: phase)

            breathingCircle

            BucketView(fraction: fraction,
                       style: VesselStyle(rawValue: vesselRaw) ?? .kibiras)
                .frame(height: 210)

            if phase == .done {
                doneFooter
            } else {
                Text("\(min(cycle + 1, totalCycles)) / \(totalCycles)")
                    .font(.headline)
                    .foregroundStyle(Color.stone)
            }
            Spacer(minLength: 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.moss.ignoresSafeArea())
        .fontDesign(.rounded)
        .task { await run() }
    }

    private var topBar: some View {
        HStack {
            if phase != .done {
                Button {
                    dismiss()   // cancelling keeps every drop in the bucket
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(Color.stone)
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
                .stroke(Color.liquid.opacity(0.25), lineWidth: 1.5)
            Circle()
                .fill(Color.liquid.opacity(0.22))
                .scaleEffect(breath)
            Circle()
                .stroke(Color.liquid, lineWidth: 2)
                .scaleEffect(breath)
        }
        .frame(width: 190, height: 190)
    }

    private var doneFooter: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(Color.liquid)
                .symbolEffect(.bounce, value: phase)
            Text("Ramybės kelias +1")
                .font(.headline)
                .foregroundStyle(Color.sand)
            if let next = Journey.next(after: sessions.count) {
                Text("Iki „\(next.title)“ liko \(next.releases - sessions.count)")
                    .font(.subheadline)
                    .foregroundStyle(Color.stone)
            }
            Button {
                dismiss()
            } label: {
                Text("Grįžti")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.liquid, in: Capsule())
                    .foregroundStyle(Color.moss)
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
            withAnimation(.easeInOut(duration: 4)) { breath = 1.0 }
            try? await Task.sleep(for: .seconds(4))
            if Task.isCancelled { return }

            phase = .exhale
            Haptics.tap()
            withAnimation(.easeInOut(duration: 6)) { breath = 0.55 }
            // The bucket only drains while breathing out.
            fraction = startFraction * Double(totalCycles - c) / Double(totalCycles)
            try? await Task.sleep(for: .seconds(6))
        }
        if Task.isCancelled { return }
        finish()
    }

    private func finish() {
        let drained = Bucket.level(of: pending)
        for drop in pending { drop.released = true }
        context.insert(ReleaseSession(cycles: totalCycles, drainedUnits: drained))
        try? context.save()
        Bucket.syncWidget(fraction: 0)
        Haptics.success()
        withAnimation(.spring(duration: 0.6)) { phase = .done }
    }
}
