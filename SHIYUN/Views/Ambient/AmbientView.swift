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
            .background(WindowActivityMonitor { isKeyWindow in
                if isKeyWindow {
                    scheduler.start()
                } else {
                    scheduler.stop()
                }
            })
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
        hideControlsTask = Task { @MainActor in
            while !Task.isCancelled {
                let elapsed = ProcessInfo.processInfo.systemUptime - controlActivity.lastInputTime
                let remaining = max(0.1, 3.2 - elapsed)
                try? await Task.sleep(for: .seconds(remaining))
                guard !Task.isCancelled else { return }
                let idleTime = ProcessInfo.processInfo.systemUptime - controlActivity.lastInputTime
                if idleTime >= 3.2, !controlActivity.pointerOverControls, controlsVisible {
                    controlsVisible = false
                    hideControlsTask = nil
                    return
                }
            }
        }
    }

    private func toggleFullscreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
        controlsVisible = false
    }
}

/// Reports whether the ambient window is the active key window. Playback is
/// paused while Settings, Favorites, or another app is in front so the hidden
/// poem view does not keep scheduling transitions or rendering animations.
private struct WindowActivityMonitor: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ActivityView {
        ActivityView(onChange: onChange)
    }

    func updateNSView(_ nsView: ActivityView, context: Context) {
        nsView.onChange = onChange
        nsView.reportIfNeeded()
    }

    final class ActivityView: NSView {
        var onChange: (Bool) -> Void
        private var observers: [NSObjectProtocol] = []
        private var lastValue: Bool?

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeObservers()
            lastValue = nil
            guard let window else { return }

            let center = NotificationCenter.default
            observers = [
                center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
                    self?.reportIfNeeded()
                },
                center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                    self?.reportIfNeeded()
                },
                center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                    self?.reportIfNeeded()
                }
            ]
            reportIfNeeded()
        }

        func reportIfNeeded() {
            let isKey = window?.isKeyWindow == true
            guard lastValue != isKey else { return }
            lastValue = isKey
            onChange(isKey)
        }

        private func removeObservers() {
            let center = NotificationCenter.default
            observers.forEach(center.removeObserver)
            observers.removeAll(keepingCapacity: false)
        }

        deinit {
            removeObservers()
        }
    }
}
