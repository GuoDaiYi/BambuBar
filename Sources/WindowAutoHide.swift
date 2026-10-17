import SwiftUI
import AppKit

/// Closes only the main menu-bar panel after 10 seconds of inactivity, or when
/// the user activates another window. Settings and sheets are left alone.
struct MainWindowAutoHide: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        content.background(
            WindowAutoHideObserver(enabled: enabled)
                .frame(width: 0, height: 0)
        )
    }
}

private struct WindowAutoHideObserver: NSViewRepresentable {
    var enabled: Bool

    func makeNSView(context: Context) -> ObserverView {
        ObserverView(enabled: enabled)
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {
        nsView.enabled = enabled
    }

    final class ObserverView: NSView {
        var enabled: Bool {
            didSet {
                if enabled { restartTimer() } else { stopTimer() }
            }
        }

        private weak var hostWindow: NSWindow?
        private var timer: Timer?
        private var eventMonitor: Any?
        private var observers: [NSObjectProtocol] = []
        private var menuOpen = false

        init(enabled: Bool) {
            self.enabled = enabled
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { return nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            detach()
            guard let window else { return }
            hostWindow = window

            let center = NotificationCenter.default
            observers.append(center.addObserver(
                forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                self?.restartTimer()
            })
            observers.append(center.addObserver(
                forName: NSWindow.didResignKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.closeIfAnotherWindowIsActive()
                }
            })
            observers.append(center.addObserver(
                forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.closeIfAllowed()
            })
            observers.append(center.addObserver(
                forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.menuOpen = true
            })
            observers.append(center.addObserver(
                forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.menuOpen = false
                self?.restartTimer()
            })

            eventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]
            ) { [weak self] event in
                self?.restartTimer()
                return event
            }

            if enabled { restartTimer() }
        }

        private func detach() {
            stopTimer()
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
                self.eventMonitor = nil
            }
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()
        }

        private func restartTimer() {
            guard enabled else { return }
            stopTimer()
            timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
                self?.closeIfAllowed()
            }
        }

        private func stopTimer() {
            timer?.invalidate()
            timer = nil
        }

        private func closeIfAllowed() {
            guard enabled, let window = hostWindow, window.isVisible else { return }
            // Do not close while a sheet, menu or popover is in use.
            if window.attachedSheet != nil || menuOpen { return }
            if let key = NSApp.keyWindow, key !== window,
               key.level.rawValue >= NSWindow.Level.popUpMenu.rawValue {
                return
            }
            window.orderOut(nil)
        }

        private func closeIfAnotherWindowIsActive() {
            guard enabled, let window = hostWindow, window.isVisible else { return }
            if window.attachedSheet != nil || menuOpen { return }
            if let key = NSApp.keyWindow, key !== window,
               key.level.rawValue >= NSWindow.Level.popUpMenu.rawValue {
                return
            }
            window.orderOut(nil)
        }

        deinit {
            detach()
        }
    }
}
