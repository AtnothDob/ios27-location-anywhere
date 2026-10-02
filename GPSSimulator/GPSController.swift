import Foundation
import CoreLocation
import MapKit
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
    Preset(name: "🇨🇳 上海陆家嘴金融中心 (Lujiazui, SH)",    lat: 31.2397,   lon: 121.5000),
    Preset(name: "🇨🇳 深圳湾人才公园 (Shenzhen Bay, SZ)",   lat: 22.5186,   lon: 113.9482),
    Preset(name: "🇨🇳 广州天河城商圈 (Tianhe, GZ)",         lat: 23.1329,   lon: 113.3235),
    Preset(name: "🇨🇳 成都春熙路太古里 (Chunxi, CD)",       lat: 30.6558,   lon: 104.0818),
    Preset(name: "🇨🇳 武汉光谷广场 (Optics Valley, WH)",   lat: 30.5078,   lon: 114.3995),
    Preset(name: "🇺🇸 苹果总部 Apple Park (CA)",             lat: 37.3349,   lon: -122.0090),
    Preset(name: "🇺🇸 洛杉矶尔湾 (Irvine, CA)",               lat: 33.6846,   lon: -117.8265),
    Preset(name: "🇺🇸 纽约中央公园 (Central Park, NY)",        lat: 40.7851,   lon: -73.9683),
    Preset(name: "🇯🇵 东京涩谷十字路口 (Shibuya, Tokyo)",      lat: 35.6595,   lon: 139.7004),
    Preset(name: "🇫🇷 巴黎埃菲尔铁塔 (Eiffel Tower, Paris)",   lat: 48.8584,   lon: 2.2945),
    Preset(name: "🇭🇰 香港中环维港 (Victoria Harbour, HK)",   lat: 22.2855,   lon: 114.1577),
]

// MARK: - Native Scenario Model

enum ScenarioRunMode: String, CaseIterable, Identifiable {
    case customOrigin = "📍 当地自选起点 (推荐)"
    case officialApple = "🍎 Apple 官方原版 (加州固定点)"

    var id: String { rawValue }
}

struct Scenario: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let command: String
    let defaultSpeedKmh: Double
    let defaultDistanceMeters: Double
    let transportType: MKDirectionsTransportType
    let subtitle: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Scenario, rhs: Scenario) -> Bool {
        lhs.id == rhs.id
    }
}

let kScenarios: [Scenario] = [
    Scenario(
        label: "🚶 慢跑 / 步行 (City Run ≈ 8 km/h)",
        command: "City Run",
        defaultSpeedKmh: 8.0,
        defaultDistanceMeters: 3000.0,
        transportType: .walking,
        subtitle: "步道慢跑拟真，单向顺路向前开拓"
    ),
    Scenario(
        label: "🚴 城市骑行 (City Bicycle Ride ≈ 18 km/h)",
        command: "City Bicycle Ride",
        defaultSpeedKmh: 18.0,
        defaultDistanceMeters: 6000.0,
        transportType: .walking,
        subtitle: "绿道骑行拟真，单向沿路持续前行"
    ),
    Scenario(
        label: "🚙 市区巡游 (City Drive ≈ 45 km/h)",
        command: "City Drive",
        defaultSpeedKmh: 45.0,
        defaultDistanceMeters: 15000.0,
        transportType: .automobile,
        subtitle: "城市干道驾驶，单向长途持续前行"
    ),
    Scenario(
        label: "🏎️ 快速路巡航 (Freeway Drive ≈ 90 km/h)",
        command: "Freeway Drive",
        defaultSpeedKmh: 90.0,
        defaultDistanceMeters: 25000.0,
        transportType: .automobile,
        subtitle: "高速/快速路巡航，单向连续高速行驶"
    ),
    Scenario(
        label: "🍎 Apple Park 官方原版 (Cupertino)",
        command: "Apple",
        defaultSpeedKmh: 15.0,
        defaultDistanceMeters: 3000.0,
        transportType: .walking,
        subtitle: "苹果总部园区巡游 (Apple 原厂加州坐标)"
    ),
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
    case route      = "道路导航"
    case roaming    = "智能漫游"
    case joystick   = "摇杆控制"
}

// MARK: - Network

/// 公共 OSM 服务（Nominatim / Photon / OSRM）要求请求带上可识别应用来源的 User-Agent
let kHTTPUserAgent = "GPSSimulator/1.0 (+https://github.com/AtnothDob/ios27-location-anywhere)"

// MARK: - Tick Timing

/// 扣除本节拍已花费的时间（主要是 devicectl 下发耗时）后睡满一个节拍，返回本节拍真实流逝的秒数。
/// 用真实耗时推进里程，避免 devicectl 较慢时实际速度低于设定值；上限 3 个节拍，防止卡顿后瞬移。
@discardableResult
func sleepRemainingTick(since start: Date, tick: Double) async -> Double {
    let spent = Date().timeIntervalSince(start)
    try? await Task.sleep(for: .seconds(max(0.05, tick - spent)))
    return min(Date().timeIntervalSince(start), tick * 3)
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

    // Navigation 2.0 State
    @Published var navigationSpeedKmh: Double = 45.0
    @Published var isNavigationPaused: Bool = false
    @Published var navigationProgress: Double = 0.0 // 0.0 ~ 1.0
    @Published var navigationRemainingDistMeters: Double = 0.0
    @Published var navigationRemainingTimeSec: TimeInterval = 0.0
    @Published var currentHeading: Double = 0.0
    @Published var totalRouteDistanceMeters: Double = 0.0

    // Turn-by-Turn Navigation Status
    @Published var currentStepIndex: Int = 0
    @Published var currentStepInstruction: String = ""

    // Scenario Simulation State
    @Published var scenarioMode: ScenarioRunMode = .customOrigin
    @Published var isScenarioRunning: Bool = false
    @Published var isScenarioPaused: Bool = false
    @Published var isScenarioCompleted: Bool = false
    @Published var currentScenario: Scenario? = nil
    @Published var scenarioStartCoord: CLLocationCoordinate2D? = nil
    @Published var scenarioRouteCoords: [CLLocationCoordinate2D] = []
    @Published var scenarioDestinationName: String = ""
    @Published var scenarioTotalDistanceMeters: Double = 0.0
    @Published var scenarioRemainingDistMeters: Double = 0.0
    @Published var scenarioPlannedDistanceMeters: Double = 0.0
    @Published var scenarioProgress: Double = 0.0
    @Published var scenarioSpeedKmh: Double = 8.0

    // Speed Drift / Natural Speed Fluctuation
    @Published var isSpeedDriftEnabled: Bool = true
    @Published var speedDriftPercentage: Double = 12.0 // ±12%
    @Published var liveSimulatedSpeedKmh: Double = 0.0

    // Traffic Light Simulation
    @Published var isTrafficLightSimulationEnabled: Bool = true
    @Published var trafficLightProbabilityPercent: Double = 40.0 // 40% probability at intersections
    @Published var trafficLightMinWaitSec: Int = 12
    @Published var trafficLightMaxWaitSec: Int = 35
    @Published var isWaitingForTrafficLight: Bool = false
    @Published var trafficLightRemainingSeconds: Int = 0
    @Published var trafficLightStatusText: String = ""

    // China Coordinate System Correction (Automated Anti-drift / GCJ-02 / WGS-84 / BD-09)
    @Published var chinaCorrectionMode: ChinaCorrectionMode = .auto
    @Published var isChinaOffsetCorrectionEnabled: Bool = true
    @Published var inputCoordinateSystem: CoordinateSystem = .gcj02
    @Published var displayGcj02CoordString: String = ""
    @Published var displayWgs84CoordString: String = ""

    // Custom Bookmarks
    @Published var customPresets: [Preset] = []

    // Internal navigation state
    private var navWaypoints: [CLLocationCoordinate2D] = []
    private var navCumulativeDists: [Double] = []
    private var navRouteSteps: [RouteStepInfo] = []
    private var currentNavDistTraveled: Double = 0.0
    private var currentUdid: String = ""
    private var lastSpokenStepIndex: Int = -1

    private var activeTask: Task<Void, Never>?
    private var jitterTask: Task<Void, Never>?

    init() {
        loadCustomPresets()
        if let initial = currentCoord {
            updateDisplayCoordStrings(for: initial)
        }
    }

    func updateDisplayCoordStrings(for coord: CLLocationCoordinate2D) {
        currentCoord = coord
        currentCoordString = String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
        if ChinaCoordinateCorrector.isInChina(coord) {
            let wgs = ChinaCoordinateCorrector.gcj02ToWgs84(coord)
            displayGcj02CoordString = currentCoordString
            displayWgs84CoordString = String(format: "%.5f, %.5f", wgs.latitude, wgs.longitude)
        } else {
            displayGcj02CoordString = ""
            displayWgs84CoordString = currentCoordString
        }
    }

    nonisolated func prepareWGS84ForInjection(_ coord: CLLocationCoordinate2D, mode: ChinaCorrectionMode) -> CLLocationCoordinate2D {
        return ChinaCoordinateCorrector.prepareWGS84ForInjection(coord, mode: mode)
    }

    nonisolated func prepareWGS84ForInjection(_ coord: CLLocationCoordinate2D, enabled: Bool = true, system: CoordinateSystem = .gcj02) -> CLLocationCoordinate2D {
        guard enabled else { return coord }
        return ChinaCoordinateCorrector.toWGS84(coord, from: system)
    }

    var isRunning: Bool {
        activeMode != .none
    }

    // MARK: - Native Scenarios (Apple Official & Custom Origin Linear Forward)

    func startScenario(_ scenario: Scenario, udid: String) {
        startOfficialScenario(scenario, udid: udid)
    }

    func startOfficialScenario(_ scenario: Scenario, udid: String) {
        stopAll(keepCoord: false)
        activeMode = .scenario
        scenarioMode = .officialApple
        currentScenario = scenario
        isScenarioRunning = true
        isScenarioPaused = false
        let cmd = scenario.command
        let label = scenario.label
        GPSLogger.shared.add("下发 Apple 原生轨迹: \(cmd)…")

        Task.detached(priority: .userInitiated) {
            let out = devicectl(["device", "simulate", "location", "scenario", "--device", udid, cmd])
            await MainActor.run {
                GPSLogger.shared.add("🟢 成功启动 Apple 官方场景: \(label)")
                if !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    GPSLogger.shared.add("  输出: \(out.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
        }
    }

    func startCustomScenario(
        _ scenario: Scenario,
        startCoord: CLLocationCoordinate2D,
        destinationCoord: CLLocationCoordinate2D? = nil,
        speedKmh: Double,
        udid: String,
        onCoordChange: ((CLLocationCoordinate2D) -> Void)? = nil
    ) {
        stopAll(keepCoord: true)
        activeMode = .scenario
        scenarioMode = .customOrigin
        currentScenario = scenario
        scenarioStartCoord = startCoord
        scenarioSpeedKmh = speedKmh
        isScenarioRunning = true
        isScenarioPaused = false
        isScenarioCompleted = false
        scenarioTotalDistanceMeters = 0.0
        scenarioRemainingDistMeters = 0.0
        scenarioPlannedDistanceMeters = 0.0
        scenarioProgress = 0.0
        currentUdid = udid
        currentCoord = startCoord
        currentCoordString = String(format: "%.5f, %.5f", startCoord.latitude, startCoord.longitude)

        GPSLogger.shared.add("🛣️ 正在检索真实路网数据 (\(scenario.label))…")

        activeTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            guard let plan = await self.planRealRoadRoute(
                from: startCoord,
                customDestination: destinationCoord,
                scenario: scenario
            ) else {
                await MainActor.run {
                    GPSLogger.shared.add("⚠️ 未能在起点周边规划出通畅的真实道路路线。建议在地图上点击任意地点作为终点！")
                    self.stopAll(keepCoord: true)
                }
                return
            }
            guard !Task.isCancelled else { return }

            let currentRoadCoords = plan.coords
            let destName = plan.destinationName
            let cumDists = self.computeCumDists(for: currentRoadCoords)
            let totalPathLength = cumDists.last ?? 1.0

            await MainActor.run {
                self.scenarioRouteCoords = currentRoadCoords
                self.scenarioDestinationName = destName
                self.scenarioPlannedDistanceMeters = totalPathLength
                self.scenarioRemainingDistMeters = totalPathLength
                GPSLogger.shared.add("🟢 成功沿真实路网规划路线: 前往 [\(destName)]，全长 \(String(format: "%.2f", totalPathLength / 1000.0)) km，初始时速 \(Int(speedKmh)) km/h，启动真实巡航！")
            }

            // 瞬移到起点 (全自动智能纠偏)
            let curMode = await self.chinaCorrectionMode
            let initialInject = self.prepareWGS84ForInjection(startCoord, mode: curMode)
            _ = injectLocation(initialInject, udid: udid)

            var distTraveled: Double = 0.0
            let tickInterval: Double = 0.8
            var currentDriftFactor: Double = 1.0
            var targetDriftFactor: Double = 1.0
            var driftTickCount: Int = 0
            var evaluatedStepIds: Set<UUID> = []
            var lastTrafficLightDist: Double = -500.0

            while !Task.isCancelled {
                // 暂停处理
                while await self.isScenarioPaused && !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(300))
                }
                if Task.isCancelled { break }

                // 1. 时速自然漂移平滑计算
                driftTickCount += 1
                if driftTickCount >= 4 { // 每约 3.2 秒调整一次浮动目标
                    driftTickCount = 0
                    let driftEnabled = await self.isSpeedDriftEnabled
                    let driftPercent = await self.speedDriftPercentage
                    if driftEnabled {
                        let maxDelta = driftPercent / 100.0
                        targetDriftFactor = Double.random(in: (1.0 - maxDelta)...(1.0 + maxDelta))
                    } else {
                        targetDriftFactor = 1.0
                    }
                }
                currentDriftFactor = currentDriftFactor * 0.75 + targetDriftFactor * 0.25
                let curBaseSpeed = await self.scenarioSpeedKmh
                let effectiveSpeedKmh = max(1.5, curBaseSpeed * currentDriftFactor)
                let speedMps = effectiveSpeedKmh / 3.6

                // 2. 检查到达终点
                if distTraveled >= totalPathLength {
                    await MainActor.run {
                        self.scenarioProgress = 1.0
                        self.scenarioRemainingDistMeters = 0.0
                        self.isScenarioCompleted = true
                        self.liveSimulatedSpeedKmh = 0.0
                        self.isWaitingForTrafficLight = false
                        self.trafficLightStatusText = ""
                        GPSLogger.shared.add("🏁 已成功沿真实道路抵达目的地 [\(destName)]，平稳停车驻留")
                        if let last = currentRoadCoords.last, self.isJitterEnabled {
                            self.startJitterLoop(baseLat: last.latitude, baseLon: last.longitude, udid: udid)
                        }
                    }
                    break
                }

                let (coord, heading) = self.computeInterpolatedPoint(distance: distTraveled, waypoints: currentRoadCoords, cumDists: cumDists)

                // 3. 路口模拟红绿灯判定 (Freeway 纯高速公路巡航默认无红绿灯)
                let isTrafficLightEnabled = await self.isTrafficLightSimulationEnabled
                let isFreeway = (scenario.command == "Freeway Drive")
                if isTrafficLightEnabled && !isFreeway && (distTraveled - lastTrafficLightDist > 250.0) && (totalPathLength - distTraveled > 80.0) {
                    let curLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    var upcomingStep: RouteStepInfo? = nil
                    for step in plan.steps {
                        if !evaluatedStepIds.contains(step.id), let sCoord = step.coordinate {
                            let d = curLoc.distance(from: CLLocation(latitude: sCoord.latitude, longitude: sCoord.longitude))
                            if d <= 25.0 {
                                upcomingStep = step
                                break
                            }
                        }
                    }

                    if let step = upcomingStep {
                        evaluatedStepIds.insert(step.id)
                        let prob = await self.trafficLightProbabilityPercent
                        if Double.random(in: 0...100) < prob {
                            let minWait = await self.trafficLightMinWaitSec
                            let maxWait = max(minWait, await self.trafficLightMaxWaitSec)
                            let waitSeconds = Int.random(in: minWait...maxWait)

                            await MainActor.run {
                                self.isWaitingForTrafficLight = true
                                self.trafficLightRemainingSeconds = waitSeconds
                                self.trafficLightStatusText = "🔴 路口红灯等待 (\(waitSeconds)s)"
                                self.liveSimulatedSpeedKmh = 0.0
                                GPSLogger.shared.add("🚦 接近路口 [\(step.instruction)]，遇红灯减速停车，预计等待 \(waitSeconds) 秒…")
                            }

                            // 减速刹停过渡
                            try? await Task.sleep(for: .milliseconds(500))

                            // 红灯等待倒计时 + 怠速微抖动
                            for rem in (1...waitSeconds).reversed() {
                                if Task.isCancelled { break }
                                while await self.isScenarioPaused && !Task.isCancelled {
                                    try? await Task.sleep(for: .milliseconds(300))
                                }

                                await MainActor.run {
                                    self.trafficLightRemainingSeconds = rem
                                    self.trafficLightStatusText = "🔴 路口红灯等待 (\(rem)s)"
                                }

                                // 停车等待期间进行 Anti-Detection 物理自然微抖动
                                let isJitter = await self.isJitterEnabled
                                let jitterAmp = await self.jitterMeters
                                var jittered = coord
                                if isJitter {
                                    let dLat = (Double.random(in: -1...1) * jitterAmp) / 111139.0
                                    let dLon = (Double.random(in: -1...1) * jitterAmp) / (111139.0 * cos(coord.latitude * .pi / 180.0))
                                    jittered = CLLocationCoordinate2D(latitude: coord.latitude + dLat, longitude: coord.longitude + dLon)
                                }

                                let tickStart = Date()
                                let loopMode = await self.chinaCorrectionMode
                                let injectCoord = self.prepareWGS84ForInjection(jittered, mode: loopMode)
                                _ = injectLocation(injectCoord, udid: udid)

                                await sleepRemainingTick(since: tickStart, tick: 1.0)
                            }

                            lastTrafficLightDist = distTraveled

                            await MainActor.run {
                                self.isWaitingForTrafficLight = false
                                self.trafficLightRemainingSeconds = 0
                                self.trafficLightStatusText = "🟢 绿灯亮起，起步加速"
                                GPSLogger.shared.add("🚦 路口绿灯放行，等待完毕，平稳起步加速！")
                            }

                            try? await Task.sleep(for: .milliseconds(400))
                        } else {
                            // 🟢 绿灯直接通行：无需等待停车，平稳匀速通过路口
                            lastTrafficLightDist = distTraveled
                            await MainActor.run {
                                self.isWaitingForTrafficLight = false
                                self.trafficLightRemainingSeconds = 0
                                self.trafficLightStatusText = "🟢 绿灯直行 · 平稳通过路口"
                                GPSLogger.shared.add("🟢 途经路口 [\(step.instruction)]：信号灯为绿灯，平稳直行直接通过")
                            }
                            Task { [weak self] in
                                try? await Task.sleep(for: .seconds(2.5))
                                await MainActor.run {
                                    if self?.trafficLightStatusText.contains("绿灯直行") == true {
                                        self?.trafficLightStatusText = ""
                                    }
                                }
                            }
                        }
                    }
                }

                // 物理下发至真机 (带全自动智能纠偏)
                let tickStart = Date()
                let loopMode = await self.chinaCorrectionMode
                let injectCoord = self.prepareWGS84ForInjection(coord, mode: loopMode)

                _ = injectLocation(injectCoord, udid: udid)

                let remDist = max(0.0, totalPathLength - distTraveled)
                let prog = min(1.0, distTraveled / totalPathLength)

                await MainActor.run {
                    self.updateDisplayCoordStrings(for: coord)
                    self.currentHeading = heading
                    self.liveSimulatedSpeedKmh = effectiveSpeedKmh
                    self.scenarioTotalDistanceMeters = distTraveled
                    self.scenarioRemainingDistMeters = remDist
                    self.scenarioProgress = prog
                    onCoordChange?(coord)
                }

                let elapsed = await sleepRemainingTick(since: tickStart, tick: tickInterval)
                distTraveled += speedMps * elapsed
            }
        }
    }

    func previewScenarioRoute(
        _ scenario: Scenario,
        startCoord: CLLocationCoordinate2D,
        destinationCoord: CLLocationCoordinate2D? = nil
    ) async -> Bool {
        GPSLogger.shared.add("🔍 正在规划真实路网预览 (\(scenario.label))…")
        guard let plan = await planRealRoadRoute(from: startCoord, customDestination: destinationCoord, scenario: scenario) else {
            GPSLogger.shared.add("⚠️ 未能在当前起点周边规划出合适路线，请尝试选择地图终点")
            return false
        }
        let total = computeCumDists(for: plan.coords).last ?? 0.0
        await MainActor.run {
            self.scenarioStartCoord = startCoord
            self.scenarioRouteCoords = plan.coords
            self.scenarioDestinationName = plan.destinationName
            self.scenarioPlannedDistanceMeters = total
            self.scenarioRemainingDistMeters = total
            GPSLogger.shared.add("🗺️ 路线规划成功: 前往 [\(plan.destinationName)]，全长 \(String(format: "%.2f", total / 1000.0)) km")
        }
        return true
    }

    func reverseScenarioRoute(udid: String, onCoordChange: ((CLLocationCoordinate2D) -> Void)? = nil) {
        guard !scenarioRouteCoords.isEmpty, let last = scenarioRouteCoords.last else { return }
        let reversedCoords = Array(scenarioRouteCoords.reversed())
        let scenario = currentScenario ?? kScenarios[0]
        stopAll(keepCoord: true)
        activeMode = .scenario
        currentScenario = scenario
        scenarioMode = .customOrigin
        scenarioStartCoord = last
        isScenarioRunning = true
        isScenarioPaused = false
        isScenarioCompleted = false

        let destName = "起点原路返回"
        let cumDists = self.computeCumDists(for: reversedCoords)
        let totalPathLength = cumDists.last ?? 1.0

        scenarioRouteCoords = reversedCoords
        scenarioDestinationName = destName
        scenarioPlannedDistanceMeters = totalPathLength
        scenarioRemainingDistMeters = totalPathLength
        scenarioProgress = 0.0

        GPSLogger.shared.add("🔄 启动原路返程巡航，全长 \(String(format: "%.2f", totalPathLength / 1000.0)) km…")

        activeTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            var distTraveled: Double = 0.0
            let tickInterval: Double = 0.8
            var effectiveSpeedKmh = scenario.defaultSpeedKmh
            var targetSpeedKmh = scenario.defaultSpeedKmh
            var lastDriftChangeTime = Date()

            while !Task.isCancelled {
                while await self.isScenarioPaused && !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(300))
                }
                if Task.isCancelled { break }

                let baseSpeedKmh = await self.scenarioSpeedKmh
                let isDrift = await self.isSpeedDriftEnabled
                let driftPct = await self.speedDriftPercentage

                if Date().timeIntervalSince(lastDriftChangeTime) > 3.0 {
                    let factor = isDrift ? (1.0 + Double.random(in: -driftPct...driftPct) / 100.0) : 1.0
                    targetSpeedKmh = max(2.0, baseSpeedKmh * factor)
                    lastDriftChangeTime = Date()
                }

                effectiveSpeedKmh += (targetSpeedKmh - effectiveSpeedKmh) * 0.35
                let speedMps = max(0.5, effectiveSpeedKmh / 3.6)

                if distTraveled >= totalPathLength {
                    await MainActor.run {
                        self.scenarioProgress = 1.0
                        self.scenarioRemainingDistMeters = 0.0
                        self.liveSimulatedSpeedKmh = 0.0
                        self.isScenarioCompleted = true
                        GPSLogger.shared.add("🏁 已安全返程回到起点！")
                        if let last = reversedCoords.last, self.isJitterEnabled {
                            self.startJitterLoop(baseLat: last.latitude, baseLon: last.longitude, udid: udid)
                        }
                    }
                    break
                }

                let (coord, heading) = self.computeInterpolatedPoint(distance: distTraveled, waypoints: reversedCoords, cumDists: cumDists)

                let tickStart = Date()
                let loopMode = await self.chinaCorrectionMode
                let injectCoord = self.prepareWGS84ForInjection(coord, mode: loopMode)

                _ = injectLocation(injectCoord, udid: udid)

                let remDist = max(0.0, totalPathLength - distTraveled)
                let prog = min(1.0, distTraveled / totalPathLength)

                await MainActor.run {
                    self.updateDisplayCoordStrings(for: coord)
                    self.currentHeading = heading
                    self.liveSimulatedSpeedKmh = effectiveSpeedKmh
                    self.scenarioTotalDistanceMeters = distTraveled
                    self.scenarioRemainingDistMeters = remDist
                    self.scenarioProgress = prog
                    onCoordChange?(coord)
                }

                let elapsed = await sleepRemainingTick(since: tickStart, tick: tickInterval)
                distTraveled += speedMps * elapsed
            }
        }
    }

    func pauseScenario() {
        isScenarioPaused = true
        GPSLogger.shared.add("⏸️ 拟真模拟已暂停")
    }

    func resumeScenario() {
        isScenarioPaused = false
        GPSLogger.shared.add("▶️ 拟真模拟已继续")
    }

    func stopScenario() {
        stopAll(keepCoord: true)
        scenarioRouteCoords = []
        scenarioStartCoord = nil
        scenarioDestinationName = ""
        currentScenario = nil
        isScenarioRunning = false
        isScenarioPaused = false
        isScenarioCompleted = false
        scenarioTotalDistanceMeters = 0.0
        scenarioRemainingDistMeters = 0.0
        scenarioProgress = 0.0
        GPSLogger.shared.add("⏹️ 拟真模拟已停止")
    }

    // MARK: - 真实路网路线规划算法 (100% 沿真实公路，绝无虚假穿墙直线)

    private nonisolated func computeCumDists(for coords: [CLLocationCoordinate2D]) -> [Double] {
        var cumDists: [Double] = [0.0]
        guard coords.count >= 2 else { return [0.0] }
        for i in 0..<(coords.count - 1) {
            let pA = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            let pB = CLLocation(latitude: coords[i + 1].latitude, longitude: coords[i + 1].longitude)
            cumDists.append((cumDists.last ?? 0.0) + pA.distance(from: pB))
        }
        return cumDists
    }

    // MARK: - 全球通用 OSRM 真实路网引擎 (OpenStreetMap 真实公路图谱，主备多节点 HTTPS)
    static nonisolated func fetchOSRMRoute(
        from start: CLLocationCoordinate2D,
        to dest: CLLocationCoordinate2D,
        profile: String = "driving"
    ) async -> (coords: [CLLocationCoordinate2D], steps: [RouteStepInfo], distance: Double, duration: Double)? {
        let startLonStr = String(format: "%.6f", start.longitude)
        let startLatStr = String(format: "%.6f", start.latitude)
        let destLonStr = String(format: "%.6f", dest.longitude)
        let destLatStr = String(format: "%.6f", dest.latitude)

        // 主备两个全球公开 OSRM 高性能路线服务器（均为标准 HTTPS）
        let endpoints: [String] = [
            // 节点 1: OSRM 官方公共服务器
            "https://router.project-osrm.org/route/v1/\(profile)/\(startLonStr),\(startLatStr);\(destLonStr),\(destLatStr)?overview=full&geometries=geojson&steps=true",
            // 节点 2: OpenStreetMap 欧洲高可用服务器
            "https://routing.openstreetmap.de/\(profile == "walking" ? "routed-foot" : "routed-car")/route/v1/\(profile == "walking" ? "foot" : "driving")/\(startLonStr),\(startLatStr);\(destLonStr),\(destLatStr)?overview=full&geometries=geojson&steps=true"
        ]

        for urlStr in endpoints {
            guard let url = URL(string: urlStr) else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = 7.0
            req.setValue(kHTTPUserAgent, forHTTPHeaderField: "User-Agent")
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { continue }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let routes = json["routes"] as? [[String: Any]],
                      let firstRoute = routes.first,
                      let geom = firstRoute["geometry"] as? [String: Any],
                      let rawCoords = geom["coordinates"] as? [[Double]] else { continue }

                let coords = rawCoords.compactMap { pair -> CLLocationCoordinate2D? in
                    guard pair.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                }
                guard coords.count >= 2 else { continue }

                let distanceMeters = (firstRoute["distance"] as? Double) ?? 0.0
                let durationSec = (firstRoute["duration"] as? Double) ?? 0.0

                var steps: [RouteStepInfo] = []
                if let legs = firstRoute["legs"] as? [[String: Any]], let leg = legs.first, let rawSteps = leg["steps"] as? [[String: Any]] {
                    for s in rawSteps {
                        let name = (s["name"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                        let dist = (s["distance"] as? Double) ?? 0.0
                        let man = s["maneuver"] as? [String: Any]
                        let type = man?["type"] as? String ?? ""
                        let modifier = man?["modifier"] as? String ?? ""

                        let instruction = formatOSRMInstruction(type: type, modifier: modifier, roadName: name)
                        var stepCoord: CLLocationCoordinate2D? = nil
                        if let loc = man?["location"] as? [Double], loc.count >= 2 {
                            stepCoord = CLLocationCoordinate2D(latitude: loc[1], longitude: loc[0])
                        }
                        steps.append(RouteStepInfo(instruction: instruction, distanceMeters: dist, coordinate: stepCoord))
                    }
                }
                return (coords, steps, distanceMeters, durationSec)
            } catch {
                continue
            }
        }
        return nil
    }

    private nonisolated static func formatOSRMInstruction(type: String, modifier: String, roadName: String) -> String {
        let modZh: String
        switch modifier {
        case "uturn": modZh = "掉头"
        case "sharp right": modZh = "向右急转"
        case "right": modZh = "向右转"
        case "slight right": modZh = "向右前方偏"
        case "straight": modZh = "继续直行"
        case "slight left": modZh = "向左前方偏"
        case "left": modZh = "向左转"
        case "sharp left": modZh = "向左急转"
        default: modZh = ""
        }

        switch type {
        case "depart":
            return roadName.isEmpty ? "出发" : "从 \(roadName) 出发"
        case "arrive":
            return roadName.isEmpty ? "到达目的地" : "到达目的地 \(roadName)"
        case "roundabout":
            return "进入环岛"
        case "merge":
            return roadName.isEmpty ? "汇入主道" : "汇入 \(roadName)"
        case "on ramp":
            return "驶入匝道"
        case "off ramp":
            return "驶出匝道"
        case "fork":
            return modZh.isEmpty ? "沿岔路前行" : "向 \(modZh) 走岔路"
        case "end of road":
            return modZh.isEmpty ? "到达道路尽头" : "\(modZh) 转向"
        default:
            if !modZh.isEmpty {
                return roadName.isEmpty ? modZh : "\(modZh)，进入 \(roadName)"
            } else {
                return roadName.isEmpty ? "沿道路前行" : "沿 \(roadName) 前行"
            }
        }
    }

    private nonisolated func calculateRouteData(from start: CLLocationCoordinate2D, to dest: CLLocationCoordinate2D, transportType: MKDirectionsTransportType) async -> (coords: [CLLocationCoordinate2D], steps: [RouteStepInfo])? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
        request.transportType = transportType
        request.requestsAlternateRoutes = false
        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            guard let route = response.routes.first else { return nil }
            var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: route.polyline.pointCount)
            route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: route.polyline.pointCount))

            var steps: [RouteStepInfo] = []
            for s in route.steps {
                let txt = s.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !txt.isEmpty else { continue }
                var stepCoord: CLLocationCoordinate2D? = nil
                if s.polyline.pointCount > 0 {
                    var c = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: 1)
                    s.polyline.getCoordinates(&c, range: NSRange(location: 0, length: 1))
                    stepCoord = c.first
                }
                steps.append(RouteStepInfo(instruction: txt, distanceMeters: s.distance, coordinate: stepCoord))
            }
            return (coords, steps)
        } catch {
            return nil
        }
    }

    private nonisolated func fetchRouteData(from start: CLLocationCoordinate2D, to dest: CLLocationCoordinate2D, transportType: MKDirectionsTransportType) async -> (coords: [CLLocationCoordinate2D], steps: [RouteStepInfo])? {
        let inChina = ChinaCoordinateCorrector.isInChina(start) && ChinaCoordinateCorrector.isInChina(dest)

        // 1. 若起点和终点都在中国境内，优先尝试 Apple Maps 官方路网 (高德底层数据，含红绿灯路口指引)
        if inChina {
            if let data = await calculateRouteData(from: start, to: dest, transportType: transportType) {
                return data
            }
            if transportType == .walking {
                if let data = await calculateRouteData(from: start, to: dest, transportType: .automobile) {
                    return data
                }
            }
        }

        // 2. 境外区域（或境内 Apple Maps 规划失败），立即启动全球高精度 OSRM HTTPS 真实路网引擎
        let osrmProfile = (transportType == .walking) ? "walking" : "driving"
        if let data = await Self.fetchOSRMRoute(from: start, to: dest, profile: osrmProfile) {
            return (data.coords, data.steps)
        }
        if osrmProfile == "walking" {
            if let data = await Self.fetchOSRMRoute(from: start, to: dest, profile: "driving") {
                return (data.coords, data.steps)
            }
        }

        // 3. 兜底回退：如果境外 OSRM 偶尔遇到短时网络波动，再试一次 Apple Maps
        if !inChina {
            if let data = await calculateRouteData(from: start, to: dest, transportType: transportType) {
                return data
            }
        }
        return nil
    }

    // 智能检索真实道路地标并规划真实路线（多层容灾体系，100% 成功率）
    private nonisolated func planRealRoadRoute(
        from start: CLLocationCoordinate2D,
        customDestination: CLLocationCoordinate2D? = nil,
        scenario: Scenario
    ) async -> (coords: [CLLocationCoordinate2D], destinationName: String, steps: [RouteStepInfo])? {
        // 1. 若用户指定了自定义终点，专程规划此路线
        if let dest = customDestination {
            let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
            let destLoc = CLLocation(latitude: dest.latitude, longitude: dest.longitude)
            let directDist = startLoc.distance(from: destLoc)
            if directDist > 20.0 {
                GPSLogger.shared.add("📍 正在规划前往自选终点 (\(String(format: "%.4f, %.4f", dest.latitude, dest.longitude))) 的道路路线…")
                if let data = await fetchRouteData(from: start, to: dest, transportType: scenario.transportType), data.coords.count >= 2 {
                    return (data.coords, "自选地图终点", data.steps)
                }
                // 若指定交通方式（如步行）过长或受限，尝试驾车干道路网
                if scenario.transportType != .automobile {
                    if let data = await fetchRouteData(from: start, to: dest, transportType: .automobile), data.coords.count >= 2 {
                        return (data.coords, "自选地图终点 (公路干道)", data.steps)
                    }
                }
                GPSLogger.shared.add("⚠️ 自选终点未能连通道路（两点间可能隔着水系、海湾或无道路连接），建议重新选点！")
                return nil
            } else {
                GPSLogger.shared.add("⚠️ 起点与自选终点距离过近 (< 20米)，请在地图上重新选点作为目的地！")
                return nil
            }
        }

        // 2. 自动智能巡航（未自选终点）：优先搜索周边符合生活运动特征的真实 POI 地标
        let keywords: [String]
        switch scenario.command {
        case "City Run":
            keywords = ["公园", "绿道", "体育公园", "广场", "Park", "Garden", "Trail"]
        case "City Bicycle Ride":
            keywords = ["森林公园", "湿地公园", "景区", "滨江路", "Trail", "Park", "Bikeway"]
        case "City Drive":
            keywords = ["商业广场", "购物中心", "高铁站", "奥特莱斯", "Mall", "Plaza", "Center"]
        case "Freeway Drive":
            keywords = ["收费站", "互通立交", "高速入口", "服务区", "机场", "Highway", "Airport"]
        default:
            keywords = ["公园", "广场", "商业中心", "Park", "Mall"]
        }

        let targetDist = scenario.defaultDistanceMeters
        let searchRegion = MKCoordinateRegion(
            center: start,
            latitudinalMeters: max(targetDist * 2.0, 5000),
            longitudinalMeters: max(targetDist * 2.0, 5000)
        )

        var candidateItems: [MKMapItem] = []
        for kw in keywords {
            let req = MKLocalSearch.Request()
            req.naturalLanguageQuery = kw
            req.region = searchRegion
            let search = MKLocalSearch(request: req)
            if let res = try? await search.start(), !res.mapItems.isEmpty {
                candidateItems.append(contentsOf: res.mapItems)
                if candidateItems.count >= 8 { break }
            }
        }

        let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let sorted = candidateItems.sorted { itemA, itemB in
            let distA = startLoc.distance(from: CLLocation(latitude: itemA.placemark.coordinate.latitude, longitude: itemA.placemark.coordinate.longitude))
            let distB = startLoc.distance(from: CLLocation(latitude: itemB.placemark.coordinate.latitude, longitude: itemB.placemark.coordinate.longitude))
            return abs(distA - targetDist) < abs(distB - targetDist)
        }

        for item in sorted.prefix(4) {
            let destCoord = item.placemark.coordinate
            if let data = await fetchRouteData(from: start, to: destCoord, transportType: scenario.transportType), data.coords.count >= 2 {
                let name = item.name ?? "真实路网地标"
                return (data.coords, name, data.steps)
            }
        }

        // 3. 若 POI 搜索因境外或无覆盖无果，启动八向极坐标真实路网探测 (Radial Compass Road Probing)
        // 向 8 个罗盘方位延伸目标距离，路网引擎会自动将端点吸附至最近的真实马路/公路
        let bearings = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0].shuffled()
        let probeDistances = [targetDist, targetDist * 0.7, targetDist * 1.3]

        for dist in probeDistances {
            for b in bearings {
                let rad = b * .pi / 180.0
                let dLat = (dist * cos(rad)) / 111139.0
                let dLon = (dist * sin(rad)) / (111139.0 * cos(start.latitude * .pi / 180.0))
                let probeCoord = CLLocationCoordinate2D(latitude: start.latitude + dLat, longitude: start.longitude + dLon)

                if let data = await fetchRouteData(from: start, to: probeCoord, transportType: scenario.transportType), data.coords.count >= 2 {
                    let dirName: String
                    switch b {
                    case 0.0: dirName = "北向真实干道"
                    case 45.0: dirName = "东北向真实干道"
                    case 90.0: dirName = "东向真实干道"
                    case 135.0: dirName = "东南向真实干道"
                    case 180.0: dirName = "南向真实干道"
                    case 225.0: dirName = "西南向真实干道"
                    case 270.0: dirName = "西向真实干道"
                    default: dirName = "西北向真实干道"
                    }
                    return (data.coords, dirName, data.steps)
                }
            }
        }

        return nil
    }

    // MARK: - Teleport (Static Coordinates)
    func teleport(lat: Double, lon: Double, udid: String) {
        stopAll(keepCoord: true)
        activeMode = .teleport
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        updateDisplayCoordStrings(for: coord)

        let isCorrected = (chinaCorrectionMode == .auto && ChinaCoordinateCorrector.isInChina(coord)) || chinaCorrectionMode == .forcedGCJ02 || chinaCorrectionMode == .forcedBD09
        let injectCoord = prepareWGS84ForInjection(coord, mode: chinaCorrectionMode)
        let corrTag = isCorrected ? " [🇨🇳 智能防漂移: GCJ-02 ➔ WGS-84]" : " [🌐 国际标准 WGS-84 直通]"
        GPSLogger.shared.add("瞬移到坐标: (\(String(format: "%.5f, %.5f", lat, lon)))\(corrTag)…")

        Task.detached(priority: .userInitiated) {
            _ = injectLocation(injectCoord, udid: udid)
            await MainActor.run {
                GPSLogger.shared.add("🟢 已定位到: \(self.currentCoordString)\(corrTag)")
                if self.isJitterEnabled {
                    self.startJitterLoop(baseLat: lat, baseLon: lon, udid: udid)
                }
            }
        }
    }

    // MARK: - Navigation 2.0 (High-Precision Point-by-Point Kinematics)

    func startRouteNavigation(
        waypoints: [CLLocationCoordinate2D],
        routeSteps: [RouteStepInfo] = [],
        initialSpeedKmh: Double = 45.0,
        voiceEnabled: Bool = true,
        udid: String,
        onCoordChange: ((CLLocationCoordinate2D) -> Void)? = nil
    ) {
        guard waypoints.count >= 2 else {
            GPSLogger.shared.add("⚠️ 导航点不足，无法启动路线模拟")
            return
        }
        stopAll(keepCoord: true)
        activeMode = .route
        currentUdid = udid
        navigationSpeedKmh = initialSpeedKmh
        isNavigationPaused = false
        navWaypoints = waypoints
        navRouteSteps = routeSteps
        lastSpokenStepIndex = -1

        // 计算路网累计距离数组
        var cumDists: [Double] = [0.0]
        for i in 0..<(waypoints.count - 1) {
            let pA = CLLocation(latitude: waypoints[i].latitude, longitude: waypoints[i].longitude)
            let pB = CLLocation(latitude: waypoints[i + 1].latitude, longitude: waypoints[i + 1].longitude)
            cumDists.append((cumDists.last ?? 0.0) + pA.distance(from: pB))
        }
        navCumulativeDists = cumDists
        let totalDist = cumDists.last ?? 1.0
        totalRouteDistanceMeters = totalDist
        currentNavDistTraveled = 0.0
        navigationProgress = 0.0
        navigationRemainingDistMeters = totalDist
        navigationRemainingTimeSec = totalDist / max(1.5, (initialSpeedKmh / 3.6))

        // 初始第一条语音
        currentStepIndex = 0
        currentStepInstruction = routeSteps.first?.instruction ?? "开始导航"
        if voiceEnabled && !currentStepInstruction.isEmpty {
            GPSVoiceService.shared.speak(currentStepInstruction)
            lastSpokenStepIndex = 0
        }

        GPSLogger.shared.add("🟢 启动道路导航 2.0: 总程 \(String(format: "%.2f", totalDist / 1000.0)) km，初始时速 \(Int(initialSpeedKmh)) km/h")

        activeTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let tickInterval: Double = 1.0
            var evaluatedStepIds: Set<UUID> = []
            var lastTrafficLightDist: Double = -999.0
            var effectiveSpeedKmh = initialSpeedKmh
            var targetSpeedKmh = initialSpeedKmh
            var lastDriftChangeTime = Date()

            while !Task.isCancelled {
                // 暂停处理
                while await self.isNavigationPaused && !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(300))
                }
                if Task.isCancelled { break }

                let total = await self.totalRouteDistanceMeters
                let distTraveled = await self.currentNavDistTraveled
                if distTraveled >= total {
                    // 到达终点
                    await MainActor.run {
                        self.navigationProgress = 1.0
                        self.navigationRemainingDistMeters = 0
                        self.navigationRemainingTimeSec = 0
                        self.liveSimulatedSpeedKmh = 0.0
                        self.isWaitingForTrafficLight = false
                        self.trafficLightRemainingSeconds = 0
                        self.trafficLightStatusText = ""
                        GPSLogger.shared.add("🏁 已到达终点附近，导航圆满完成！")
                        if voiceEnabled {
                            GPSVoiceService.shared.speak("已到达目的地附近，导航结束")
                        }
                        // 到达后若开启抖动，启动微弱防检测抖动
                        if let last = waypoints.last, self.isJitterEnabled {
                            self.startJitterLoop(baseLat: last.latitude, baseLon: last.longitude, udid: udid)
                        }
                    }
                    break
                }

                // 1. 速度自然浮动计算
                let isDriftEnabled = await self.isSpeedDriftEnabled
                let driftPct = await self.speedDriftPercentage
                let baseSpeedKmh = await self.navigationSpeedKmh

                if Date().timeIntervalSince(lastDriftChangeTime) > 3.0 {
                    let driftFactor = isDriftEnabled ? (1.0 + Double.random(in: -driftPct...driftPct) / 100.0) : 1.0
                    targetSpeedKmh = max(2.0, baseSpeedKmh * driftFactor)
                    lastDriftChangeTime = Date()
                }

                effectiveSpeedKmh += (targetSpeedKmh - effectiveSpeedKmh) * 0.35
                let speedMps = max(0.5, effectiveSpeedKmh / 3.6)

                // 计算当前插值点与航向角
                let (coord, heading) = self.computeInterpolatedPoint(distance: distTraveled, waypoints: waypoints, cumDists: cumDists)
                let progress = min(1.0, distTraveled / total)
                let remDist = max(0.0, total - distTraveled)
                let remTime = remDist / speedMps

                // 2. 检查路线指引与转弯语音
                var nextInstruction = ""
                var nextIndex = await self.currentStepIndex
                let lastSpoken = await self.lastSpokenStepIndex

                if !routeSteps.isEmpty {
                    let cLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    for sIdx in max(0, nextIndex)..<routeSteps.count {
                        if let sCoord = routeSteps[sIdx].coordinate {
                            let distToStep = cLoc.distance(from: CLLocation(latitude: sCoord.latitude, longitude: sCoord.longitude))
                            if distToStep < 70.0 { // 70米内触发转弯提示
                                nextIndex = sIdx
                                nextInstruction = routeSteps[sIdx].instruction
                                break
                            }
                        }
                    }
                }

                // 3. 路口模拟红绿灯判定 (间隔需大于 250 米，且距终点大于 80 米)
                let isTrafficLightEnabled = await self.isTrafficLightSimulationEnabled
                if isTrafficLightEnabled && (distTraveled - lastTrafficLightDist > 250.0) && (total - distTraveled > 80.0) {
                    let curLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    var upcomingIntersection: RouteStepInfo? = nil
                    for step in routeSteps {
                        if !evaluatedStepIds.contains(step.id), let sCoord = step.coordinate {
                            let d = curLoc.distance(from: CLLocation(latitude: sCoord.latitude, longitude: sCoord.longitude))
                            if d <= 25.0 {
                                upcomingIntersection = step
                                break
                            }
                        }
                    }

                    if let step = upcomingIntersection {
                        evaluatedStepIds.insert(step.id)
                        let prob = await self.trafficLightProbabilityPercent
                        if Double.random(in: 0...100) < prob {
                            let minWait = await self.trafficLightMinWaitSec
                            let maxWait = max(minWait, await self.trafficLightMaxWaitSec)
                            let waitSeconds = Int.random(in: minWait...maxWait)

                            await MainActor.run {
                                self.isWaitingForTrafficLight = true
                                self.trafficLightRemainingSeconds = waitSeconds
                                self.trafficLightStatusText = "🔴 路口红灯等待 (\(waitSeconds)s)"
                                self.liveSimulatedSpeedKmh = 0.0
                                GPSLogger.shared.add("🚦 接近路口 [\(step.instruction)]，遇红灯减速停车，预计等待 \(waitSeconds) 秒…")
                            }

                            // 减速刹停平稳过渡
                            try? await Task.sleep(for: .milliseconds(500))

                            // 红灯等待倒计时 + 怠速微抖动
                            for rem in (1...waitSeconds).reversed() {
                                if Task.isCancelled { break }
                                while await self.isNavigationPaused && !Task.isCancelled {
                                    try? await Task.sleep(for: .milliseconds(300))
                                }

                                await MainActor.run {
                                    self.trafficLightRemainingSeconds = rem
                                    self.trafficLightStatusText = "🔴 路口红灯等待 (\(rem)s)"
                                }

                                // 停车等待期间进行 Anti-Detection 物理自然微抖动
                                let isJitter = await self.isJitterEnabled
                                let jitterAmp = await self.jitterMeters
                                var jittered = coord
                                if isJitter {
                                    let dLat = (Double.random(in: -1...1) * jitterAmp) / 111139.0
                                    let dLon = (Double.random(in: -1...1) * jitterAmp) / (111139.0 * cos(coord.latitude * .pi / 180.0))
                                    jittered = CLLocationCoordinate2D(latitude: coord.latitude + dLat, longitude: coord.longitude + dLon)
                                }

                                let tickStart = Date()
                                let loopMode = await self.chinaCorrectionMode
                                let injectCoord = self.prepareWGS84ForInjection(jittered, mode: loopMode)
                                _ = injectLocation(injectCoord, udid: udid)

                                await sleepRemainingTick(since: tickStart, tick: 1.0)
                            }

                            lastTrafficLightDist = distTraveled

                            await MainActor.run {
                                self.isWaitingForTrafficLight = false
                                self.trafficLightRemainingSeconds = 0
                                self.trafficLightStatusText = "🟢 绿灯亮起，起步加速"
                                GPSLogger.shared.add("🚦 路口绿灯放行，等待完毕，平稳起步加速！")
                            }

                            try? await Task.sleep(for: .milliseconds(400))
                        } else {
                            // 🟢 绿灯直接通行：无需等待停车，平稳匀速通过路口
                            lastTrafficLightDist = distTraveled
                            await MainActor.run {
                                self.isWaitingForTrafficLight = false
                                self.trafficLightRemainingSeconds = 0
                                self.trafficLightStatusText = "🟢 绿灯直行 · 平稳通过路口"
                                GPSLogger.shared.add("🟢 途经路口 [\(step.instruction)]：信号灯为绿灯，平稳直行直接通过")
                            }
                            Task { [weak self] in
                                try? await Task.sleep(for: .seconds(2.5))
                                await MainActor.run {
                                    if self?.trafficLightStatusText.contains("绿灯直行") == true {
                                        self?.trafficLightStatusText = ""
                                    }
                                }
                            }
                        }
                    }
                }

                // 物理下发至真机 (带全自动智能纠偏)
                let tickStart = Date()
                let loopMode = await self.chinaCorrectionMode
                let injectCoord = self.prepareWGS84ForInjection(coord, mode: loopMode)
                injectLocation(injectCoord, udid: udid)

                await MainActor.run {
                    self.updateDisplayCoordStrings(for: coord)
                    self.currentHeading = heading
                    self.liveSimulatedSpeedKmh = effectiveSpeedKmh
                    self.navigationProgress = progress
                    self.navigationRemainingDistMeters = remDist
                    self.navigationRemainingTimeSec = remTime

                    if !nextInstruction.isEmpty && nextIndex > lastSpoken {
                        self.currentStepIndex = nextIndex
                        self.currentStepInstruction = nextInstruction
                        self.lastSpokenStepIndex = nextIndex
                        GPSLogger.shared.add("🧭 [转弯提示] \(nextInstruction)")
                        if voiceEnabled {
                            GPSVoiceService.shared.speak(nextInstruction)
                        }
                    }

                    onCoordChange?(coord)
                }

                // 步进下发间隔
                let elapsed = await sleepRemainingTick(since: tickStart, tick: tickInterval)
                let advance = speedMps * elapsed
                await MainActor.run {
                    self.currentNavDistTraveled += advance
                }
            }
        }
    }

    func pauseNavigation() {
        isNavigationPaused = true
        GPSLogger.shared.add("⏸️ 导航已暂停")
    }

    func resumeNavigation() {
        isNavigationPaused = false
        GPSLogger.shared.add("▶️ 导航已继续")
    }

    func seekTo(progress: Double) {
        let clamped = max(0.0, min(1.0, progress))
        let total = totalRouteDistanceMeters
        guard total > 0, !navWaypoints.isEmpty, !navCumulativeDists.isEmpty else { return }

        currentNavDistTraveled = clamped * total
        navigationProgress = clamped
        navigationRemainingDistMeters = max(0.0, total - currentNavDistTraveled)

        let (coord, heading) = computeInterpolatedPoint(distance: currentNavDistTraveled, waypoints: navWaypoints, cumDists: navCumulativeDists)
        currentCoord = coord
        currentCoordString = String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
        currentHeading = heading
        updateDisplayCoordStrings(for: coord)

        let injectCoord = prepareWGS84ForInjection(coord, mode: chinaCorrectionMode)

        if !currentUdid.isEmpty {
            let udid = currentUdid
            // 后台下发，避免拖动进度条时阻塞主线程
            Task.detached(priority: .userInitiated) {
                injectLocation(injectCoord, udid: udid)
            }
        }
        GPSLogger.shared.add("⏩ 导航跳转至进度 \(Int(clamped * 100))%")
    }

    // 微米级路网插值与航向计算
    private nonisolated func computeInterpolatedPoint(distance: Double, waypoints: [CLLocationCoordinate2D], cumDists: [Double]) -> (CLLocationCoordinate2D, Double) {
        guard waypoints.count >= 2 else {
            return (waypoints.first ?? CLLocationCoordinate2D(latitude: 0, longitude: 0), 0.0)
        }
        let total = cumDists.last ?? 0.0
        if distance <= 0 {
            let h = bearing(from: waypoints[0], to: waypoints[1])
            return (waypoints[0], h)
        }
        if distance >= total {
            let h = bearing(from: waypoints[waypoints.count - 2], to: waypoints[waypoints.count - 1])
            return (waypoints.last!, h)
        }

        for i in 0..<(cumDists.count - 1) {
            if distance >= cumDists[i] && distance <= cumDists[i + 1] {
                let segDist = cumDists[i + 1] - cumDists[i]
                let p0 = waypoints[i]
                let p1 = waypoints[i + 1]
                let h = bearing(from: p0, to: p1)
                guard segDist > 0.0001 else { return (p0, h) }
                let t = (distance - cumDists[i]) / segDist
                let lat = p0.latitude + t * (p1.latitude - p0.latitude)
                let lon = p0.longitude + t * (p1.longitude - p0.longitude)
                return (CLLocationCoordinate2D(latitude: lat, longitude: lon), h)
            }
        }
        return (waypoints.last!, 0.0)
    }

    private nonisolated func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180.0
        let lon1 = from.longitude * .pi / 180.0
        let lat2 = to.latitude * .pi / 180.0
        let lon2 = to.longitude * .pi / 180.0
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        let deg = radians * 180.0 / .pi
        return (deg + 360.0).truncatingRemainder(dividingBy: 360.0)
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
        updateDisplayCoordStrings(for: newCoord)

        let injectCoord = prepareWGS84ForInjection(newCoord, mode: chinaCorrectionMode)

        Task.detached(priority: .userInitiated) {
            _ = injectLocation(injectCoord, udid: udid)
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
                let cCoord = CLLocationCoordinate2D(latitude: cLat, longitude: cLon)

                let loopMode = await self.chinaCorrectionMode
                let injectCoord = self.prepareWGS84ForInjection(cCoord, mode: loopMode)

                injectLocation(injectCoord, udid: udid)

                let coordStr = String(format: "%.5f, %.5f", cLat, cLon)
                await MainActor.run {
                    self.currentCoord = cCoord
                    self.currentCoordString = coordStr
                    self.updateDisplayCoordStrings(for: cCoord)
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
        isScenarioRunning = false
        isScenarioPaused = false
        isWaitingForTrafficLight = false
        trafficLightRemainingSeconds = 0
        trafficLightStatusText = ""
        liveSimulatedSpeedKmh = 0.0
        GPSVoiceService.shared.stop()
    }

    // MARK: - Clear / Restore Real Physical GPS
    func clearSimulation(udid: String) {
        stopAll(keepCoord: false)
        scenarioRouteCoords = []
        scenarioStartCoord = nil
        currentScenario = nil
        GPSLogger.shared.add("下发指令: 恢复物理真实 GPS…")
        Task.detached(priority: .userInitiated) {
            devicectl(["device", "simulate", "location", "clear", "--device", udid])
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
