import SwiftUI

struct AboutView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 14) {
            Image("SHIYUNLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .accessibilityLabel("SHIYUN")
            Text("SHIYUN")
                .font(.system(size: 24, weight: .medium, design: .serif))
                .tracking(5)
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(settings.text("让诗句，在屏幕上自然发生。", "Let poetry quietly unfold."))
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

