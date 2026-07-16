import SwiftUI
import SwiftData

/// Main screen: the transparent bucket, current level and two actions.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var drops: [StressDrop]

    @State private var showAdd = false
    @State private var showRelease = false
    @State private var dropSignal = 0
    @AppStorage("vesselStyle") private var vesselRaw = VesselStyle.kibiras.rawValue
    @AppStorage("soundOn") private var soundOn = true

    private var vessel: VesselStyle { VesselStyle(rawValue: vesselRaw) ?? .kibiras }
    private var fraction: Double { Bucket.fraction(of: drops) }
    private var level: Int { Bucket.level(of: drops) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header
                BucketView(fraction: fraction, dropSignal: dropSignal, style: vessel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                vesselPicker
                buttons
            }
            .padding(24)
            .background(Color.moss.ignoresSafeArea())
            .toolbar {
                Button {
                    Haptics.tap()
                    soundOn.toggle()
                } label: {
                    Image(systemName: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .foregroundStyle(Color.stone)
                }
                NavigationLink {
                    JourneyView()
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(Color.stone)
                }
            }
        }
        .tint(.liquid)
        .fontDesign(.rounded)
        .sheet(isPresented: $showAdd) {
            AddDropSheet { intensity, note in addDrop(intensity, note: note) }
        }
        .fullScreenCover(isPresented: $showRelease) {
            ReleaseView()
        }
        .onAppear { Bucket.syncWidget(fraction: fraction) }
    }

    private var header: some View {
        VStack(spacing: 6) {
            MascotView(mood: MascotMood.forFraction(fraction))
            Text(Bucket.stateLine(for: fraction))
                .font(.title3)
                .foregroundStyle(Color.stone)
            Text("\(Int(fraction * 100)) %")
                .font(.system(size: 56, weight: .light, design: .rounded))
                .foregroundStyle(Color.sand)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.6), value: level)
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
                        .foregroundStyle(isOn ? Color.moss : Color.stone)
                        .frame(width: 38, height: 38)
                        .background(isOn ? Color.liquid : Color.white.opacity(0.05), in: Circle())
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
                Label("Lašas", systemImage: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.liquid, in: Capsule())
                    .foregroundStyle(Color.moss)
            }

            if level > 0 {
                Button {
                    Haptics.tap()
                    showRelease = true
                } label: {
                    Label("Išleisti", systemImage: "wind")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.sand.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.sand)
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
            Text("Kas užgriuvo?")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.sand)
                .padding(.top, 28)

            HStack(spacing: 12) {
                ForEach(Intensity.allCases) { intensity in
                    intensityButton(intensity)
                }
            }

            TextField("Trumpa pastaba (nebūtina)", text: $note)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(Color.sand)

            Button {
                onSave(selected, note.trimmingCharacters(in: .whitespaces))
                dismiss()
            } label: {
                Text("Įlašinti")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.liquid, in: Capsule())
                    .foregroundStyle(Color.moss)
            }

            Spacer()
        }
        .padding(24)
        .fontDesign(.rounded)
        .presentationDetents([.height(340)])
        .presentationBackground(Color.moss)
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
                    .foregroundStyle(isOn ? Color.liquid : Color.stone)
                    .frame(height: 46)
                Text(intensity.title)
                    .font(.subheadline.weight(isOn ? .semibold : .regular))
                    .foregroundStyle(isOn ? Color.sand : Color.stone)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(isOn ? 0.09 : 0.03),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(isOn ? Color.liquid.opacity(0.6) : .clear, lineWidth: 1))
        }
    }
}
