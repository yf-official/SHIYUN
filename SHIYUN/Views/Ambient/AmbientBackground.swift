import SwiftUI

struct AmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var settings: AppSettings
    @ObservedObject var background: BackgroundService
    let poemID: String

    private var focalPoint: UnitPoint {
        let value = poemID.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        let x = 0.38 + Double(abs(value % 23)) / 100
        let y = 0.32 + Double(abs((value / 23) % 27)) / 100
        return UnitPoint(x: x, y: y)
    }

    var body: some View {
        ZStack {
            switch settings.backgroundMode {
            case .atmosphere:
                atmosphere
            case .color:
                settings.customBackgroundColor.color
            case .image:
                if let image = background.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                    Color.black.opacity(settings.backgroundImageDim)
                } else {
                    atmosphere
                }
            }
        }
        .clipped()
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 18), value: focalPoint)
    }

    private var atmosphere: some View {
        ZStack {
            SHIYUNTheme.resolvedBackground(for: colorScheme)
            RadialGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.12, green: 0.15, blue: 0.18).opacity(0.45), .clear]
                    : [Color.white.opacity(0.5), .clear],
                center: focalPoint,
                startRadius: 30,
                endRadius: 680
            )
        }
    }
}
