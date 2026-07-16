import WidgetKit
import SwiftUI

// MARK: - Timeline

struct BucketEntry: TimelineEntry {
    let date: Date
    let fraction: Double
    let line: String
}

struct BucketProvider: TimelineProvider {
    func placeholder(in context: Context) -> BucketEntry {
        BucketEntry(date: .now, fraction: 0.4, line: "Kaupiasi…")
    }

    func getSnapshot(in context: Context, completion: @escaping (BucketEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BucketEntry>) -> Void) {
        // The app reloads timelines on every change, so one entry is enough.
        completion(Timeline(entries: [current()], policy: .never))
    }

    private func current() -> BucketEntry {
        BucketEntry(date: .now, fraction: SharedState.fillFraction, line: SharedState.stateLine)
    }
}

// MARK: - Views

private let mossColor = Color(red: 0.055, green: 0.082, blue: 0.071)
private let liquidColor = Color(red: 0.373, green: 0.831, blue: 0.769)
private let sandColor = Color(red: 0.910, green: 0.863, blue: 0.784)
private let stoneColor = Color(red: 0.478, green: 0.545, blue: 0.522)

struct CapsyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BucketEntry

    private var percent: Int { Int(entry.fraction * 100) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.fraction) {
                Image(systemName: "drop.fill")
            } currentValueLabel: {
                Text("\(percent)")
            }
            .gaugeStyle(.accessoryCircular)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                Text("Capsy · \(percent) %")
                    .font(.headline)
                Text(entry.line)
                    .font(.caption)
                Gauge(value: entry.fraction) { EmptyView() }
                    .gaugeStyle(.accessoryLinear)
            }

        default: // .systemSmall — a mini transparent bucket
            VStack(spacing: 8) {
                Text("\(percent) %")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(sandColor)
                ZStack(alignment: .bottom) {
                    WaveShape(fraction: entry.fraction)
                        .fill(liquidColor.gradient)
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(sandColor.opacity(0.35), lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(entry.line)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(stoneColor)
                    .lineLimit(1)
            }
        }
    }
}

/// Static frozen wave for the small widget.
struct WaveShape: Shape {
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let surface = rect.height * (1 - fraction * 0.94)
        path.move(to: CGPoint(x: 0, y: surface))
        let steps = 24
        for i in 0...steps {
            let u = Double(i) / Double(steps)
            let y = surface + sin(u * .pi * 2.6) * rect.height * 0.02
            path.addLine(to: CGPoint(x: rect.width * u, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Widget

@main
struct CapsyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CapsyWidget", provider: BucketProvider()) { entry in
            CapsyWidgetView(entry: entry)
                .containerBackground(for: .widget) { mossColor }
        }
        .configurationDisplayName("Capsy kibirėlis")
        .description("Tavo streso lygis vienu žvilgsniu.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}
