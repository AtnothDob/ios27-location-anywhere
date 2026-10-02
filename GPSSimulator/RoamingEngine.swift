import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - Roaming Persona

enum RoamingPersona: String, CaseIterable, Identifiable {
    case commuter = "💼 都市白领"
    case explorer = "🏖️ 城市漫步"
    case slowLife = "☕ 文艺慢调"
    case active   = "🏃 活力运动"
    case random   = "🎲 随机探索"

    var id: String { rawValue }

    var summary: String {
        switch self {
        case .commuter:
            return "住所 ➔ 晨间咖啡 ➔ 商务园区 ➔ 午餐便当 ➔ 下午茶/商圈 ➔ 晚市聚餐 ➔ 归宿"
        case .explorer:
            return "住所 ➔ 早餐 ➔ 热门名胜/地标 ➔ 特色美食 ➔ 公园/美术馆 ➔ 晚市夜景 ➔ 归宿"
        case .slowLife:
            return "住所 ➔ 面包烘焙 ➔ 城市公园 ➔ 独立书店/咖啡馆 ➔ 慢调晚餐 ➔ 归宿"
        case .active:
            return "住所 ➔ 晨跑公园 ➔ 营养早餐 ➔ 健身运动中心 ➔ 绿道漫步 ➔ 生鲜超市 ➔ 归宿"
        case .random:
            return "完全随机抽取周边 4~6 个真实商户与公共地标串联成一日生活"
        }
    }
}

// MARK: - Roaming Stop Model

struct RoamingStop: Identifiable, Hashable {
    let id = UUID()
    var index: Int
    var title: String          // 如 "第 1 站 · 晨间咖啡"
    var poiName: String        // 如 "Blue Bottle Coffee"
    var categoryTag: String    // 如 "☕ 咖啡馆"
    var icon: String           // SF Symbol
    var coordinate: CLLocationCoordinate2D
    var stayMinutes: Int       // 驻留时长（分钟）
    var plannedTimeStr: String // 预计抵达/活动时间

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RoamingStop, rhs: RoamingStop) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Roaming Execution State

enum RoamingState: Equatable {
    case idle
    case traveling(legIndex: Int, fromName: String, toName: String, progress: Double)
    case staying(stopIndex: Int, stopName: String, remainingSeconds: Int, totalSeconds: Int)
    case paused
    case completed

    var description: String {
        switch self {
        case .idle:
            return "待启动"
        case .traveling(_, let fromName, let toName, let progress):
            return "🚗 前往中: \(fromName) ➔ \(toName) (\(Int(progress * 100))%)"
        case .staying(_, let stopName, let remaining, _):
            let mins = remaining / 60
            let secs = remaining % 60
            return "📍 驻留中: \(stopName) (剩余 \(mins)分\(secs)秒)"
        case .paused:
            return "⏸️ 已暂停"
        case .completed:
            return "🏁 今日漫游行程已圆满完成"
        }
    }
}

// MARK: - Roaming Engine

@MainActor
final class RoamingEngine: ObservableObject {
    @Published var persona: RoamingPersona = .commuter
    @Published var stops: [RoamingStop] = []
    @Published var state: RoamingState = .idle
    @Published var isAccelerated: Bool = true // 快进演示模式（默认开启，方便测试）
    @Published var travelSpeedKmh: Double = 35.0
    @Published var isGenerating: Bool = false
    @Published var statusMessage: String = "准备生成今日生活轨迹"
    @Published var fullRouteCoordinates: [CLLocationCoordinate2D] = []

    // 运行中的任务控制
    private var roamingTask: Task<Void, Never>?
    private var stayCountdownTask: Task<Void, Never>?
    private var jitterTask: Task<Void, Never>?
    private var currentLegIndex: Int = 0
    private var isPausedState: Bool = false

    // MARK: - 生成一日生活轨迹 (纯程序化 + 真实 POI 调度)
    func generateDailyPlan(center: CLLocationCoordinate2D, reRoll: Bool = false) async -> Bool {
        isGenerating = true
        statusMessage = "正在检索周边 3km 真实商铺与地标…"

        // 获取周边真实 POIs
        let rawItems = await fetchPOIs(around: center, radiusMeters: 3500)
        guard !rawItems.isEmpty else {
            statusMessage = "⚠️ 周边未检索到足够商铺，建议在地图移动选点后重试"
            isGenerating = false
            return false
        }

        statusMessage = "已发现 \(rawItems.count) 个真实地点，正在智能编排生活日程…"

        // 获取历史访问记录以去重（每日不重复机制）
        let historyKey = "GPSSimulator_VisitedPOIs"
        var visited = UserDefaults.standard.stringArray(forKey: historyKey) ?? []


        // 分类桶
        var cafes: [MKMapItem] = []
        var restaurants: [MKMapItem] = []
        var parksAndCulture: [MKMapItem] = []
        var shoppingAndWork: [MKMapItem] = []
        var others: [MKMapItem] = []

        for item in rawItems {
            let cat = item.pointOfInterestCategory
            if cat == .cafe || cat == .bakery {
                cafes.append(item)
            } else if cat == .restaurant || cat == .nightlife {
                restaurants.append(item)
            } else if cat == .park || cat == .nationalPark || cat == .museum || cat == .library {
                parksAndCulture.append(item)
            } else if cat == .store || cat == .fitnessCenter || cat == .movieTheater {
                shoppingAndWork.append(item)
            } else {
                others.append(item)
            }
        }

        // 辅助选择函数（优先选择未访问过的地点，每日不重复）
        func pickOne(from list: [MKMapItem], fallback: [MKMapItem], usedNames: Set<String>) -> MKMapItem? {
            let combined = list.isEmpty ? fallback : list
            let unvisited = combined.filter { item in
                let name = item.name ?? ""
                return !name.isEmpty && !usedNames.contains(name) && !visited.contains(name)
            }
            if let candidate = unvisited.randomElement() {
                return candidate
            }
            // 回退到未在本轮使用的候选
            let unusedInRound = combined.filter { item in
                let name = item.name ?? ""
                return !name.isEmpty && !usedNames.contains(name)
            }
            return unusedInRound.randomElement() ?? combined.randomElement()
        }

        var selectedStops: [RoamingStop] = []
        var usedNames: Set<String> = []

        // 0. 起点（住所 / 出发地）
        selectedStops.append(RoamingStop(
            index: 0,
            title: "🏠 住所 · 出发",
            poiName: "温馨寓所 (出发地)",
            categoryTag: "住宅/公寓",
            icon: "house.fill",
            coordinate: center,
            stayMinutes: 0,
            plannedTimeStr: "08:00"
        ))

        // 根据人设进行日程编排
        switch persona {
        case .commuter:
            // 1. 晨间咖啡/早餐
            if let p1 = pickOne(from: cafes, fallback: rawItems, usedNames: usedNames) {
                let name = p1.name ?? "晨间咖啡馆"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 1,
                    title: "第 1 站 · 早餐咖啡",
                    poiName: name,
                    categoryTag: "☕ 咖啡轻食",
                    icon: "cup.and.saucer.fill",
                    coordinate: p1.placemark.coordinate,
                    stayMinutes: Int.random(in: 20...35),
                    plannedTimeStr: "08:25"
                ))
            }

            // 2. 商务办公/产业园区
            if let p2 = pickOne(from: shoppingAndWork, fallback: rawItems, usedNames: usedNames) {
                let name = p2.name ?? "商务办公园区"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 2,
                    title: "第 2 站 · 上午工作/商务",
                    poiName: name,
                    categoryTag: "🏢 商务/商圈",
                    icon: "building.2.fill",
                    coordinate: p2.placemark.coordinate,
                    stayMinutes: Int.random(in: 120...180),
                    plannedTimeStr: "09:30"
                ))
            }

            // 3. 午餐食堂/餐厅
            if let p3 = pickOne(from: restaurants, fallback: rawItems, usedNames: usedNames) {
                let name = p3.name ?? "午市餐厅"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 3,
                    title: "第 3 站 · 午间就餐",
                    poiName: name,
                    categoryTag: "🍽️ 美食就餐",
                    icon: "fork.knife",
                    coordinate: p3.placemark.coordinate,
                    stayMinutes: Int.random(in: 45...60),
                    plannedTimeStr: "12:15"
                ))
            }

            // 4. 下午茶/商圈
            if let p4 = pickOne(from: cafes, fallback: shoppingAndWork, usedNames: usedNames) {
                let name = p4.name ?? "下午茶歇店"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 4,
                    title: "第 4 站 · 下午茶歇",
                    poiName: name,
                    categoryTag: "🍰 甜品烘焙",
                    icon: "takeoutbag.and.cup.and.straw.fill",
                    coordinate: p4.placemark.coordinate,
                    stayMinutes: Int.random(in: 30...45),
                    plannedTimeStr: "15:00"
                ))
            }

            // 5. 晚市聚餐
            if let p5 = pickOne(from: restaurants, fallback: rawItems, usedNames: usedNames) {
                let name = p5.name ?? "晚宴餐馆"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 5,
                    title: "第 5 站 · 晚间聚餐",
                    poiName: name,
                    categoryTag: "🍲 特色晚市",
                    icon: "wineglass.fill",
                    coordinate: p5.placemark.coordinate,
                    stayMinutes: Int.random(in: 60...90),
                    plannedTimeStr: "18:30"
                ))
            }

        case .explorer:
            // 旅行家：早点 -> 热门地标 -> 特色美食 -> 城市绿地/博物馆 -> 晚市夜景
            if let p1 = pickOne(from: cafes, fallback: rawItems, usedNames: usedNames) {
                let name = p1.name ?? "晨起风味早餐"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 1, title: "第 1 站 · 风味早茶", poiName: name, categoryTag: "🥐 当地风味",
                    icon: "sun.horizon.fill", coordinate: p1.placemark.coordinate,
                    stayMinutes: Int.random(in: 30...45), plannedTimeStr: "08:30"
                ))
            }
            if let p2 = pickOne(from: parksAndCulture, fallback: rawItems, usedNames: usedNames) {
                let name = p2.name ?? "城市知名地标"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 2, title: "第 2 站 · 地标打卡", poiName: name, categoryTag: "🏛️ 名胜古迹",
                    icon: "camera.fill", coordinate: p2.placemark.coordinate,
                    stayMinutes: Int.random(in: 60...90), plannedTimeStr: "10:00"
                ))
            }
            if let p3 = pickOne(from: restaurants, fallback: rawItems, usedNames: usedNames) {
                let name = p3.name ?? "特色午市料理"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 3, title: "第 3 站 · 当地美食", poiName: name, categoryTag: "🍱 招牌料理",
                    icon: "fork.knife", coordinate: p3.placemark.coordinate,
                    stayMinutes: Int.random(in: 50...70), plannedTimeStr: "12:30"
                ))
            }
            if let p4 = pickOne(from: parksAndCulture, fallback: shoppingAndWork, usedNames: usedNames) {
                let name = p4.name ?? "城市公园与展馆"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 4, title: "第 4 站 · 绿地漫步", poiName: name, categoryTag: "🌳 城市公园",
                    icon: "leaf.fill", coordinate: p4.placemark.coordinate,
                    stayMinutes: Int.random(in: 45...75), plannedTimeStr: "14:45"
                ))
            }
            if let p5 = pickOne(from: shoppingAndWork, fallback: restaurants, usedNames: usedNames) {
                let name = p5.name ?? "特色商圈夜市"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 5, title: "第 5 站 · 商圈夜游", poiName: name, categoryTag: "🛍️ 繁华商街",
                    icon: "bag.fill", coordinate: p5.placemark.coordinate,
                    stayMinutes: Int.random(in: 60...90), plannedTimeStr: "18:00"
                ))
            }

        case .slowLife:
            // 文艺慢调：面包坊 -> 城市公园 -> 独立书店/咖啡馆 -> 慢调晚餐
            if let p1 = pickOne(from: cafes, fallback: rawItems, usedNames: usedNames) {
                let name = p1.name ?? "手作烘焙面包坊"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 1, title: "第 1 站 · 早午烘焙", poiName: name, categoryTag: "🥖 手工面包",
                    icon: "cup.and.saucer.fill", coordinate: p1.placemark.coordinate,
                    stayMinutes: Int.random(in: 40...60), plannedTimeStr: "09:30"
                ))
            }
            if let p2 = pickOne(from: parksAndCulture, fallback: rawItems, usedNames: usedNames) {
                let name = p2.name ?? "静谧绿地花园"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 2, title: "第 2 站 · 绿道闲步", poiName: name, categoryTag: "🌿 生态公园",
                    icon: "figure.walk", coordinate: p2.placemark.coordinate,
                    stayMinutes: Int.random(in: 60...80), plannedTimeStr: "11:00"
                ))
            }
            if let p3 = pickOne(from: cafes, fallback: shoppingAndWork, usedNames: usedNames) {
                let name = p3.name ?? "慢调书店与咖啡"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 3, title: "第 3 站 · 深度阅读", poiName: name, categoryTag: "📚 书吧咖啡",
                    icon: "book.fill", coordinate: p3.placemark.coordinate,
                    stayMinutes: Int.random(in: 90...120), plannedTimeStr: "14:00"
                ))
            }
            if let p4 = pickOne(from: restaurants, fallback: rawItems, usedNames: usedNames) {
                let name = p4.name ?? "慢生活小馆"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 4, title: "第 4 站 · 恬静晚餐", poiName: name, categoryTag: "🍷 私房餐饮",
                    icon: "wineglass.fill", coordinate: p4.placemark.coordinate,
                    stayMinutes: Int.random(in: 60...80), plannedTimeStr: "18:00"
                ))
            }

        case .active:
            // 活力运动：晨跑公园 -> 营养早点 -> 健身运动中心 -> 绿道漫步 -> 生鲜超市
            if let p1 = pickOne(from: parksAndCulture, fallback: rawItems, usedNames: usedNames) {
                let name = p1.name ?? "环湖跑步公园"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 1, title: "第 1 站 · 晨间慢跑", poiName: name, categoryTag: "🏃 慢跑公园",
                    icon: "figure.run", coordinate: p1.placemark.coordinate,
                    stayMinutes: Int.random(in: 35...50), plannedTimeStr: "07:15"
                ))
            }
            if let p2 = pickOne(from: cafes, fallback: rawItems, usedNames: usedNames) {
                let name = p2.name ?? "高蛋白早餐厅"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 2, title: "第 2 站 · 营养早餐", poiName: name, categoryTag: "🥑 健康轻食",
                    icon: "carrot.fill", coordinate: p2.placemark.coordinate,
                    stayMinutes: Int.random(in: 25...35), plannedTimeStr: "08:30"
                ))
            }
            if let p3 = pickOne(from: shoppingAndWork, fallback: rawItems, usedNames: usedNames) {
                let name = p3.name ?? "运动健身中心"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 3, title: "第 3 站 · 力量器械", poiName: name, categoryTag: "🏋️ 健身中心",
                    icon: "dumbbell.fill", coordinate: p3.placemark.coordinate,
                    stayMinutes: Int.random(in: 60...90), plannedTimeStr: "10:30"
                ))
            }
            if let p4 = pickOne(from: shoppingAndWork, fallback: rawItems, usedNames: usedNames) {
                let name = p4.name ?? "有机生鲜超市"
                usedNames.insert(name)
                selectedStops.append(RoamingStop(
                    index: 4, title: "第 4 站 · 果蔬采购", poiName: name, categoryTag: "🛒 超市采购",
                    icon: "cart.fill", coordinate: p4.placemark.coordinate,
                    stayMinutes: Int.random(in: 30...45), plannedTimeStr: "17:30"
                ))
            }

        case .random:
            // 完全随机 4~5 个不同地点
            let shuffled = rawItems.shuffled()
            var count = 0
            for item in shuffled {
                guard count < 4 else { break }
                let name = item.name ?? ""
                guard !name.isEmpty && !usedNames.contains(name) else { continue }
                usedNames.insert(name)
                count += 1
                selectedStops.append(RoamingStop(
                    index: count,
                    title: "第 \(count) 站 · 城市偶遇",
                    poiName: name,
                    categoryTag: item.pointOfInterestCategory?.rawValue.replacingOccurrences(of: "MKPOICategory", with: "") ?? "精选地点",
                    icon: "sparkles",
                    coordinate: item.placemark.coordinate,
                    stayMinutes: Int.random(in: 30...60),
                    plannedTimeStr: "\(8 + count * 2):00"
                ))
            }
        }

        // 最终站：返程归巢（回到起点）
        selectedStops.append(RoamingStop(
            index: selectedStops.count,
            title: "🏠 寓所 · 归宿休眠",
            poiName: "温馨寓所 (归巢夜宿)",
            categoryTag: "住宅/公寓",
            icon: "moon.stars.fill",
            coordinate: center,
            stayMinutes: 480, // 夜间驻留
            plannedTimeStr: "21:30"
        ))

        // 计算全天完整闭环路网 Polyline
        statusMessage = "正在规划连接 \(selectedStops.count) 个站点的道路轨迹…"
        var allCoords: [CLLocationCoordinate2D] = []
        for i in 0..<(selectedStops.count - 1) {
            let start = selectedStops[i].coordinate
            let end = selectedStops[i + 1].coordinate
            let legCoords = await calculateLegRoute(from: start, to: end)
            allCoords.append(contentsOf: legCoords)
        }

        self.stops = selectedStops
        self.fullRouteCoordinates = allCoords
        self.state = .idle
        self.isGenerating = false
        self.statusMessage = "✅ 成功生成【\(persona.rawValue)】今日专属生活轨迹（共 \(selectedStops.count) 个真实节点）"

        // 更新访问历史记录（保留最新 120 条）
        visited.append(contentsOf: usedNames)
        if visited.count > 120 {
            visited.removeFirst(visited.count - 120)
        }
        UserDefaults.standard.set(visited, forKey: historyKey)

        return true
    }

    // MARK: - 漫游运行执行闭环
    func startRoaming(udid: String, gps: GPSController, mapVM: MapViewModel) {
        guard stops.count >= 2 else {
            statusMessage = "⚠️ 请先点击生成今日漫游轨迹"
            return
        }

        stopRoaming()
        gps.stopAll(keepCoord: true)
        gps.activeMode = .roaming
        currentLegIndex = 0
        isPausedState = false

        GPSLogger.shared.add("🚶 启动智能漫游模拟 (模式: \(isAccelerated ? "⚡ 快进演示" : "⏱️ 1:1 真实挂机"))")
        GPSVoiceService.shared.speak("漫游模拟启动，开始今日生活轨迹")

        roamingTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let totalStops = await self.stops.count
            for leg in 0..<(totalStops - 1) {
                if Task.isCancelled { break }

                let fromStop = await self.stops[leg]
                let toStop = await self.stops[leg + 1]

                await MainActor.run {
                    self.currentLegIndex = leg
                    self.state = .traveling(legIndex: leg, fromName: fromStop.poiName, toName: toStop.poiName, progress: 0.0)
                    GPSLogger.shared.add("🚗 赶往下一站: 从 [\(fromStop.poiName)] ➔ [\(toStop.poiName)]")
                    GPSVoiceService.shared.speak("出发前往下一站，\(toStop.poiName)")
                }

                // 规划该单段路线
                let waypoints = await self.calculateLegRoute(from: fromStop.coordinate, to: toStop.coordinate)
                guard !waypoints.isEmpty else { continue }

                // 行驶过程（点对点微米级平滑下发）
                let speedKmh = await self.isAccelerated ? 60.0 : self.travelSpeedKmh
                let speedMps = max(1.5, speedKmh / 3.6)
                var currentDist: Double = 0.0

                // 累积各段距离
                var cumDists: [Double] = [0.0]
                for i in 0..<(waypoints.count - 1) {
                    let d = CLLocation(latitude: waypoints[i].latitude, longitude: waypoints[i].longitude)
                        .distance(from: CLLocation(latitude: waypoints[i + 1].latitude, longitude: waypoints[i + 1].longitude))
                    cumDists.append((cumDists.last ?? 0.0) + d)
                }
                let totalLegDist = cumDists.last ?? 1.0

                while !Task.isCancelled && currentDist < totalLegDist {
                    // 处理暂停
                    while await self.isPausedState && !Task.isCancelled {
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                    if Task.isCancelled { break }

                    // 根据 currentDist 插值坐标
                    let coord = self.interpolateCoordinate(distance: currentDist, waypoints: waypoints, cumDists: cumDists)
                    let progress = min(1.0, currentDist / totalLegDist)

                    // 注入到手机 (带中国区坐标全自动纠偏)
                    let tickStart = Date()
                    let loopMode = await gps.chinaCorrectionMode
                    let injectCoord = gps.prepareWGS84ForInjection(coord, mode: loopMode)

                    injectLocation(injectCoord, udid: udid)

                    await MainActor.run {
                        gps.currentCoord = coord
                        gps.currentCoordString = String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
                        gps.updateDisplayCoordStrings(for: coord)
                        self.state = .traveling(legIndex: leg, fromName: fromStop.poiName, toName: toStop.poiName, progress: progress)
                        if mapVM.isTrackingCar {
                            mapVM.cameraPosition = .region(MKCoordinateRegion(center: coord, latitudinalMeters: 800, longitudinalMeters: 800))
                        }
                    }

                    let elapsed = await sleepRemainingTick(since: tickStart, tick: 1.0)
                    currentDist += speedMps * elapsed
                }

                if Task.isCancelled { break }

                // 2. 抵达目的地并进入驻留状态
                let staySeconds = await self.isAccelerated ? 15 : (toStop.stayMinutes * 60)
                await MainActor.run {
                    GPSLogger.shared.add("📍 已到达 [\(toStop.poiName)]，计划停留 \(toStop.stayMinutes) 分钟 (模拟倒计时 \(staySeconds)s)")
                    GPSVoiceService.shared.speak("已到达\(toStop.poiName)，开始停留")
                }

                // 驻留倒计时循环（伴随拟真自然抖动）
                var remaining = Double(staySeconds)
                while !Task.isCancelled && remaining > 0 {
                    while await self.isPausedState && !Task.isCancelled {
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                    if Task.isCancelled { break }

                    // 微弱高斯自然抖动 (±1.5米)
                    let jLat = (Double.random(in: -1...1) * 1.5) / 111320.0
                    let jLon = (Double.random(in: -1...1) * 1.5) / (111320.0 * cos(toStop.coordinate.latitude * .pi / 180.0))
                    let jitteredCoord = CLLocationCoordinate2D(
                        latitude: toStop.coordinate.latitude + jLat,
                        longitude: toStop.coordinate.longitude + jLon
                    )

                    let tickStart = Date()
                    let loopMode = await gps.chinaCorrectionMode
                    let injectJitter = gps.prepareWGS84ForInjection(jitteredCoord, mode: loopMode)

                    injectLocation(injectJitter, udid: udid)

                    let currentRemaining = Int(remaining.rounded(.up))
                    await MainActor.run {
                        gps.currentCoord = jitteredCoord
                        gps.currentCoordString = String(format: "%.5f, %.5f", jitteredCoord.latitude, jitteredCoord.longitude)
                        gps.updateDisplayCoordStrings(for: jitteredCoord)
                        self.state = .staying(stopIndex: leg + 1, stopName: toStop.poiName, remainingSeconds: currentRemaining, totalSeconds: staySeconds)
                    }

                    let sleepSec: Double = await self.isAccelerated ? 1 : 2
                    let elapsed = await sleepRemainingTick(since: tickStart, tick: sleepSec)
                    remaining -= elapsed
                }
            }

            // 全部行程结束
            await MainActor.run {
                self.state = .completed
                GPSLogger.shared.add("🏁 今日漫游日程已全部圆满完成，回到寓所休眠")
                GPSVoiceService.shared.speak("今日漫游行程已圆满结束，已安全返回住所")
            }
        }
    }

    func pauseRoaming() {
        isPausedState = true
        state = .paused
        GPSLogger.shared.add("⏸️ 漫游已暂停")
    }

    func resumeRoaming() {
        isPausedState = false
        GPSLogger.shared.add("▶️ 漫游已恢复继续")
    }

    func stopRoaming() {
        roamingTask?.cancel()
        roamingTask = nil
        stayCountdownTask?.cancel()
        stayCountdownTask = nil
        jitterTask?.cancel()
        jitterTask = nil
        state = .idle
        isPausedState = false
    }

    // MARK: - 内部辅助算法

    private nonisolated func interpolateCoordinate(distance: Double, waypoints: [CLLocationCoordinate2D], cumDists: [Double]) -> CLLocationCoordinate2D {
        guard waypoints.count >= 2 else { return waypoints.first ?? CLLocationCoordinate2D(latitude: 0, longitude: 0) }
        let total = cumDists.last ?? 0.0
        if distance <= 0 { return waypoints.first! }
        if distance >= total { return waypoints.last! }

        for i in 0..<(cumDists.count - 1) {
            if distance >= cumDists[i] && distance <= cumDists[i + 1] {
                let segmentDist = cumDists[i + 1] - cumDists[i]
                guard segmentDist > 0.0001 else { return waypoints[i] }
                let t = (distance - cumDists[i]) / segmentDist
                let p0 = waypoints[i]
                let p1 = waypoints[i + 1]
                let lat = p0.latitude + t * (p1.latitude - p0.latitude)
                let lon = p0.longitude + t * (p1.longitude - p0.longitude)
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        return waypoints.last!
    }

    private func calculateLegRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> [CLLocationCoordinate2D] {
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        req.transportType = .automobile
        req.requestsAlternateRoutes = false

        let directions = MKDirections(request: req)
        if let resp = try? await directions.calculate(), let route = resp.routes.first {
            var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: route.polyline.pointCount)
            route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: route.polyline.pointCount))
            return coords
        }
        // 若规划失败则直线回退
        return [from, to]
    }

    private func fetchPOIs(around center: CLLocationCoordinate2D, radiusMeters: Double) async -> [MKMapItem] {
        let req = MKLocalPointsOfInterestRequest(center: center, radius: radiusMeters)
        req.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .cafe, .bakery, .restaurant, .nightlife,
            .park, .nationalPark, .museum, .library,
            .store, .fitnessCenter, .movieTheater, .amusementPark
        ])
        let search = MKLocalSearch(request: req)
        if let resp = try? await search.start(), !resp.mapItems.isEmpty {
            return resp.mapItems
        }

        // 回退机制：通用关键词搜索
        var fallbackItems: [MKMapItem] = []
        for kw in ["Cafe", "Restaurant", "Park", "Store"] {
            let kwReq = MKLocalSearch.Request()
            kwReq.naturalLanguageQuery = kw
            kwReq.region = MKCoordinateRegion(center: center, latitudinalMeters: radiusMeters, longitudinalMeters: radiusMeters)
            let s = MKLocalSearch(request: kwReq)
            if let r = try? await s.start() {
                fallbackItems.append(contentsOf: r.mapItems)
            }
        }
        return fallbackItems
    }
}
