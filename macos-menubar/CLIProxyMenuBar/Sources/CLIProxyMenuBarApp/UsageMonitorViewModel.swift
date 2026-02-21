import Foundation

@MainActor
final class UsageMonitorViewModel: ObservableObject {
    @Published var summary: UsageSummary?
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    @Published var monitorEnabled: Bool {
        didSet {
            UserDefaults.standard.set(monitorEnabled, forKey: Self.monitorEnabledKey)
            reconfigureMonitorLoop()
            if monitorEnabled {
                Task { await refreshNow() }
            }
        }
    }

    private var monitorTask: Task<Void, Never>?
    private let client: CLIProxyAPIClient

    private static let pollingIntervalSeconds: Double = 10
    private static let monitorEnabledKey = "menubar.monitorEnabled"

    init(client: CLIProxyAPIClient = CLIProxyAPIClient()) {
        self.client = client

        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.monitorEnabledKey) == nil {
            self.monitorEnabled = true
        } else {
            self.monitorEnabled = defaults.bool(forKey: Self.monitorEnabledKey)
        }

        if monitorEnabled {
            Task {
                await refreshNow()
                reconfigureMonitorLoop()
            }
        }
    }

    deinit {
        monitorTask?.cancel()
    }

    var menuBarTitle: String {
        if !monitorEnabled {
            return "OFF"
        }
        guard let totalRequests = summary?.displayRequests else {
            return "--"
        }
        return Self.compactNumber(totalRequests)
    }

    var keyUsages: [APIKeyUsage] {
        summary?.keyUsages ?? []
    }

    func refreshNow() async {
        guard monitorEnabled else {
            return
        }

        let runtimeConfig = RuntimeConfigLoader.load()

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let newSummary = try await client.fetchUsageSummary(
                baseURL: runtimeConfig.baseURL,
                managementKey: runtimeConfig.managementKey
            )
            summary = newSummary
            errorMessage = nil
        } catch {
            errorMessage = Self.makeFriendlyError(error, config: runtimeConfig)
        }
    }

    func toggleMonitor() {
        monitorEnabled.toggle()
    }

    private func reconfigureMonitorLoop() {
        monitorTask?.cancel()

        guard monitorEnabled else {
            monitorTask = nil
            return
        }

        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.pollingIntervalSeconds))
                guard !Task.isCancelled else {
                    return
                }
                await self?.refreshNow()
            }
        }
    }

    private static func makeFriendlyError(_ error: Error, config: RuntimeConfig) -> String {
        if case let APIClientError.httpError(statusCode, _) = error, statusCode == 401 {
            if config.managementKey.isEmpty {
                return "监控未授权：缺少 Management Key"
            }
            return "监控未授权：Management Key 无效"
        }

        if case let APIClientError.serverMessage(message) = error {
            if message.isEmpty {
                return "暂时无法读取统计"
            }
            return "暂时无法读取统计"
        }

        if case APIClientError.decodeError = error {
            return "统计数据格式暂不兼容，已自动跳过"
        }

        return "暂时无法读取统计"
    }

    private static func compactNumber(_ value: Int64) -> String {
        let absolute = abs(Double(value))
        let sign = value < 0 ? "-" : ""

        switch absolute {
        case 1_000_000_000...:
            return String(format: "\(sign)%.1fB", absolute / 1_000_000_000)
        case 1_000_000...:
            return String(format: "\(sign)%.1fM", absolute / 1_000_000)
        case 1_000...:
            return String(format: "\(sign)%.1fK", absolute / 1_000)
        default:
            return "\(value)"
        }
    }
}
