import WidgetKit
import SwiftUI
import UIKit
import AppIntents

// MARK: - One-tap drop from the widget (works on Home Screen and StandBy)

/// Logs one light stress drop without opening the app: bumps the shared
/// fill immediately so the widget reacts, and queues the drop for the app
/// to absorb into SwiftData on next launch/foreground.
struct QuickDropIntent: AppIntent {
    static var title: LocalizedStringResource = "Add a drop"
    static var description = IntentDescription("Drops one light stress drop into Capsy.")

    func perform() async throws -> some IntentResult {
        SharedState.pendingQuickDrops += 1
        let fraction = min(1.0, SharedState.fillFraction + 2.0 / 24.0)
        SharedState.fillFraction = fraction
        SharedState.stateLine = SharedState.line(for: fraction)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Timeline

struct BucketEntry: TimelineEntry {
    let date: Date
    let fraction: Double
    let line: String
}

struct BucketProvider: TimelineProvider {
    func placeholder(in context: Context) -> BucketEntry {
        BucketEntry(date: .now, fraction: 0.4, line: "FILLING UP…")
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

// Gyva tyla V4.5 paletė (diena/naktis — seka sistemos šviesumą).
private func dyn(_ day: UInt32, _ night: UInt32) -> Color {
    func ui(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(night) : ui(day) })
}
private let bgColor  = dyn(0xEDE4D6, 0x191511)
private let accColor = dyn(0xE8865C, 0xF0A06E)
private let inkColor = dyn(0x2B2620, 0xEDE4D6)
private let subColor = dyn(0x8A7E6E, 0x9C8F7D)

struct CapsyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BucketEntry

    private var percent: Int { Int(entry.fraction * 100) }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Capsy \(percent) %")

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

        default: // .systemSmall — a mini transparent vessel with a one-tap drop
            VStack(spacing: 6) {
                HStack {
                    Text("\(percent) %")
                        .font(.system(.title2, design: .monospaced, weight: .semibold))
                        .foregroundStyle(inkColor)
                    Spacer()
                    // One tap = one light drop, right from the Home Screen.
                    Button(intent: QuickDropIntent()) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(bgColor)
                            .frame(width: 26, height: 26)
                            .background(accColor, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                ZStack(alignment: .bottom) {
                    WaveShape(fraction: entry.fraction)
                        .fill(accColor.gradient)
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(inkColor.opacity(0.35), lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(entry.line)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(subColor)
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
                .containerBackground(for: .widget) { bgColor }
        }
        .configurationDisplayName("Capsy")
        .description("Your stress level at a glance — plus a one-tap drop.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}
