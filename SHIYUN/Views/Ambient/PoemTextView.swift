import SwiftUI

struct PoemTextView: View {
    let poem: Poem
    @ObservedObject var settings: AppSettings
    let availableSize: CGSize
    var forceLightText = false

    var body: some View {
        VStack(spacing: max(20, settings.fontSize * 0.48)) {
            if settings.layout == .horizontal {
                horizontalPoem
            } else {
                verticalPoem
            }
            attribution
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(poem.accessibilityText)
    }

    private var horizontalPoem: some View {
        VStack(alignment: .center, spacing: settings.fontSize * 0.32) {
            ForEach(Array(poem.text.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .tracking(settings.fontSize * 0.1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .font(SHIYUNTheme.poetryFont(style: settings.fontStyle, size: responsiveFontSize))
        .foregroundStyle(poetryColor.opacity(0.92))
        .lineLimit(1)
    }

    private var verticalPoem: some View {
        HStack(alignment: .top, spacing: responsiveFontSize * 0.58) {
            ForEach(Array(poem.text.reversed().enumerated()), id: \.offset) { _, line in
                VStack(spacing: responsiveFontSize * 0.12) {
                    ForEach(Array(verticalCharacters(line).enumerated()), id: \.offset) { _, character in
                        Text(character)
                            .frame(width: responsiveFontSize * 1.1, height: responsiveFontSize * 1.08)
                    }
                }
            }
        }
        .font(SHIYUNTheme.poetryFont(style: settings.fontStyle, size: responsiveFontSize))
        .foregroundStyle(poetryColor.opacity(0.92))
    }

    @ViewBuilder private var attribution: some View {
        let parts = [
            settings.showDynasty ? poem.dynasty : nil,
            settings.showAuthor ? poem.author : nil,
            settings.showTitle ? "《\(poem.title)》" : nil
        ].compactMap { $0 }
        if !parts.isEmpty {
            Text("—  " + parts.joined(separator: " · "))
                .font(SHIYUNTheme.poetryFont(style: settings.fontStyle, size: 13))
                .tracking(1.2)
                .foregroundStyle(poetryColor.opacity(0.68))
                .transition(.opacity)
        }
    }

    private var responsiveFontSize: Double {
        let scale = min(max(availableSize.width / 1100, 0.72), 1.35)
        return min(96, max(28, settings.fontSize * scale))
    }

    private var poetryColor: Color {
        if !settings.automaticPoetryColor { return settings.customPoetryColor.color }
        return forceLightText ? .white : .primary
    }

    private func verticalCharacters(_ line: String) -> [String] {
        line.map { character in
            switch character {
            case "，": return "︐"
            case "。": return "︒"
            case "、": return "︑"
            case "；": return "︔"
            case "：": return "︓"
            case "！": return "︕"
            case "？": return "︖"
            default: return String(character)
            }
        }
    }
}
