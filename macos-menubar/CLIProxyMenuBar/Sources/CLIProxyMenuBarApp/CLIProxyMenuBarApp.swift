import AppKit
import SwiftUI
import ServiceManagement

@main
struct CLIProxyMenuBarApp: App {
    @StateObject private var viewModel = UsageMonitorViewModel()
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarDashboardView(viewModel: viewModel)
        } label: {
            Label {
                Text(viewModel.menuBarTitle)
            } icon: {
                Image(systemName: viewModel.monitorEnabled ? "dot.radiowaves.left.and.right" : "pause.circle")
            }
        }
        .menuBarExtraStyle(.window)
        .onChange(of: launchAtLogin) { newValue in
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update Launch at Login setting: \(error)")
            }
        }
    }
}
