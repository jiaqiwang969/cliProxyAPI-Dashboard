import AppKit
import SwiftUI

private enum DashboardTab: String, CaseIterable, Identifiable {
    case service = "服务"
    case keys = "Keys"
    case usage = "贡献"

    var id: String { rawValue }
}

struct MenuBarDashboardView: View {
    @ObservedObject var viewModel: UsageMonitorViewModel
    @State private var selectedTab: DashboardTab = .usage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CLIProxy 控制台")
                    .font(.headline)
                Spacer()
                Text(viewModel.monitorEnabled ? "MONITOR ON" : "MONITOR OFF")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Picker("", selection: $selectedTab) {
                ForEach(DashboardTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch selectedTab {
                case .service:
                    servicePanel
                case .keys:
                    keysPanel
                case .usage:
                    usagePanel
                }
            }

            if let actionMessage = viewModel.actionMessage, !actionMessage.isEmpty {
                Text(actionMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Divider()

            HStack(spacing: 8) {
                Button("刷新") {
                    Task { await viewModel.refreshNow() }
                }
                .disabled(viewModel.isRefreshing)

                Button(viewModel.monitorEnabled ? "暂停统计" : "开启统计") {
                    viewModel.toggleMonitor()
                }

                Spacer()

                Button("退出") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(12)
        .frame(width: 400)
    }

    private var servicePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("状态：\(viewModel.serviceStatusText)")
                .font(.callout)

            if !viewModel.hasConfigFile {
                Text("未找到本地 config.yaml，无法控制服务")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("启动服务") {
                    viewModel.startLocalService()
                }
                .disabled(viewModel.serviceStatus.isRunning || !viewModel.hasConfigFile)

                Button("停止服务") {
                    viewModel.stopLocalService()
                }
                .disabled(!viewModel.serviceStatus.isRunning)

                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private var keysPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.hasConfigFile {
                Text("未找到本地 config.yaml，无法管理 Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    TextField("粘贴 sk-key", text: $viewModel.newKeyInput)
                        .textFieldStyle(.roundedBorder)
                    Button("添加") {
                        viewModel.addManualKey()
                    }
                }

                HStack(spacing: 6) {
                    Button("生成并添加") {
                        viewModel.generateAndAddKey()
                    }
                    Spacer()
                    Text("共 \(viewModel.apiKeys.count) 个")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.apiKeys.isEmpty {
                Text("暂无 sk-key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.apiKeys) { entry in
                            HStack(spacing: 8) {
                                Text(entry.masked)
                                    .font(.callout)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text("\(viewModel.requestsForKey(entry.id))")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                Button("删除") {
                                    viewModel.removeKey(entry.id)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }

    private var usagePanel: some View {
        let total = max(viewModel.summary?.displayRequests ?? 0, 1)

        return Group {
            if viewModel.keyUsages.isEmpty {
                Text("暂无贡献数据")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.keyUsages) { keyUsage in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(keyUsage.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text("\(keyUsage.totalRequests)")
                                        .font(.caption)
                                        .monospacedDigit()
                                    Text(percentText(value: keyUsage.totalRequests, total: total))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                ForEach(keyUsage.modelCalls) { item in
                                    HStack(spacing: 8) {
                                        Text(item.id)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                        Text("\(item.requests)")
                                            .monospacedDigit()
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.callout)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private func percentText(value: Int64, total: Int64) -> String {
        let ratio = Double(value) / Double(total)
        return String(format: "%.1f%%", ratio * 100)
    }
}
