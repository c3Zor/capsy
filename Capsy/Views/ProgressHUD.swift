import SwiftUI
import SwiftData

// MARK: - ProgressHUD
//
// One-line gamification strip for the home screen: level, XP capsule, gold.
// Reads the GameState row via @Query so it live-updates the instant
// Game.earn(...) mutates the database, no matter where the call came from.

struct ProgressHUD: View {
    @Query private var states: [GameState]

    private var gold: Int { states.first?.gold ?? 0 }
    private var xp: Int { states.first?.xp ?? 0 }
    private var level: Int { xp / 100 + 1 }
    private var progress: Double { min(1, max(0, Double(xp % 100) / 100)) }

    var body: some View {
        HStack(spacing: 12) {
            Text("LVL \(level)")
                .font(.display(13))
                .foregroundStyle(Color.ink)
                .fixedSize()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(Color.acc)
                        .frame(width: max(4, geo.size.width * progress))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 6)
            .animation(.earth, value: progress)

            HStack(spacing: 5) {
                // Tiny voxel coin — a single blocky pixel, gyva-tyla style.
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.acc)
                    .frame(width: 9, height: 9)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.accDeep, lineWidth: 1)
                    )
                Text("\(gold)")
                    .font(.mono(13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                    .contentTransition(.numericText())
            }
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(Color.lino, in: Capsule())
        .animation(.earth, value: gold)
    }
}

// MARK: - DailyQuestCard
//
// One quiet daily quest: finish a breathing ritual today, claim 20 gold.
// State machine: no ritual yet → pending · ritual done, unclaimed → claim
// button · claimed → a single quiet line. Date-key logic is self-contained
// so no other file needs to know its UserDefaults key shape.

struct DailyQuestCard: View {
    @Query private var sessions: [ReleaseSession]

    @State private var claimed = false

    private var todayCount: Int {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDateInToday($0.date) }.count
    }

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "questClaimed-\(formatter.string(from: .now))"
    }

    var body: some View {
        Group {
            if todayCount == 0 {
                pendingRow
            } else if !claimed {
                claimRow
            } else {
                doneRow
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(Color.lino, in: RoundedRectangle(cornerRadius: 18))
        .onAppear { claimed = UserDefaults.standard.bool(forKey: todayKey) }
    }

    private var pendingRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 19))
                .foregroundStyle(Color.sub.opacity(0.55))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text("TODAY'S QUEST")
                    .font(.mono(10, weight: .medium))
                    .kerning(1.6)
                    .foregroundStyle(Color.sub)
                Text("One breathing ritual. Reward: 20 g")
                    .font(.subheadline)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var claimRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 19))
                .foregroundStyle(Color.acc)
                .frame(width: 30)
            Text("QUEST COMPLETE")
                .font(.mono(10, weight: .medium))
                .kerning(1.6)
                .foregroundStyle(Color.sub)
            Spacer(minLength: 0)
            Button {
                Haptics.success()
                Game.earn(gold: 20, xp: 0)
                UserDefaults.standard.set(true, forKey: todayKey)
                withAnimation(.earth) { claimed = true }
            } label: {
                Text("CLAIM 20 g")
                    .font(.display(14))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.acc, in: Capsule())
                    .foregroundStyle(Color.bg)
            }
        }
    }

    private var doneRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundStyle(Color.sub)
                .frame(width: 30)
            Text("QUEST DONE. THE GARDEN GREW.")
                .font(.mono(11, weight: .regular))
                .kerning(1.2)
                .foregroundStyle(Color.sub)
            Spacer(minLength: 0)
        }
    }
}
