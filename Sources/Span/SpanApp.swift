import SwiftUI
import AppKit

@main
struct SpanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = SpanModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 920, minHeight: 590)
                .onAppear { appDelegate.connect(model) }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Window") {
                Button("Previous zone") { model.snapPrevious() }
                    .keyboardShortcut(.leftArrow, modifiers: [.control, .option])
                Button("Next zone") { model.snapNext() }
                    .keyboardShortcut(.rightArrow, modifiers: [.control, .option])
                Button("Maximize") { model.maximize() }
                    .keyboardShortcut(.return, modifiers: [.control, .option])
                Divider()
                Button("Center window") { model.centerWindow() }
            }
        }

        MenuBarExtra("Span", systemImage: "rectangle.split.3x1") {
            MenuBarView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 460, height: 310)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: SpanModel?
    private var shortcutMonitor: GlobalShortcutMonitor?

    func connect(_ model: SpanModel) {
        guard self.model == nil else { return }
        self.model = model
        shortcutMonitor = GlobalShortcutMonitor(model: model)
        shortcutMonitor?.start()
        model.refreshDisplays()
        model.refreshPermission()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model?.refreshPermission()
        model?.refreshTargetApplication()
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutMonitor?.stop()
    }
}
