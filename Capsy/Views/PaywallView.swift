import SwiftUI
import StoreKit

/// One calm screen. No timers, no fake discounts, no guilt —
/// the paywall keeps the same voice as the rest of Capsy.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var plus = Plus.shared
    @State private var selectedID = Plus.yearlyID
    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    benefits
                    priceCards
                    legal
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            footer
        }
        .background(Color.bg.ignoresSafeArea())
        .onChange(of: plus.isPlus) { _, owned in
            if owned { dismiss() }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(Color.sub)
                    .padding(10)
                    .background(Color.white.opacity(0.06), in: Circle())
            }
            .accessibilityLabel("Close")
            .accessibilityHint("Dismisses without purchasing")
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.acc)
                        .frame(width: 16, height: 16)
                        .rotationEffect(.degrees(45))
                        .offset(y: i == 1 ? -6 : 0)
                }
            }
            .padding(.top, 8)
            .accessibilityHidden(true)
            Text("CAPSY PLUS")
                .font(.display(38))
                .foregroundStyle(Color.ink)
            Text("Everything unlocked. Forever calm.")
                .font(.mono(12, weight: .medium))
                .kerning(1.6)
                .foregroundStyle(Color.sub)
        }
        // Compressed display title over a fixed-width column; cap the top
        // of the Dynamic Type range so it keeps wrapping the same way.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("cube.fill", "Every body and every hat, unlocked")
            benefit("waveform.path.ecg", "Body insights from Apple Health")
            benefit("checkmark.seal.fill", "Unlimited calm habits")
            benefit("heart.fill", "And you keep a tiny quiet app alive")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefit(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.acc)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .foregroundStyle(Color.ink)
        }
        .accessibilityElement(children: .combine)
    }

    /// StoreKit configs only inject via an Xcode scheme, so the CI
    /// screenshot runner never gets real products — demo mode shows
    /// representative cards instead. Never used in a real session.
    private var isDemo: Bool {
        ProcessInfo.processInfo.arguments.contains("--demo")
    }

    private var priceCards: some View {
        VStack(spacing: 10) {
            if plus.products.isEmpty {
                if isDemo {
                    mockCard(name: "MONTHLY", price: "$2.99", badge: nil, id: Plus.monthlyID)
                    mockCard(name: "YEARLY", price: "$19.99", badge: "BEST VALUE", id: Plus.yearlyID)
                    mockCard(name: "LIFETIME", price: "$49.99", badge: "PAY ONCE", id: Plus.lifetimeID)
                } else {
                    Text(plus.isLoading ? "LOADING PRICES…" : "STORE UNAVAILABLE. TRY AGAIN LATER.")
                        .font(.mono(11, weight: .medium))
                        .kerning(1.4)
                        .foregroundStyle(Color.sub)
                        .padding(.vertical, 24)
                }
            }
            ForEach(plus.products, id: \.id) { product in
                priceCard(product)
            }
        }
        // Mono prices sit against fixed-padding capsule cards; cap the top
        // of the Dynamic Type range so badges never wrap over the price.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func mockCard(name: String, price: String, badge: String?, id: String) -> some View {
        let isSelected = selectedID == id
        return Button {
            Haptics.tap()
            withAnimation(.earth) { selectedID = id }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.display(16))
                        .foregroundStyle(Color.ink)
                    if let badge {
                        Text(badge)
                            .font(.mono(9, weight: .semibold))
                            .kerning(1.2)
                            .foregroundStyle(Color.acc)
                    }
                }
                Spacer()
                Text(price)
                    .font(.mono(17, weight: .medium))
                    .foregroundStyle(Color.ink)
            }
            .padding(16)
            .background(Color.white.opacity(isSelected ? 0.09 : 0.03),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.acc : Color.ink.opacity(0.12), lineWidth: 1.5))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([name, badge].compactMap { $0 }.joined(separator: ", "))
        .accessibilityValue(price)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func priceCard(_ product: Product) -> some View {
        let isSelected = selectedID == product.id
        let badge: String? = switch product.id {
        case Plus.yearlyID: "BEST VALUE"
        case Plus.lifetimeID: "PAY ONCE"
        default: nil
        }
        return Button {
            Haptics.tap()
            withAnimation(.earth) { selectedID = product.id }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.displayName.uppercased())
                        .font(.display(16))
                        .foregroundStyle(Color.ink)
                    if let badge {
                        Text(badge)
                            .font(.mono(9, weight: .semibold))
                            .kerning(1.2)
                            .foregroundStyle(Color.acc)
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.mono(17, weight: .medium))
                    .foregroundStyle(Color.ink)
            }
            .padding(16)
            .background(Color.white.opacity(isSelected ? 0.09 : 0.03),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.acc : Color.ink.opacity(0.12), lineWidth: 1.5))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([product.displayName, badge].compactMap { $0 }.joined(separator: ", "))
        .accessibilityValue(product.displayPrice)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var legal: some View {
        Text("Subscriptions renew until cancelled in Settings. Lifetime is a one-time purchase. Your data never leaves your device either way.")
            .font(.caption2)
            .foregroundStyle(Color.sub)
            .multilineTextAlignment(.center)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                guard let product = plus.products.first(where: { $0.id == selectedID }) else { return }
                busy = true
                Task {
                    let bought = await plus.purchase(product)
                    busy = false
                    if bought { Haptics.success() }
                }
            } label: {
                Text(busy ? "…" : "UNLOCK PLUS")
                    .font(.display(20))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.acc, in: Capsule())
                    .foregroundStyle(Color.bg)
            }
            .disabled(busy || (plus.products.isEmpty && !isDemo))
            .opacity(busy || (plus.products.isEmpty && !isDemo) ? 0.55 : 1)
            .accessibilityLabel("Unlock Plus")
            .accessibilityHint(busy ? "Purchase in progress" : "Buys the selected plan")
            // Compressed display label in a fixed-padding capsule; cap the
            // top of the Dynamic Type range so it never clips inside it.
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)

            Button {
                Task { await plus.restore() }
            } label: {
                Text("RESTORE PURCHASES")
                    .font(.mono(11, weight: .medium))
                    .kerning(1.4)
                    .foregroundStyle(Color.sub)
            }
            .accessibilityLabel("Restore purchases")
            .accessibilityHint("Restores a previous Plus purchase")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.bg)
    }
}
