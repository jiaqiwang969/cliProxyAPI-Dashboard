import AppKit
import SwiftUI

struct MenuBarDashboardView: View {
    @ObservedObject var viewModel: UsageMonitorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("模型调用")
                    .font(.headline)
                Spacer()
                Text(viewModel.monitorEnabled ? "ON" : "OFF")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button(viewModel.monitorEnabled ? "暂停" : "开启") {
                    viewModel.toggleMonitor()
                }
                Spacer()
                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Divider()

            if viewModel.keyUsages.isEmpty {
                Text("暂无模型调用数据")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
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
                .frame(maxHeight: 260)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Button("退出") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}
