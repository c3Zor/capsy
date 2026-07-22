import SwiftUI
import SwiftData

// MARK: - Habit model
//
// Not yet declared in Capsy/Models.swift — this view owns it until the
// integrator moves it there. See integration_notes: `Habit.self` must be
// added to the `.modelContainer(for:)` list in CapsyApp.swift or this
// screen's @Query will crash at runtime.

@Model
final class Habit {
    var name: String
    var symbol: String
    var timesDone: Int
    var lastDone: Date?
    var createdAt: Date

    init(name: String, symbol: String) {
        self.name = name
        self.symbol = symbol
        self.timesDone = 0
        self.lastDone = nil
        self.createdAt = .now
    }
}

/// Eight calm, ordinary SF symbols to choose from when planting a habit.
enum HabitSymbol {
    static let choices: [String] = [
        "drop.fill", "leaf.fill", "moon.stars.fill", "cup.and.saucer.fill",
        "figure.walk", "book.fill", "sun.max.fill", "heart.fill",
    ]

    /// Spoken name for a symbol choice, for VoiceOver — the SF Symbol name
    /// alone ("drop point fill") reads poorly.
    static func title(for symbol: String) -> String {
        switch symbol {
        case "drop.fill": "Drop"
        case "leaf.fill": "Leaf"
        case "moon.stars.fill": "Moon"
        case "cup.and.saucer.fill": "Cup"
        case "figure.walk": "Walk"
        case "book.fill": "Book"
        case "sun.max.fill": "Sun"
        case "heart.fill": "Heart"
        default: "Symbol"
        }
    }
}

/// "Calm Habits" — small, positive taps that quietly earn gold and xp.
/// Habitica's habit loop, tuned to gyva-tyla stillness.
struct HabitsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.createdAt) private var habits: [Habit]

    @State private var showAdd = false
    @State private var showPaywall = false

    var body: some View {
        List {
            Section {
                header
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if habits.isEmpty {
                Section {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(habits) { habit in
                        HabitRow(habit: habit) { bump(habit) }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    }
                    .onDelete(perform: deleteHabits)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("Calm Habits")
        .toolbar {
            Button {
                Haptics.tap()
                // Free tier holds four habits; Plus removes the cap.
                if habits.count >= 4 && !Plus.shared.isPlus {
                    showPaywall = true
                } else {
                    showAdd = true
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.acc)
            }
            .accessibilityLabel("Plant a habit")
            .accessibilityHint("Adds a new calm habit")
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showAdd) {
            AddHabitSheet { name, symbol in
                context.insert(Habit(name: name, symbol: symbol))
                try? context.save()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR CALM HABITS")
                .font(.mono(11.5, weight: .medium))
                .kerning(1.8)
                .foregroundStyle(Color.sub)
            Text("TAP TO KEEP THEM ALIVE")
                .font(.display(24))
                .foregroundStyle(Color.ink)
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf")
                .font(.system(size: 28))
                .foregroundStyle(Color.sub.opacity(0.6))
                .accessibilityHidden(true)
            Text("NO HABITS YET. PLANT ONE.")
                .font(.mono(11, weight: .regular))
                .kerning(1.5)
                .foregroundStyle(Color.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func bump(_ habit: Habit) {
        habit.timesDone += 1
        habit.lastDone = .now
        try? context.save()
        Game.earn(gold: 5, xp: 10)
    }

    private func deleteHabits(at offsets: IndexSet) {
        for index in offsets { context.delete(habits[index]) }
        try? context.save()
    }
}

/// One habit row: symbol, name, done-count and a coral "+" that earns reward.
private struct HabitRow: View {
    let habit: Habit
    var onTap: () -> Void

    @State private var bump = false
    @State private var showEarn = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: habit.symbol)
                .font(.headline)
                .foregroundStyle(Color.bg)
                .frame(width: 40, height: 40)
                .background(Color.acc, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                if showEarn {
                    Text("+5 G · +10 XP")
                        .font(.mono(10, weight: .medium))
                        .kerning(0.5)
                        .foregroundStyle(Color.acc)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer()

            Text("×\(habit.timesDone)")
                .font(.mono(15, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.sub)

            Button {
                tap()
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.bg)
                    .frame(width: 34, height: 34)
                    .background(Color.acc, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
        .scaleEffect(bump ? 1.04 : 1)
        .animation(.earth, value: bump)
        // One VoiceOver stop per row; the "+" button's tap still fires
        // from the combined element.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Log \(habit.name), adds five gold")
        .accessibilityValue("Completed \(habit.timesDone) times")
        .accessibilityHint("Also adds ten experience")
        // Mono count sits next to a fixed 34pt circular button; cap the top
        // of the Dynamic Type range so the row keeps its layout.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func tap() {
        Haptics.tap()
        onTap()
        bump = true
        withAnimation(.easeOut(duration: 0.2)) { showEarn = true }
        Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            bump = false
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeOut(duration: 0.3)) { showEarn = false }
        }
    }
}

/// Name a habit and pick one of eight calm symbols, then plant it.
private struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (String, String) -> Void

    @State private var name = ""
    @State private var symbol = HabitSymbol.choices[0]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(spacing: 24) {
            Text("PLANT A HABIT")
                .font(.display(26))
                .foregroundStyle(Color.ink)
                .padding(.top, 28)

            TextField("Habit name", text: $name)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(Color.ink)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(HabitSymbol.choices, id: \.self) { candidate in
                    symbolButton(candidate)
                }
            }

            Button {
                let trimmed = name.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                onSave(trimmed, symbol)
                dismiss()
            } label: {
                Text("SAVE HABIT")
                    .font(.display(20))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.acc, in: Capsule())
                    .foregroundStyle(Color.bg)
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

            Spacer()
        }
        .padding(24)
        // Fixed-height sheet with a compressed display title; cap the top
        // of the Dynamic Type range instead of letting content overflow it.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .presentationDetents([.height(420)])
        .presentationBackground(Color.bg)
    }

    private func symbolButton(_ candidate: String) -> some View {
        let isOn = symbol == candidate
        return Button {
            Haptics.tap()
            withAnimation(.spring(duration: 0.35)) { symbol = candidate }
        } label: {
            Image(systemName: candidate)
                .font(.headline)
                .foregroundStyle(isOn ? Color.bg : Color.sub)
                .frame(width: 52, height: 52)
                .background(isOn ? Color.acc : Color.white.opacity(0.05), in: Circle())
                .overlay(Circle().stroke(isOn ? Color.acc.opacity(0.6) : .clear, lineWidth: 1))
        }
        .accessibilityLabel(HabitSymbol.title(for: candidate))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
