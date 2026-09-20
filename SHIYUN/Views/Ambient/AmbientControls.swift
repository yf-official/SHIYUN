import AppKit
import SwiftUI

struct AmbientControls: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings
    let toggleFullscreen: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            controlButton(
                systemName: model.favorites.contains(model.scheduler.current) ? "heart.fill" : "heart",
                label: model.settings.text("收藏", "Favorite")
            ) { model.favorites.toggle(model.scheduler.current) }

            controlButton(systemName: "arrow.right", label: model.settings.text("下一句", "Next")) {
                model.scheduler.next()
            }

            controlButton(systemName: model.settings.layout == .horizontal ? "textformat" : "character.book.closed", label: model.settings.text("切换排版", "Change Layout")) {
                model.settings.layout = model.settings.layout == .horizontal ? .vertical : .horizontal
            }

            controlButton(systemName: "gearshape", label: model.settings.text("设置", "Settings")) {
                openSettings()
            }

            controlButton(systemName: "arrow.up.left.and.arrow.down.right", label: model.settings.text("全屏", "Full Screen")) {
                toggleFullscreen()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .accessibilityElement(children: .contain)
    }

    private func controlButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .regular))
                .frame(width: 30, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary.opacity(0.76))
        .help(label)
        .accessibilityLabel(label)
    }
}

