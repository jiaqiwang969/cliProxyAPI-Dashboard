import Foundation

@MainActor
final class UsageMonitorViewModel: ObservableObject {
    @Published var summary: UsageSummary?
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var serviceStatus: LocalServiceStatus = .unknown
    @Published var apiKeys: [APIKeyEntry] = []
    @Published var newKeyInput = ""
    @Published var newKeyNoteInput = ""
    @Published var actionMessage: String?

    @Published var showOnlyErrorLogs = false
    @Published var serviceLogs: [LogLine] = []
    private var logTask: Task<Void, Never>?
    private var logFileHandle: FileHandle?

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
        logTask?.cancel()
        logFileHandle?.readabilityHandler = nil
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

    var launchAtLoginEnabled: Bool {
        UserDefaults.standard.bool(forKey: "launchAtLogin")
    }

    func toggleLaunchAtLogin() {
        let newValue = !launchAtLoginEnabled
        UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
    }

    var filteredServiceLogs: [LogLine] {
        if showOnlyErrorLogs {
            return serviceLogs.filter { $0.isError }
        }
        return serviceLogs
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
        if serviceStatus.isRunning && logTask == nil {
            startLogMonitoring()
        }
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
                newKeyNoteInput = ""
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

    func updateKeyNote(_ key: String, note: String) {
        Task {
            let runtimeConfig = RuntimeConfigLoader.load()
            do {
                try APIKeyStore.updateKeyNote(configPath: runtimeConfig.configPath, keyId: key, note: note)
                actionMessage = "备注已更新"
            } catch {
                actionMessage = error.localizedDescription
            }
            await refreshServiceAndKeys(runtimeConfig: runtimeConfig)
        }
    }

    func setKeyEnabled(_ key: String, enabled: Bool) {
        Task {
            let runtimeConfig = RuntimeConfigLoader.load()
            do {
                try APIKeyStore.setKeyEnabled(configPath: runtimeConfig.configPath, keyId: key, enabled: enabled)
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

    private func startLogMonitoring() {
        stopLogMonitoring()
        
        let logPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("cli-proxy-api.log")
        guard FileManager.default.fileExists(atPath: logPath) else { return }
        
        logTask = Task { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
            process.arguments = ["-n", "100", "-f", logPath]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            self.logFileHandle = pipe.fileHandleForReading
            
            self.logFileHandle?.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty else { return }
                
                if let str = String(data: data, encoding: .utf8) {
                    let lines = str.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    Task { @MainActor in
                        for line in lines {
                            let isError = line.lowercased().contains("error") || line.lowercased().contains("panic")
                            self.serviceLogs.append(LogLine(text: line, isError: isError))
                        }
                        if self.serviceLogs.count > 100 {
                            self.serviceLogs.removeFirst(self.serviceLogs.count - 100)
                        }
                    }
                }
            }
            
            try? process.run()
            process.waitUntilExit()
        }
    }

    private func stopLogMonitoring() {
        logTask?.cancel()
        logTask = nil
        logFileHandle?.readabilityHandler = nil
        logFileHandle = nil
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

struct LogLine: Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
}
