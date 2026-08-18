#if canImport(UnlockBriefingCore)
import UnlockBriefingCore
#endif
import SwiftUI

enum CardSurface {
    case window
    case hud

    var isElevated: Bool { self == .hud }
}

struct CardColors {
    let fill: Color
    let border: Color
    let text: Color
    let accent: Color
}

enum BriefingCardPalette {
    static func hex(_ value: String, opacity: Double = 1) -> Color {
        let trimmed = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        return Color(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    static func todo(_ priority: TodoPriority, surface: CardSurface, darkWindow: Bool) -> CardColors {
        let dark = surface.isElevated || darkWindow
        let fillOpacity = dark ? 0.72 : 0.86
        switch priority {
        case .high:
            return CardColors(
                fill: hex("FEE2E2", opacity: fillOpacity),
                border: hex("DC2626", opacity: dark ? 0.78 : 0.48),
                text: hex("9F1239"),
                accent: hex("EF4444")
            )
        case .medium:
            return CardColors(
                fill: hex("FEF3C7", opacity: fillOpacity),
                border: hex("D97706", opacity: dark ? 0.80 : 0.50),
                text: hex("92400E"),
                accent: hex("F59E0B")
            )
        case .low:
            return CardColors(
                fill: hex("DCFCE7", opacity: fillOpacity),
                border: hex("16A34A", opacity: dark ? 0.78 : 0.48),
                text: hex("166534"),
                accent: hex("22C55E")
            )
        }
    }

    static func band(_ band: CountdownColorBand, surface: CardSurface, darkWindow: Bool, fillOpacity: Double) -> CardColors {
        let dark = surface.isElevated || darkWindow
        let base = (dark ? 0.68 : 0.84) * fillOpacity
        switch band {
        case .green:
            return CardColors(
                fill: hex("D1FAE5", opacity: base),
                border: hex("059669", opacity: dark ? 0.78 : 0.48),
                text: hex("065F46"),
                accent: hex("10B981")
            )
        case .yellow:
            return CardColors(
                fill: hex("FEF9C3", opacity: base),
                border: hex("D97706", opacity: dark ? 0.80 : 0.50),
                text: hex("854D0E"),
                accent: hex("F59E0B")
            )
        case .orange:
            return CardColors(
                fill: hex("FFEDD5", opacity: base),
                border: hex("EA580C", opacity: dark ? 0.80 : 0.50),
                text: hex("9A3412"),
                accent: hex("F97316")
            )
        case .red:
            return CardColors(
                fill: hex("FEE2E2", opacity: base),
                border: hex("DC2626", opacity: dark ? 0.80 : 0.50),
                text: hex("9F1239"),
                accent: hex("EF4444")
            )
        }
    }
}

extension View {
    func briefingCardSurface(fill: Color, border: Color) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
    }
}

struct TodoCardView: View {
    let item: TodoItem
    let index: Int
    let total: Int
    let surface: CardSurface
    var darkWindow: Bool = false
    var showsHandle: Bool = false

    var body: some View {
        let colors = BriefingCardPalette.todo(item.priority, surface: surface, darkWindow: darkWindow)
        HStack(alignment: .top, spacing: 10) {
            if showsHandle {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(colors.text.opacity(0.55))
                    .padding(.top, 2)
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(colors.accent)
                .frame(width: 4)
            Text(item.text)
                .font(surface == .hud ? .custom("PingFang SC", size: 16) : .body)
                .foregroundColor(colors.text)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.priority.label)
                .font(.caption.weight(.semibold))
                .foregroundColor(colors.text.opacity(0.8))
        }
        .padding(12)
        .briefingCardSurface(fill: colors.fill, border: colors.border)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("待办，优先级\(item.priority.label)，第 \(index + 1) / \(total)")
    }
}

struct CountdownCardView: View {
    let card: CountdownPresentation
    let appearance: CountdownAppearanceMode
    let surface: CardSurface
    var darkWindow: Bool = false

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.item.title)
                    .font(surface == .hud ? .custom("PingFang SC", size: 16).weight(.medium) : .headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(card.remainingLabel)
                    .font(.subheadline.weight(.semibold))
            }
            Text(card.item.date)
                .font(.caption)
                .opacity(0.75)
        }
        .padding(12)

        Group {
            switch appearance {
            case .off:
                content
                    .foregroundColor(surface.isElevated || darkWindow ? .white : .primary)
                    .briefingCardSurface(fill: neutralTrack, border: neutralBorder)
            case .remainingDays:
                let colors = BriefingCardPalette.band(card.remainingDaysBand, surface: surface, darkWindow: darkWindow, fillOpacity: 1)
                content
                    .foregroundColor(colors.text)
                    .briefingCardSurface(fill: colors.fill, border: colors.border)
            case .progressFill:
                if card.isExpired {
                    let colors = BriefingCardPalette.band(.red, surface: surface, darkWindow: darkWindow, fillOpacity: 1)
                    content
                        .foregroundColor(colors.text)
                        .briefingCardSurface(fill: colors.fill, border: colors.border)
                } else {
                    progressBody(content)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.item.title)，\(card.remainingLabel)")
    }

    private var isDarkChrome: Bool { surface.isElevated || darkWindow }

    private var neutralTrack: Color {
        isDarkChrome ? Color.white.opacity(0.08) : Color.black.opacity(0.045)
    }

    private var neutralBorder: Color {
        isDarkChrome ? Color.white.opacity(0.18) : Color.black.opacity(0.10)
    }

    private func progressBody<Content: View>(_ content: Content) -> some View {
        let colors = BriefingCardPalette.band(card.progressBand, surface: surface, darkWindow: darkWindow, fillOpacity: fillOpacity)
        return content
            .foregroundColor(colors.text)
            .background(
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(neutralTrack)
                        colors.fill
                            .frame(width: max(0, geo.size.width * card.progress))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(colors.border, lineWidth: 1)
            )
    }

    private var fillOpacity: Double {
        switch card.progressBand {
        case .green: return 0.88
        case .yellow, .orange: return 0.90
        case .red: return 0.92
        }
    }
}

struct BriefingSectionsView: View {
    let presentation: BriefingPresentation
    let appearance: CountdownAppearanceMode
    let surface: CardSurface
    var darkWindow: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(presentation.greetingLine)
                .font(surface == .hud ? .custom("PingFang SC", size: 18).weight(.semibold) : .title3.weight(.semibold))
                .foregroundColor(surface == .hud ? .white : .primary)
            if !presentation.isEmpty {
                if !presentation.todos.isEmpty {
                    sectionTitle("今日待办")
                    ForEach(Array(presentation.todos.enumerated()), id: \.offset) { index, item in
                        TodoCardView(
                            item: item,
                            index: index,
                            total: presentation.todos.count,
                            surface: surface,
                            darkWindow: darkWindow
                        )
                    }
                }
                if !presentation.countdowns.isEmpty {
                    sectionTitle("关键倒计时")
                    ForEach(Array(presentation.countdowns.enumerated()), id: \.offset) { _, card in
                        CountdownCardView(card: card, appearance: appearance, surface: surface, darkWindow: darkWindow)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(surface == .hud ? Color.white.opacity(0.7) : .secondary)
    }
}
