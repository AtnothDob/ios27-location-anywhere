import Foundation
import Combine

// MARK: - Models

struct DeviceInfo: Identifiable, Equatable, Hashable {
    let id: String   // UDID or identifier
    let name: String
    let modelName: String
    let osVersion: String
    let isPhysical: Bool
    let transportType: String // "wired" / "localNetwork" / "unknown"
    let isConnected: Bool

    var isUSB: Bool { transportType.lowercased().contains("wired") }
    var isWifi: Bool { transportType.lowercased().contains("localnetwork") }

    var transportTag: String {
        if isUSB {
            return "🔌 USB"
        } else if isWifi {
            return "📶 Wi-Fi"
        } else {
            return "📱 设备"
        }
    }

    var displayName: String {
        var parts: [String] = []
        parts.append(transportTag)
        parts.append(name)
        if !modelName.isEmpty {
            parts.append("(\(modelName))")
        }
        if !osVersion.isEmpty {
            parts.append("iOS \(osVersion)")
        }
        let shortID = id.count > 8 ? "\(id.prefix(8))…" : id
        parts.append("[\(shortID)]")
        return parts.joined(separator: "  ")
    }
}

enum SpeedMode: String, CaseIterable, Identifiable {
    case walk     = "walk"
    case jog      = "jog"
    case bike     = "bike"
    case cityCar  = "cityCar"
    case highway  = "highway"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .walk:    return "🚶 步行 5 km/h"
        case .jog:     return "🏃 慢跑 10 km/h"
        case .bike:    return "🚴 骑行 20 km/h"
        case .cityCar: return "🚙 市区 45 km/h"
        case .highway: return "🚗 高速 90 km/h"
        }
    }

    var speedMps: Double {
        switch self {
        case .walk:    return 5.0 / 3.6
        case .jog:     return 10.0 / 3.6
        case .bike:    return 20.0 / 3.6
        case .cityCar: return 45.0 / 3.6
        case .highway: return 90.0 / 3.6
        }
    }

    var radius: Double {
        switch self {
        case .walk:    return 0.0015
        case .jog:     return 0.003
        case .bike:    return 0.006
        case .cityCar: return 0.012
        case .highway: return 0.025
        }
    }

    var stepSec: Double {
        switch self {
        case .walk:    return 1.5
        case .jog:     return 1.2
        case .bike:    return 1.0
        case .cityCar: return 0.8
        case .highway: return 0.6
        }
    }

    var angleStep: Double {
        switch self {
        case .walk:    return 0.06
        case .jog:     return 0.09
        case .bike:    return 0.12
        case .cityCar: return 0.16
        case .highway: return 0.20
        }
    }
}

// MARK: - Device Scanner

@MainActor
final class DeviceScanner: ObservableObject {
    @Published var devices: [DeviceInfo] = []
    @Published var statusText: String = "正在搜索连接的设备…"
    @Published var isAutoScanning: Bool = true
    @Published var dotChar: String = "●"

    private var scanTask: Task<Void, Never>?
    private let dots = ["◐","◓","◑","◒"]
    private var dotIndex = 0

    init() {
        Task { await refresh(initial: true) }
        startAutoScan()
    }

    func refresh(initial: Bool = false) async {
        statusText = "🔍 扫描设备中…"
        let found = await scanPhysicalDevices()
        updateDevices(found)
        if initial && found.isEmpty {
            statusText = "⚠️ 未发现已连接的真机（请插上数据线或开启局域网调试）"
        }
    }

    private func startAutoScan() {
        scanTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard await self.isAutoScanning else { continue }
                let found = await scanPhysicalDevices()
                await MainActor.run { self.updateDevices(found) }
                // 旋转动画
                await MainActor.run {
                    self.dotIndex = (self.dotIndex + 1) % 4
                    self.dotChar = self.dots[self.dotIndex]
                }
            }
        }
    }

    private func updateDevices(_ found: [DeviceInfo]) {
        let oldIDs = Set(devices.map(\.id))
        let newIDs = Set(found.map(\.id))
        if newIDs != oldIDs {
            let added   = newIDs.subtracting(oldIDs)
            let removed = oldIDs.subtracting(newIDs)
            if !oldIDs.isEmpty {
                if !added.isEmpty {
                    let names = found.filter { added.contains($0.id) }.map { "\($0.transportTag) \($0.name)" }.joined(separator: ", ")
                    GPSLogger.shared.add("🟢 新设备接入: \(names)")
                }
                if !removed.isEmpty {
                    GPSLogger.shared.add("🔴 设备断开 (UDID: \(removed.first?.prefix(8) ?? "")…)")
                }
            }
            devices = found
        }
        let n = found.count
        statusText = n > 0
            ? "✅ \(n) 台设备就绪（每 3s 自动扫描）"
            : "⚠️ 未发现真机（每 3s 自动扫描）"
    }

    deinit { scanTask?.cancel() }
}

// MARK: - JSON Structures for devicectl

private struct DevicectlDeviceJSON: Decodable {
    struct DeviceProperties: Decodable {
        let name: String?
        let osVersionNumber: String?
    }
    struct HardwareProperties: Decodable {
        let udid: String?
        let marketingName: String?
        let productType: String?
        let reality: String?
    }
    struct ConnectionProperties: Decodable {
        let transportType: String?
        let tunnelState: String?
    }

    let identifier: String
    let deviceProperties: DeviceProperties?
    let hardwareProperties: HardwareProperties?
    let connectionProperties: ConnectionProperties?
}

private struct DevicectlRootJSON: Decodable {
    struct ResultContainer: Decodable {
        let devices: [DevicectlDeviceJSON]?
    }
    let result: ResultContainer?
}

// MARK: - Shell helpers (nonisolated)

func scanPhysicalDevices() async -> [DeviceInfo] {
    await withCheckedContinuation { cont in
        DispatchQueue.global(qos: .utility).async {
            let tmpPath = NSTemporaryDirectory() + "devicectl_scan_\(UUID().uuidString).json"
            defer { try? FileManager.default.removeItem(atPath: tmpPath) }

            _ = shell("xcrun devicectl list devices --json-output \"\(tmpPath)\" >/dev/null 2>&1")

            if let data = try? Data(contentsOf: URL(fileURLWithPath: tmpPath)),
               let root = try? JSONDecoder().decode(DevicectlRootJSON.self, from: data),
               let list = root.result?.devices, !list.isEmpty {
                var devs: [DeviceInfo] = []
                for d in list {
                    let reality = d.hardwareProperties?.reality ?? ""
                    guard reality == "physical" else { continue }
                    let udid = d.hardwareProperties?.udid ?? d.identifier
                    let name = d.deviceProperties?.name ?? "iOS Device"
                    let model = d.hardwareProperties?.marketingName ?? ""
                    let os = d.deviceProperties?.osVersionNumber ?? ""
                    let transport = d.connectionProperties?.transportType ?? "unknown"
                    let isConn = d.connectionProperties?.tunnelState == "connected"

                    devs.append(DeviceInfo(
                        id: udid,
                        name: name,
                        modelName: model,
                        osVersion: os,
                        isPhysical: true,
                        transportType: transport,
                        isConnected: isConn
                    ))
                }
                if !devs.isEmpty {
                    devs.sort { a, b in
                        if a.isUSB != b.isUSB { return a.isUSB }
                        if a.isConnected != b.isConnected { return a.isConnected }
                        return a.name < b.name
                    }
                    cont.resume(returning: devs)
                    return
                }
            }

            // 备用：纯文本正则回退解析
            let result = shell("xcrun devicectl list devices 2>&1")
            var devices: [DeviceInfo] = []
            for line in result.components(separatedBy: "\n") {
                guard line.lowercased().contains("physical") else { continue }
                let stripped = line.trimmingCharacters(in: .whitespaces)
                guard !stripped.isEmpty,
                      !stripped.hasPrefix("-"),
                      !stripped.hasPrefix("Name") else { continue }
                let cols = stripped.components(separatedBy: "  ").filter { !$0.isEmpty }
                let name = cols.first?.trimmingCharacters(in: .whitespaces) ?? ""
                if let udid = extractUDID(from: line), !name.isEmpty {
                    devices.append(DeviceInfo(
                        id: udid,
                        name: name,
                        modelName: "",
                        osVersion: "",
                        isPhysical: true,
                        transportType: "unknown",
                        isConnected: true
                    ))
                }
            }
            cont.resume(returning: devices)
        }
    }
}

func extractUDID(from line: String) -> String? {
    let pattern = #"\b([0-9A-Fa-f]{8}-[0-9A-Fa-f]{16,})\b"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
          let range = Range(match.range(at: 1), in: line) else { return nil }
    return String(line[range])
}

@discardableResult
func shell(_ command: String) -> String {
    let process = Process()
    process.launchPath = "/bin/bash"
    process.arguments = ["-c", command]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError  = pipe
    do {
        try process.run()
    } catch {
        return ""
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(data: data, encoding: .utf8) ?? ""
}

// MARK: - Logger

final class GPSLogger: ObservableObject {
    static let shared = GPSLogger()
    @Published var entries: [String] = []
    private init() {}

    func add(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        DispatchQueue.main.async {
            self.entries.append("[\(ts)] \(msg)")
            if self.entries.count > 300 { self.entries.removeFirst() }
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
    }
}
