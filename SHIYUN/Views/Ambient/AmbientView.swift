import AppKit
import SwiftUI

private final class ControlActivity {
    var lastInputTime = ProcessInfo.processInfo.systemUptime
    var pointerOverControls = false
}

struct AmbientView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var scheduler: PoetryScheduler
    @ObservedObject private var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var controlActivity = ControlActivity()

    init(model: AppModel) {
        self.model = model
        _scheduler = ObservedObject(wrappedValue: model.scheduler)
        _settings = ObservedObject(wrappedValue: model.settings)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AmbientBackground(settings: settings, background: model.background, poemID: scheduler.current.id)

                PoemTextView(
                    poem: scheduler.current,
                    settings: settings,
                    availableSize: geometry.size,
                    forceLightText: settings.backgroundMode == .image && model.background.image != nil
                )
                    .contentTransition(.identity)
                    .opacity(scheduler.poemOpacity)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .animation(.easeInOut(duration: reduceMotion ? 1.2 : 3), value: scheduler.poemOpacity)

                VStack {
                    Spacer()
                    AmbientControls(model: model, toggleFullscreen: toggleFullscreen)
                        .opacity(controlsVisible ? 1 : 0)
                        .offset(y: controlsVisible ? 0 : 8)
                        .allowsHitTesting(controlsVisible)
                        .onHover { inside in
                            controlActivity.pointerOverControls = inside
                            if inside { recordPointerActivity() }
                        }
                        .animation(.easeOut(duration: 0.45), value: controlsVisible)
                        .padding(.bottom, 24)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { recordPointerActivity() }
            .onContinuousHover { phase in
                if case .active = phase { recordPointerActivity() }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .environment(\.colorScheme, settings.resolvedColorScheme(system: systemColorScheme))
        .shiyunWindowAppearance(settings.appearance)
        .onKeyPress(.rightArrow) { scheduler.next(); revealControls(); return .handled }
        .onKeyPress(.space) { scheduler.next(); return .handled }
        .onAppear {
            scheduler.start()
            startControlVisibilityMonitor()
        }
        .onDisappear {
            hideControlsTask?.cancel()
            hideControlsTask = nil
            scheduler.stop()
        }
    }

    private func revealControls() {
        recordPointerActivity()
    }

    private func recordPointerActivity() {
        controlActivity.lastInputTime = ProcessInfo.processInfo.systemUptime
        if !controlsVisible { controlsVisible = true }
    }

    private func startControlVisibilityMonitor() {
        hideControlsTask?.cancel()
        controlActivity.lastInputTime = ProcessInfo.processInfo.systemUptime
        hideControlsTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                let idleTime = ProcessInfo.processInfo.systemUptime - controlActivity.lastInputTime
                if idleTime >= 3.2, !controlActivity.pointerOverControls, controlsVisible {
                    controlsVisible = false
                }
            }
        }
    }

    private func toggleFullscreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
        controlsVisible = false
    }
}
