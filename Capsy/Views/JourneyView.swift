import SwiftUI
import SwiftData
import Charts

/// The quiet history screen: journey milestones, a 7-day chart and recent drops.
struct JourneyView: View {
    @Query(sort: \StressDrop.date, order: .reverse) private var drops: [StressDrop]
    @Query private var sessions: [ReleaseSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                journeySection
                chartSection
                recentSection
            }
            .padding(24)
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("Path of Stillness")
    }

    // MARK: - Journey milestones

    private var journeySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Mono tabular numerals — the design book's "SODAS 000" counter.
            Text("GARDEN \(String(format: "%03d", sessions.count))")
                .font(.mono(20, weight: .medium))
                .kerning(2)
                .foregroundStyle(Color.ink)

            if sessions.isEmpty {
                Text("THE FIRST STONE AWAITS.")
                    .font(.mono(11, weight: .regular))
                    .kerning(1.5)
                    .foregroundStyle(Color.sub)
            } else {
                GardenView(count: sessions.count)
                    .frame(maxWidth: .infinity)
                    .frame(height: 130)
            }

            ForEach(Journey.milestones) { milestone in
                let reached = sessions.count >= milestone.releases
                HStack(spacing: 14) {
                    Image(systemName: milestone.symbol)
                        .font(.headline)
                        .foregroundStyle(reached ? Color.bg : Color.sub)
                        .frame(width: 40, height: 40)
                        .background(reached ? Color.acc : Color.white.opacity(0.05),
                                    in: Circle())
                    Text(milestone.title)
                        .foregroundStyle(reached ? Color.ink : Color.sub)
                    Spacer()
                    Text("\(min(sessions.count, milestone.releases))/\(milestone.releases)")
                        .font(.mono(13, weight: .medium))
                        .foregroundStyle(Color.sub)
                }
            }
        }
    }

    // MARK: - 7 day chart

    /// Ramybės sodas: kiekvienas išleidimas — akmenukas aukso kampo spiralėje.
    /// Kas trečias tyliai išauga voxel formos — be pranešimų, tik pastebėjusiems.
    private struct GardenView: View {
        let count: Int

        var body: some View {
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0..<count {
                    let angle = Double(i) * 2.399963 // aukso kampas
                    let radius = 12 + Double(i) * 5.5
                    let p = CGPoint(x: center.x + cos(angle) * radius,
                                    y: center.y + sin(angle) * radius * 0.55)
                    let s = 8.0
                    if i % 3 == 2 {
                        for k in 0..<4 {
                            let b = s * 0.5
                            let off = CGPoint(x: Double(k % 2) * b - b / 2 - b * 0.3,
                                              y: Double(k / 2) * b * 0.9 - b / 2)
                            ctx.fill(Path(roundedRect: CGRect(x: p.x + off.x, y: p.y + off.y,
                                                              width: b * 0.9, height: b * 0.9),
                                          cornerRadius: 1),
                                     with: .color(.sub.opacity(0.85)))
                        }
                    } else {
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - s / 2, y: p.y - s * 0.4,
                                                        width: s, height: s * 0.8)),
                                 with: .color(.sub))
                    }
                }
            }
        }
    }

    private struct DayLoad: Identifiable {
        let day: Date
        let units: Int
        var id: Date { day }
    }

    private var week: [DayLoad] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let units = drops
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .map(\.units)
                .reduce(0, +)
            return DayLoad(day: day, units: units)
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("The Week")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.ink)

            Chart(week) { load in
                BarMark(x: .value("Day", load.day, unit: .day),
                        y: .value("Load", load.units))
                .foregroundStyle(Color.acc.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                        .foregroundStyle(Color.sub)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel().foregroundStyle(Color.sub)
                }
            }
            .frame(height: 160)
        }
    }

    // MARK: - Recent drops

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Drops")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.ink)

            if drops.isEmpty {
                Text("Nothing yet. May it stay that way.")
                    .foregroundStyle(Color.sub)
            }

            ForEach(drops.prefix(10)) { drop in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.acc.opacity(0.3 + Double(drop.intensity) * 0.23))
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(drop.note.isEmpty
                             ? (Intensity(rawValue: drop.intensity)?.title ?? "Drop")
                             : drop.note)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                        Text(drop.date, format: .relative(presentation: .named))
                            .font(.caption)
                            .foregroundStyle(Color.sub)
                    }
                    Spacer()
                    if drop.released {
                        Image(systemName: "wind")
                            .font(.caption)
                            .foregroundStyle(Color.sub.opacity(0.6))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
