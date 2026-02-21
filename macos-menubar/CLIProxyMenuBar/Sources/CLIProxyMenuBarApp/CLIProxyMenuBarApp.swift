import AppKit
import SwiftUI

@main
struct CLIProxyMenuBarApp: App {
    @StateObject private var viewModel = UsageMonitorViewModel()

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
    }
}
