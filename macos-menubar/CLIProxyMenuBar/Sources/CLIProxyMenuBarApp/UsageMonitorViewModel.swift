import Foundation

@MainActor
final class UsageMonitorViewModel: ObservableObject {
    @Published var summary: UsageSummary?
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var serviceStatus: LocalServiceStatus = .unknown
    @Published var apiKeys: [APIKeyEntry] = []
    @Published var newKeyInput = ""
    @Published var actionMessage: String?

    @Published var monitorEnabled: Bool {
        didSet {
            UserDefaults.standard.set(monitorEnabled, forKey: Self.monitorEnabledKey)
            reconfigureMonitorLoop()
            Task { await refreshNow() }
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

        Task { await refreshNow() }
        reconfigureMonitorLoop()
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

    var hasConfigFile: Bool {
        RuntimeConfigLoader.load().configPath != nil
    }

    var serviceStatusText: String {
        if serviceStatus.isRunning {
            if let pid = serviceStatus.pid {
                return "运行中 (PID \(pid))"
            }
            return "运行中"
        }

        if let detail = serviceStatus.detail, !detail.isEmpty {
            return detail
        }
        return "已停止"
    }

    func requestsForKey(_ key: String) -> Int64 {
        keyUsages.first { $0.id == key }?.totalRequests ?? 0
    }

    func refreshNow() async {
        let runtimeConfig = RuntimeConfigLoader.load()

        isRefreshing = true
        defer { isRefreshing = false }

        if monitorEnabled {
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
        } else {
            summary = nil
            errorMessage = nil
        }

        await refreshServiceAndKeys(runtimeConfig: runtimeConfig)
    }

    func toggleMonitor() {
        monitorEnabled.toggle()
    }

    func startLocalService() {
        Task {
            let runtimeConfig = RuntimeConfigLoader.load()
            do {
                try await LocalServiceController.start(config: runtimeConfig)
                actionMessage = "本地服务已启动"
            } catch {
                actionMessage = error.localizedDescription
            }
            await refreshNow()
        }
    }

    func stopLocalService() {
        Task {
            let runtimeConfig = RuntimeConfigLoader.load()
            await LocalServiceController.stop(config: runtimeConfig)
            actionMessage = "本地服务已停止"
            await refreshNow()
        }
    }

    func addManualKey() {
        Task {
            let runtimeConfig = RuntimeConfigLoader.load()
            do {
                try APIKeyStore.addKey(configPath: runtimeConfig.configPath, rawKey: newKeyInput)
                newKeyInput = ""
                actionMessage = "Key 已添加"
            } catch {
                actionMessage = error.localizedDescription
            }
            await refreshServiceAndKeys(runtimeConfig: runtimeConfig)
        }
    }

    func generateAndAddKey() {
        Task {
            let runtimeConfig = RuntimeConfigLoader.load()
            do {
                let key = APIKeyStore.generateKey()
                try APIKeyStore.addKey(configPath: runtimeConfig.configPath, rawKey: key)
                actionMessage = "已生成并添加新 Key"
            } catch {
                actionMessage = error.localizedDescription
            }
            await refreshServiceAndKeys(runtimeConfig: runtimeConfig)
        }
    }

    func removeKey(_ key: String) {
        Task {
            let runtimeConfig = RuntimeConfigLoader.load()
            do {
                try APIKeyStore.removeKey(configPath: runtimeConfig.configPath, keyToRemove: key)
                actionMessage = "Key 已删除"
            } catch {
                actionMessage = error.localizedDescription
            }
            await refreshServiceAndKeys(runtimeConfig: runtimeConfig)
        }
    }

    private func reconfigureMonitorLoop() {
        monitorTask?.cancel()

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

    private func refreshServiceAndKeys(runtimeConfig: RuntimeConfig) async {
        serviceStatus = await LocalServiceController.queryStatus(config: runtimeConfig)

        do {
            apiKeys = try APIKeyStore.loadEntries(configPath: runtimeConfig.configPath)
        } catch {
            apiKeys = []
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
