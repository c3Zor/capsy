import SwiftUI
import SwiftData

/// Main screen: the transparent bucket, current level and two actions.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var drops: [StressDrop]

    @State private var showAdd = false
    @State private var showRelease = false
    @State private var dropSignal = 0
    @AppStorage("vesselStyle") private var vesselRaw = VesselStyle.kibiras.rawValue
    @AppStorage("soundOn") private var soundOn = true
    @AppStorage("themeMode") private var themeMode = "auto"

    private var vessel: VesselStyle { VesselStyle(rawValue: vesselRaw) ?? .kibiras }
    private var fraction: Double { Bucket.fraction(of: drops) }
    private var level: Int { Bucket.level(of: drops) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header
                CapsySceneView(fraction: fraction, dropSignal: dropSignal, style: vessel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                vesselPicker
                buttons
            }
            .padding(24)
            .background(Color.bg.ignoresSafeArea())
            .toolbar {
                Button {
                    Haptics.tap()
                    themeMode = DayNight.isNight(themeMode) ? "day" : "night"
                } label: {
                    Image(systemName: DayNight.isNight(themeMode) ? "sun.max" : "moon")
                        .foregroundStyle(Color.sub)
                }
                Button {
                    Haptics.tap()
                    soundOn.toggle()
                } label: {
                    Image(systemName: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .foregroundStyle(Color.sub)
                }
                NavigationLink {
                    JourneyView()
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(Color.sub)
                }
            }
        }
        .tint(.acc)
        .sheet(isPresented: $showAdd) {
            AddDropSheet { intensity, note in addDrop(intensity, note: note) }
        }
        .fullScreenCover(isPresented: $showRelease) {
            ReleaseView()
        }
        .onAppear {
            // CI screenshot mode: seed a half-full vessel so the shot is honest.
            if ProcessInfo.processInfo.arguments.contains("--demo"), drops.isEmpty {
                for intensity in [1, 2, 3] { context.insert(StressDrop(intensity: intensity, note: "")) }
                try? context.save()
            }
            absorbQuickDrops()
            Bucket.syncWidget(fraction: Bucket.fraction(of: drops))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { absorbQuickDrops() }
        }
    }

    /// Drops logged from the interactive widget land here as real StressDrops.
    private func absorbQuickDrops() {
        let count = SharedState.pendingQuickDrops
        guard count > 0 else { return }
        SharedState.pendingQuickDrops = 0
        for _ in 0..<count { context.insert(StressDrop(intensity: 1, note: "")) }
        try? context.save()
        dropSignal += 1
        let newLevel = min(Bucket.capacity, level + count * 2)
        Bucket.syncWidget(fraction: Double(newLevel) / Double(Bucket.capacity))
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(Bucket.stateLine(for: fraction))
                .font(.mono(11.5, weight: .medium))
                .kerning(1.8)
                .foregroundStyle(Color.sub)
            Text("\(Int(fraction * 100)) %")
                .font(.mono(54, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.ink)
                .contentTransition(.numericText())
                .animation(.earth, value: level)
        }
        .padding(.top, 8)
    }

    /// Choose your vessel: bucket, potion flask or glass. Saved automatically.
    private var vesselPicker: some View {
        HStack(spacing: 12) {
            ForEach(VesselStyle.allCases) { style in
                let isOn = vessel == style
                Button {
                    Haptics.tap()
                    withAnimation(.spring(duration: 0.4)) { vesselRaw = style.rawValue }
                } label: {
                    Image(systemName: style.symbol)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isOn ? Color.bg : Color.sub)
                        .frame(width: 38, height: 38)
                        .background(isOn ? Color.acc : Color.white.opacity(0.05), in: Circle())
                }
                .accessibilityLabel(style.title)
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: 14) {
            Button {
                Haptics.tap()
                showAdd = true
            } label: {
                Label("DROP", systemImage: "plus")
                    .font(.display(20))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.acc, in: Capsule())
                    .foregroundStyle(Color.bg)
            }

            if level > 0 {
                Button {
                    Haptics.tap()
                    showRelease = true
                } label: {
                    Label("RELEASE", systemImage: "wind")
                        .font(.display(20))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().stroke(Color.sub, lineWidth: 1.5))
                        .foregroundStyle(Color.ink)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(duration: 0.5), value: level > 0)
    }

    private func addDrop(_ intensity: Intensity, note: String) {
        context.insert(StressDrop(intensity: intensity.rawValue, note: note))
        try? context.save()
        dropSignal += 1
        SoundEngine.plop()
        let newLevel = min(Bucket.capacity, level + intensity.rawValue * 2)
        Bucket.syncWidget(fraction: Double(newLevel) / Double(Bucket.capacity))
    }
}

/// Two taps to log a stressful moment: pick a weight, optionally add a note.
struct AddDropSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Intensity, String) -> Void

    @State private var selected: Intensity = .vidutinis
    @State private var note = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("WHAT HIT YOU?")
                .font(.display(26))
                .foregroundStyle(Color.ink)
                .padding(.top, 28)

            HStack(spacing: 12) {
                ForEach(Intensity.allCases) { intensity in
                    intensityButton(intensity)
                }
            }

            TextField("A short note (optional)", text: $note)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(Color.ink)

            Button {
                onSave(selected, note.trimmingCharacters(in: .whitespaces))
                dismiss()
            } label: {
                Text("LET IT DROP")
                    .font(.display(20))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.acc, in: Capsule())
                    .foregroundStyle(Color.bg)
            }

            Spacer()
        }
        .padding(24)
        .presentationDetents([.height(340)])
        .presentationBackground(Color.bg)
    }

    private func intensityButton(_ intensity: Intensity) -> some View {
        let isOn = selected == intensity
        return Button {
            Haptics.tap()
            withAnimation(.spring(duration: 0.35)) { selected = intensity }
        } label: {
            VStack(spacing: 8) {
                // Drop size mirrors the weight of the moment.
                Image(systemName: "drop.fill")
                    .font(.system(size: 18 + CGFloat(intensity.rawValue) * 7))
                    .foregroundStyle(isOn ? Color.acc : Color.sub)
                    .frame(height: 46)
                Text(intensity.title)
                    .font(.subheadline.weight(isOn ? .semibold : .regular))
                    .foregroundStyle(isOn ? Color.ink : Color.sub)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(isOn ? 0.09 : 0.03),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(isOn ? Color.acc.opacity(0.6) : .clear, lineWidth: 1))
        }
    }
}
