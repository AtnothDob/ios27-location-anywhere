import Foundation
import CoreLocation
import AVFoundation
import Combine

// MARK: - Voice Guidance Service

final class GPSVoiceService {
    static let shared = GPSVoiceService()
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        DispatchQueue.main.async {
            if self.synthesizer.isSpeaking {
                self.synthesizer.stopSpeaking(at: .immediate)
            }
            let utterance = AVSpeechUtterance(string: text)
            // 优先中文语音，若无则使用系统默认
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN") ?? AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.52
            utterance.pitchMultiplier = 1.0
            self.synthesizer.speak(utterance)
        }
    }

    func stop() {
        DispatchQueue.main.async {
            if self.synthesizer.isSpeaking {
                self.synthesizer.stopSpeaking(at: .immediate)
            }
        }
    }
}

// MARK: - Preset Locations

struct Preset: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let lat: Double
    let lon: Double

    init(id: UUID = UUID(), name: String, lat: Double, lon: Double) {
        self.id = id
        self.name = name
        self.lat = lat
        self.lon = lon
    }
}

let kDefaultPresets: [Preset] = [
    Preset(name: "🇺🇸 苹果总部 Apple Park (CA)",             lat: 37.3349,   lon: -122.0090),
    Preset(name: "🇺🇸 纽约中央公园 (Central Park, NY)",        lat: 40.785091, lon: -73.968285),
    Preset(name: "🇺🇸 旧金山金门大桥 (Golden Gate, SF)",       lat: 37.8199,   lon: -122.4783),
    Preset(name: "🇭🇰 香港中环维港 (Victoria Harbour, HK)",   lat: 22.2855,   lon:  114.1577),
    Preset(name: "🇯🇵 东京涩谷十字路口 (Shibuya, Tokyo)",      lat: 35.6595,   lon:  139.7004),
    Preset(name: "🇬🇧 伦敦大本钟 (Big Ben, London)",           lat: 51.5007,   lon:   -0.1246),
    Preset(name: "🇫🇷 巴黎埃菲尔铁塔 (Eiffel Tower, Paris)",   lat: 48.8584,   lon:    2.2945),
    Preset(name: "🇨🇳 深圳湾人才公园 (Shenzhen Bay, CN)",      lat: 22.5186,   lon:  113.9482),
]

// MARK: - Apple Native Scenarios

struct Scenario: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let command: String
}

let kScenarios: [Scenario] = [
    Scenario(label: "🚶 步行 / 慢跑 (City Run ≈ 8 km/h)",        command: "City Run"),
    Scenario(label: "🚴 城市骑行 (City Bicycle Ride ≈ 18 km/h)", command: "City Bicycle Ride"),
    Scenario(label: "🍎 Apple Park 巡航 (Apple Park Cruise)",   command: "Apple"),
    Scenario(label: "🚗 高速公路 (Freeway Drive ≈ 90 km/h)",      command: "Freeway Drive"),
]

// MARK: - Joystick Directions

enum NudgeDirection {
    case north, south, east, west
    case northEast, northWest, southEast, southWest

    var dNorth: Double {
        switch self {
        case .north: return 1.0
        case .south: return -1.0
        case .east, .west: return 0.0
        case .northEast, .northWest: return 0.7071
        case .southEast, .southWest: return -0.7071
        }
    }

    var dEast: Double {
        switch self {
        case .east: return 1.0
        case .west: return -1.0
        case .north, .south: return 0.0
        case .northEast, .southEast: return 0.7071
        case .northWest, .southWest: return -0.7071
        }
    }
}

// MARK: - Active Simulation Mode

enum SimulationMode: String {
    case none       = "已停止"
    case teleport   = "静态坐标"
    case scenario   = "Apple 原生场景"
    case loop       = "环形巡航"
    case route      = "道路导航"
    case joystick   = "摇杆控制"
}

// MARK: - GPS Controller

@MainActor
final class GPSController: ObservableObject {
    @Published var activeMode: SimulationMode = .none
    @Published var currentCoord: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    @Published var currentCoordString: String = "37.33490, -122.00900"

    // Jitter Anti-detection
    @Published var isJitterEnabled: Bool = false
    @Published var jitterMeters: Double = 1.8

    // Turn-by-Turn Navigation Status
    @Published var currentStepIndex: Int = 0
    @Published var currentStepInstruction: String = ""

    // Custom Bookmarks
    @Published var customPresets: [Preset] = []

    private var activeTask: Task<Void, Never>?
    private var jitterTask: Task<Void, Never>?

    init() {
        loadCustomPresets()
    }

    var isRunning: Bool {
        activeMode != .none
    }

    // MARK: - Apple Native Scenario
    func startScenario(_ scenario: Scenario, udid: String) {
        stopAll(keepCoord: false)
        activeMode = .scenario
        let cmd = scenario.command
        let label = scenario.label
        GPSLogger.shared.add("下发 Apple 原生轨迹: \(cmd)…")

        Task.detached(priority: .userInitiated) {
            let out = shell(#"xcrun devicectl device simulate location scenario --device "\#(udid)" "\#(cmd)""#)
            await MainActor.run {
                GPSLogger.shared.add("🟢 成功启动: \(label)")
                if !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    GPSLogger.shared.add("  输出: \(out.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
        }
    }

    // MARK: - Teleport (Static Coordinates)
    func teleport(lat: Double, lon: Double, udid: String) {
        stopAll(keepCoord: true)
        activeMode = .teleport
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        currentCoord = coord
        currentCoordString = String(format: "%.5f, %.5f", lat, lon)
        GPSLogger.shared.add("瞬移到坐标: (\(lat), \(lon))…")

        Task.detached(priority: .userInitiated) {
            _ = shell(#"xcrun devicectl device simulate location coordinate --device "\#(udid)" --latitude \#(lat) --longitude=\#(lon)"#)
            await MainActor.run {
                GPSLogger.shared.add("🟢 已定位到: \(String(format: "%.5f, %.5f", lat, lon))")
                if self.isJitterEnabled {
                    self.startJitterLoop(baseLat: lat, baseLon: lon, udid: udid)
                }
            }
        }
    }

    // MARK: - Circular Loop Cruise
    func startLoop(lat: Double, lon: Double, speed: SpeedMode, radiusMeters: Double, udid: String) {
        stopAll(keepCoord: true)
        activeMode = .loop
        GPSLogger.shared.add("启动 \(speed.label) 环形巡航 (半径 \(Int(radiusMeters))m)…")

        // 经纬度米制转换
        let latDelta = radiusMeters / 111320.0
        let lonDelta = radiusMeters / (111320.0 * cos(lat * .pi / 180.0))

        activeTask = Task.detached(priority: .userInitiated) {
            var angle = 0.0
            while !Task.isCancelled {
                var clat = lat + latDelta * sin(angle)
                var clon = lon + lonDelta * cos(angle)

                // 若开启拟真漂移，添加微弱高斯抖动
                let isJitter = await self.isJitterEnabled
                let jitterRadius = await self.jitterMeters
                if isJitter {
                    let jLat = (Double.random(in: -1...1) * jitterRadius) / 111320.0
                    let jLon = (Double.random(in: -1...1) * jitterRadius) / (111320.0 * cos(clat * .pi / 180.0))
                    clat += jLat
                    clon += jLon
                }

                shell(#"xcrun devicectl device simulate location coordinate --device "\#(udid)" --latitude \#(String(format:"%.6f",clat)) --longitude=\#(String(format:"%.6f",clon))"#)

                let coordStr = String(format: "%.5f, %.5f", clat, clon)
                let cCoord = CLLocationCoordinate2D(latitude: clat, longitude: clon)
                await MainActor.run {
                    self.currentCoord = cCoord
                    self.currentCoordString = coordStr
                }

                angle += speed.angleStep
                try? await Task.sleep(for: .seconds(speed.stepSec))
            }
        }
    }

    // MARK: - Route Navigation (A -> B Waypoints + Steps + Voice)
    func startRouteNavigation(waypoints: [CLLocationCoordinate2D], routeSteps: [RouteStepInfo] = [], speedKmh: Double, voiceEnabled: Bool = true, udid: String) {
        guard waypoints.count >= 2 else {
            GPSLogger.shared.add("⚠️ 导航点不足，无法启动路线模拟")
            return
        }
        stopAll(keepCoord: true)
        activeMode = .route

        let speedMps = max(1.0, speedKmh / 3.6)
        let intervalSec: Double = 1.5
        GPSLogger.shared.add("启动真实道路导航模拟: \(waypoints.count) 个路网节点，速度 \(Int(speedKmh)) km/h…")

        // 初始第一条语音
        currentStepIndex = 0
        currentStepInstruction = routeSteps.first?.instruction ?? "开始导航"
        if voiceEnabled && !currentStepInstruction.isEmpty {
            GPSVoiceService.shared.speak(currentStepInstruction)
        }

        // 构造临时 Route JSON
        let routeDict: [String: Any] = [
            "mode": "interval",
            "interval": intervalSec,
            "speed": speedMps,
            "waypoints": waypoints.map { ["latitude": $0.latitude, "longitude": $0.longitude] }
        ]

        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("route_\(UUID().uuidString).json")
        do {
            let data = try JSONSerialization.data(withJSONObject: routeDict, options: .prettyPrinted)
            try data.write(to: tempFile)
        } catch {
            GPSLogger.shared.add("🔴 无法生成路网数据: \(error.localizedDescription)")
            return
        }

        // 调用 devicectl 原生下发
        Task.detached(priority: .userInitiated) {
            let out = shell(#"xcrun devicectl device simulate location route --device "\#(udid)" --route-file "\#(tempFile.path)""#)
            await MainActor.run {
                GPSLogger.shared.add("🟢 设备已加载路线: \(out.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        // 本地进度同步（驱动地图小车移动与转弯指引步进）
        activeTask = Task.detached(priority: .userInitiated) {
            var currentIndex = 0
            var lastStepIndex = 0
            let totalSteps = routeSteps.count

            while !Task.isCancelled && currentIndex < waypoints.count {
                let current = waypoints[currentIndex]
                let coordStr = String(format: "%.5f, %.5f", current.latitude, current.longitude)

                // 距离转弯节点匹配与语音播报
                if totalSteps > 0 {
                    let cLoc = CLLocation(latitude: current.latitude, longitude: current.longitude)
                    var bestNextStep = lastStepIndex
                    var minDistance: CLLocationDistance = 75.0 // 75米进入转弯判定范围

                    for sIdx in lastStepIndex..<totalSteps {
                        if let sCoord = routeSteps[sIdx].coordinate {
                            let dist = cLoc.distance(from: CLLocation(latitude: sCoord.latitude, longitude: sCoord.longitude))
                            if dist < minDistance {
                                minDistance = dist
                                bestNextStep = sIdx
                                break
                            }
                        }
                    }

                    if bestNextStep > lastStepIndex && bestNextStep < totalSteps {
                        lastStepIndex = bestNextStep
                        let instr = routeSteps[bestNextStep].instruction
                        await MainActor.run {
                            self.currentStepIndex = bestNextStep
                            self.currentStepInstruction = instr
                            GPSLogger.shared.add("🧭 [导航转弯] \(instr)")
                            if voiceEnabled {
                                GPSVoiceService.shared.speak(instr)
                            }
                        }
                    }
                }

                await MainActor.run {
                    self.currentCoord = current
                    self.currentCoordString = coordStr
                }

                if currentIndex + 1 < waypoints.count {
                    let next = waypoints[currentIndex + 1]
                    let locA = CLLocation(latitude: current.latitude, longitude: current.longitude)
                    let locB = CLLocation(latitude: next.latitude, longitude: next.longitude)
                    let dist = locA.distance(from: locB)
                    let travelSec = max(0.4, dist / speedMps)
                    try? await Task.sleep(for: .seconds(travelSec))
                } else {
                    break
                }
                currentIndex += 1
            }

            await MainActor.run {
                if self.activeMode == .route {
                    GPSLogger.shared.add("🏁 已到达目的地路线终点！")
                    if voiceEnabled {
                        GPSVoiceService.shared.speak("已到达目的地附近，模拟导航结束")
                    }
                }
            }
        }
    }

    // MARK: - Virtual Joystick / Nudge
    func nudge(direction: NudgeDirection, stepMeters: Double, udid: String) {
        guard let base = currentCoord else { return }
        stopAll(keepCoord: true)
        activeMode = .joystick

        let dLat = (direction.dNorth * stepMeters) / 111320.0
        let dLon = (direction.dEast * stepMeters) / (111320.0 * cos(base.latitude * .pi / 180.0))

        let newLat = base.latitude + dLat
        let newLon = base.longitude + dLon
        let newCoord = CLLocationCoordinate2D(latitude: newLat, longitude: newLon)

        currentCoord = newCoord
        currentCoordString = String(format: "%.5f, %.5f", newLat, newLon)

        Task.detached(priority: .userInitiated) {
            _ = shell(#"xcrun devicectl device simulate location coordinate --device "\#(udid)" --latitude \#(String(format:"%.6f",newLat)) --longitude=\#(String(format:"%.6f",newLon))"#)
        }
    }

    // MARK: - Anti-Detection Jitter Loop
    private func startJitterLoop(baseLat: Double, baseLon: Double, udid: String) {
        jitterTask?.cancel()
        guard isJitterEnabled else { return }

        jitterTask = Task.detached(priority: .background) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.0...3.5)))
                guard await self.isJitterEnabled, await self.activeMode == .teleport else { break }

                let radius = await self.jitterMeters
                let jLat = (Double.random(in: -1...1) * radius) / 111320.0
                let jLon = (Double.random(in: -1...1) * radius) / (111320.0 * cos(baseLat * .pi / 180.0))

                let cLat = baseLat + jLat
                let cLon = baseLon + jLon

                shell(#"xcrun devicectl device simulate location coordinate --device "\#(udid)" --latitude \#(String(format:"%.6f",cLat)) --longitude=\#(String(format:"%.6f",cLon))"#)

                let coordStr = String(format: "%.5f, %.5f", cLat, cLon)
                let cCoord = CLLocationCoordinate2D(latitude: cLat, longitude: cLon)
                await MainActor.run {
                    self.currentCoord = cCoord
                    self.currentCoordString = coordStr
                }
            }
        }
    }

    // MARK: - Stop All Simulation
    func stopAll(keepCoord: Bool = false) {
        activeTask?.cancel()
        activeTask = nil
        jitterTask?.cancel()
        jitterTask = nil
        activeMode = .none
        GPSVoiceService.shared.stop()
    }

    // MARK: - Clear / Restore Real Physical GPS
    func clearSimulation(udid: String) {
        stopAll(keepCoord: false)
        GPSLogger.shared.add("下发指令: 恢复物理真实 GPS…")
        Task.detached(priority: .userInitiated) {
            shell(#"xcrun devicectl device simulate location clear --device "\#(udid)""#)
            await MainActor.run {
                self.currentCoordString = "真实 GPS（未模拟）"
                GPSLogger.shared.add("🟢 成功恢复手机物理硬件定位！")
            }
        }
    }

    // MARK: - Custom Preset Bookmarks
    func addCustomPreset(name: String, lat: Double, lon: Double) {
        let p = Preset(name: name, lat: lat, lon: lon)
        customPresets.append(p)
        saveCustomPresets()
        GPSLogger.shared.add("⭐ 已收藏地点: \(name) (\(lat), \(lon))")
    }

    func removeCustomPreset(id: UUID) {
        customPresets.removeAll { $0.id == id }
        saveCustomPresets()
    }

    private func saveCustomPresets() {
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: "GPSSimulator_CustomPresets")
        }
    }

    private func loadCustomPresets() {
        if let data = UserDefaults.standard.data(forKey: "GPSSimulator_CustomPresets"),
           let list = try? JSONDecoder().decode([Preset].self, from: data) {
            customPresets = list
        }
    }
}
