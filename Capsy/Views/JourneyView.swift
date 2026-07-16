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
        .background(Color.moss.ignoresSafeArea())
        .fontDesign(.rounded)
        .navigationTitle("Ramybės kelias")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Journey milestones

    private var journeySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Išleidimų: \(sessions.count)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.sand)

            ForEach(Journey.milestones) { milestone in
                let reached = sessions.count >= milestone.releases
                HStack(spacing: 14) {
                    Image(systemName: milestone.symbol)
                        .font(.headline)
                        .foregroundStyle(reached ? Color.moss : Color.stone)
                        .frame(width: 40, height: 40)
                        .background(reached ? Color.liquid : Color.white.opacity(0.05),
                                    in: Circle())
                    Text(milestone.title)
                        .foregroundStyle(reached ? Color.sand : Color.stone)
                    Spacer()
                    Text("\(min(sessions.count, milestone.releases))/\(milestone.releases)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.stone)
                }
            }
        }
    }

    // MARK: - 7 day chart

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
            Text("Savaitė")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.sand)

            Chart(week) { load in
                BarMark(x: .value("Diena", load.day, unit: .day),
                        y: .value("Krūvis", load.units))
                .foregroundStyle(Color.liquid.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                        .foregroundStyle(Color.stone)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel().foregroundStyle(Color.stone)
                }
            }
            .frame(height: 160)
        }
    }

    // MARK: - Recent drops

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Paskutiniai lašai")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.sand)

            if drops.isEmpty {
                Text("Kol kas tuščia. Ir tegul taip lieka.")
                    .foregroundStyle(Color.stone)
            }

            ForEach(drops.prefix(10)) { drop in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.liquid.opacity(0.3 + Double(drop.intensity) * 0.23))
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(drop.note.isEmpty
                             ? (Intensity(rawValue: drop.intensity)?.title ?? "Lašas")
                             : drop.note)
                            .foregroundStyle(Color.sand)
                            .lineLimit(1)
                        Text(drop.date, format: .relative(presentation: .named))
                            .font(.caption)
                            .foregroundStyle(Color.stone)
                    }
                    Spacer()
                    if drop.released {
                        Image(systemName: "wind")
                            .font(.caption)
                            .foregroundStyle(Color.stone.opacity(0.6))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
