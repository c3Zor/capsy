import SwiftUI

/// REWARDS — spend gold earned from habits and rituals on new vessel bodies
/// and hats. Calm and premium: no wheel spins, no confetti, just clear
/// affordances (owned / equipped / affordable / too expensive).
struct ShopView: View {
    // Mirrors Game.gold — AppStorage observes the same UserDefaults key,
    // so the header refreshes automatically whenever Game.earn/spend/buy runs.
    @AppStorage("gold") private var gold = 0
    @AppStorage("vesselStyle") private var vesselRaw = VesselStyle.kibiras.rawValue
    @AppStorage("hat") private var hatRaw = ""

    /// Item id currently mid-pulse after a fresh purchase.
    @State private var pulsingID: String?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                section(title: "BODIES", items: bodyItems)
                section(title: "HATS", items: hatItems)
            }
            .padding(24)
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("Rewards")
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR GOLD")
                .font(.mono(11.5, weight: .medium))
                .kerning(1.8)
                .foregroundStyle(Color.sub)
            HStack(spacing: 10) {
                CoinGlyph(size: 22)
                Text("\(gold) g")
                    .font(.mono(40, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                    .contentTransition(.numericText())
                    .animation(.earth, value: gold)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Sections

    private func section(title: String, items: [ShopItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.mono(13, weight: .medium))
                .kerning(2)
                .foregroundStyle(Color.sub)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(items) { item in
                    RewardCard(
                        item: item,
                        isEquipped: isEquipped(item),
                        isOwned: isOwned(item),
                        gold: gold,
                        isPulsing: pulsingID == item.id,
                        onEquip: { equip(item) },
                        onBuy: { buy(item) }
                    )
                }
            }
        }
    }

    // MARK: - Item lists

    private var bodyItems: [ShopItem] {
        var items = [ShopItem(id: "vessel.kibiras", name: "Bucket", symbol: "cube",
                               price: 0, kind: .vessel, alwaysOwned: true)]
        items += Reward.catalog
            .filter { $0.kind == .vessel }
            .map { ShopItem(id: $0.id, name: $0.name, symbol: $0.symbol,
                             price: $0.price, kind: .vessel, alwaysOwned: false) }
        return items
    }

    private var hatItems: [ShopItem] {
        var items = [ShopItem(id: "hat.none", name: "No Hat", symbol: "circle.slash",
                               price: 0, kind: .hat, alwaysOwned: true)]
        items += Reward.catalog
            .filter { $0.kind == .hat }
            .map { ShopItem(id: $0.id, name: $0.name, symbol: $0.symbol,
                             price: $0.price, kind: .hat, alwaysOwned: false) }
        return items
    }

    // MARK: - State helpers

    private func isOwned(_ item: ShopItem) -> Bool {
        item.alwaysOwned || Game.owns(item.id)
    }

    private func isEquipped(_ item: ShopItem) -> Bool {
        switch item.kind {
        case .vessel:
            return item.id == "vessel.\(vesselRaw)"
        case .hat:
            return item.id == "hat.none" ? hatRaw.isEmpty : hatRaw == item.id
        }
    }

    private func equip(_ item: ShopItem) {
        Haptics.tap()
        switch item.kind {
        case .vessel:
            let style = String(item.id.dropFirst("vessel.".count))
            withAnimation(.spring(duration: 0.4)) { vesselRaw = style }
        case .hat:
            withAnimation(.spring(duration: 0.4)) { hatRaw = item.id == "hat.none" ? "" : item.id }
        }
    }

    private func buy(_ item: ShopItem) {
        guard Game.buy(item.id, price: item.price) else { return }
        Haptics.success()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) { pulsingID = item.id }
        Task {
            try? await Task.sleep(nanoseconds: 260_000_000)
            await MainActor.run {
                withAnimation(.earth) { pulsingID = nil }
            }
        }
    }
}

// MARK: - Shop item (view model over Reward + the always-free defaults)

private struct ShopItem: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let price: Int
    let kind: Reward.Kind
    let alwaysOwned: Bool
}

// MARK: - Reward card

private struct RewardCard: View {
    let item: ShopItem
    let isEquipped: Bool
    let isOwned: Bool
    let gold: Int
    let isPulsing: Bool
    let onEquip: () -> Void
    let onBuy: () -> Void

    private var canAfford: Bool { gold >= item.price }
    private var missing: Int { max(0, item.price - gold) }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: item.symbol)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 56, height: 56)
                    .background(iconBackground, in: Circle())

                if isEquipped {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.acc)
                        .background(Color.bg, in: Circle())
                        .offset(x: 4, y: -4)
                }
            }

            Text(item.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isOwned ? Color.ink : Color.ink.opacity(canAfford ? 1 : 0.55))
                .lineLimit(1)

            footer
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .stroke(isEquipped ? Color.acc.opacity(0.6) : .clear, lineWidth: 1.5))
        .opacity(isOwned || canAfford ? 1 : 0.55)
        .scaleEffect(isPulsing ? 1.06 : 1.0)
    }

    @ViewBuilder
    private var footer: some View {
        if isEquipped {
            Text("EQUIPPED")
                .font(.mono(10, weight: .medium))
                .kerning(1.2)
                .foregroundStyle(Color.acc)
        } else if isOwned {
            Button(action: onEquip) {
                Text("WEAR")
                    .font(.mono(11, weight: .medium))
                    .kerning(1.2)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Capsule().stroke(Color.sub, lineWidth: 1.2))
            }
        } else if canAfford {
            Button(action: onBuy) {
                HStack(spacing: 4) {
                    Text("BUY")
                    CoinGlyph(size: 9)
                    Text("\(item.price)")
                        .monospacedDigit()
                }
                .font(.mono(11, weight: .medium))
                .kerning(1)
                .foregroundStyle(Color.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.acc, in: Capsule())
            }
        } else {
            Text("NEED \(missing) MORE")
                .font(.mono(10, weight: .medium))
                .kerning(1)
                .foregroundStyle(Color.sub)
        }
    }

    private var iconColor: Color {
        if isEquipped { return Color.bg }
        if isOwned { return Color.acc }
        return canAfford ? Color.sub : Color.sub.opacity(0.6)
    }

    private var iconBackground: Color {
        isEquipped ? Color.acc : Color.white.opacity(0.05)
    }

    private var cardBackground: Color {
        Color.white.opacity(isEquipped ? 0.08 : 0.03)
    }
}

// MARK: - Coin glyph — a tiny voxel cube, gyva-tyla style

private struct CoinGlyph: View {
    var size: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.18)
            .fill(Color.acc.gradient)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(45))
    }
}

#Preview {
    NavigationStack {
        ShopView()
    }
}
