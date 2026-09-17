import SwiftUI
import MapKit

// MARK: - Control Tabs

enum ControlTab: String, CaseIterable, Identifiable {
    case cruise   = "📍 巡航瞬移"
    case route    = "🛣️ 道路导航"
    case scenario = "🏃 原生拟真"
    case joystick = "🕹️ 摇杆微调"

    var id: String { rawValue }
}

enum RouteTransportMode: String, CaseIterable, Identifiable {
    case automobile = "automobile"
    case walking    = "walking"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .automobile: return "🚗 驾车"
        case .walking:    return "🚶 步行"
        }
    }
    var mkType: MKDirectionsTransportType {
        switch self {
        case .automobile: return .automobile
        case .walking:    return .walking
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var scanner = DeviceScanner()
    @StateObject private var gps     = GPSController()
    @StateObject private var logger  = GPSLogger.shared
    @StateObject private var mapVM   = MapViewModel()

    // Device
    @AppStorage("lastSelectedUDID") private var selectedUDID: String = ""

    // Active Control Tab
    @State private var selectedTab: ControlTab = .cruise

    // Coordinates & Presets
    @State private var selectedPresetID: String = "kDefault_0"
    @State private var latText: String = "37.33490"
    @State private var lonText: String = "-122.00900"
    @State private var newBookmarkName: String = ""
    @State private var showingAddBookmark: Bool = false

    // Cruise Settings
    @State private var speedMode: SpeedMode = .bike
    @State private var loopRadiusMeters: Double = 250.0

    // Route Navigation Settings
    @State private var routeTransportMode: RouteTransportMode = .automobile
    @State private var routeSpeedKmh: Double = 40.0

    // Scenario
    @State private var selectedScenario: Scenario = kScenarios[0]

    // Joystick Settings
    @State private var joystickStepMeters: Double = 10.0

    var body: some View {
        HSplitView {
            // ── 左侧控制面板 ─────────────────────────────────
            leftControlPanel
                .frame(minWidth: 420, idealWidth: 440, maxWidth: 480)
                .background(Color(nsColor: .windowBackgroundColor))

            // ── 右侧可视化地图 ─────────────────────────────────
            rightMapPanel
                .frame(minWidth: 500)
        }
        .frame(minWidth: 960, minHeight: 680)
        .onAppear {
            syncInitialDevice()
        }
        .onChange(of: scanner.devices) { _, devices in
            selectBestDevice(from: devices)
        }
        .onKeyPress(.upArrow) {
            handleKeyboardNudge(.north)
            return .handled
        }
        .onKeyPress(.downArrow) {
            handleKeyboardNudge(.south)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            handleKeyboardNudge(.west)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            handleKeyboardNudge(.east)
            return .handled
        }
    }

    private func selectBestDevice(from devices: [DeviceInfo]) {
        if !selectedUDID.isEmpty && devices.contains(where: { $0.id == selectedUDID }) {
            return
        }
        // 优先选择处于连接状态的有线 USB 设备
        if let usb = devices.first(where: { $0.isUSB && $0.isConnected }) {
            selectedUDID = usb.id
            return
        }
        // 其次选择任意有线 USB 设备
        if let usb = devices.first(where: { $0.isUSB }) {
            selectedUDID = usb.id
            return
        }
        // 其次选择已连接的设备
        if let conn = devices.first(where: { $0.isConnected }) {
            selectedUDID = conn.id
            return
        }
        if let first = devices.first {
            selectedUDID = first.id
        }
    }

    private func syncInitialDevice() {
        selectBestDevice(from: scanner.devices)
        if let lat = Double(latText), let lon = Double(lonText) {
            mapVM.targetCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            mapVM.moveTo(coordinate: mapVM.targetCoordinate)
        }
    }

    private func handleKeyboardNudge(_ dir: NudgeDirection) {
        guard selectedTab == .joystick, !selectedUDID.isEmpty else { return }
        gps.nudge(direction: dir, stepMeters: joystickStepMeters, udid: selectedUDID)
        if let current = gps.currentCoord {
            latText = String(format: "%.5f", current.latitude)
            lonText = String(format: "%.5f", current.longitude)
            mapVM.targetCoordinate = current
        }
    }

    // MARK: - Left Panel
    var leftControlPanel: some View {
        VStack(spacing: 0) {
            // 顶部状态栏
            headerBar

            // 主配置滚动视图
            ScrollView {
                VStack(spacing: 12) {
                    deviceSection
                    tabSelectorSection

                    switch selectedTab {
                    case .cruise:
                        cruiseSection
                    case .route:
                        routeSection
                    case .scenario:
                        scenarioSection
                    case .joystick:
                        joystickSection
                    }

                    antiDetectionSection
                    restoreRealGPSButton
                    logSection
                }
                .padding(14)
            }
        }
    }

    // MARK: Header Bar
    var headerBar: some View {
        HStack {
            Image(systemName: "location.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("iOS GPS 轨迹模拟器")
                    .font(.headline)
                Text("CoreDevice 硬件级位置注入引擎")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if gps.isRunning {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("\(gps.activeMode.rawValue): \(gps.currentCoordString)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.green.opacity(0.12), in: Capsule())
            } else {
                Text("待命中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: Device Section
    var deviceSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Picker("", selection: $selectedUDID) {
                        if scanner.devices.isEmpty {
                            Text("⚠️ 未发现物理设备").tag("")
                        }
                        ForEach(scanner.devices) { dev in
                            Text(dev.displayName).tag(dev.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    Button {
                        Task { await scanner.refresh() }
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }

                HStack(spacing: 6) {
                    Text(scanner.dotChar)
                        .foregroundStyle(.green)
                        .font(.system(size: 13, design: .monospaced))
                    Text(scanner.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("自动热插拔", isOn: $scanner.isAutoScanning)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
            }
        } label: {
            Label("目标 iOS 真机", systemImage: "iphone")
                .font(.subheadline.bold())
        }
    }

    // MARK: Tab Selector Section
    var tabSelectorSection: some View {
        Picker("", selection: $selectedTab) {
            ForEach(ControlTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 2)
    }

    // MARK: - Tab 1: Cruise & Teleport Section
    var cruiseSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                // 预设选择
                HStack {
                    Text("地标收藏:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $selectedPresetID) {
                        Section(header: Text("官方热门地标")) {
                            ForEach(Array(kDefaultPresets.enumerated()), id: \.offset) { idx, p in
                                Text(p.name).tag("kDefault_\(idx)")
                            }
                        }
                        if !gps.customPresets.isEmpty {
                            Section(header: Text("我的自定义收藏")) {
                                ForEach(gps.customPresets) { p in
                                    Text("⭐ \(p.name)").tag(p.id.uuidString)
                                }
                            }
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .onChange(of: selectedPresetID) { _, newID in
                        applyPreset(id: newID)
                    }

                    Button {
                        newBookmarkName = ""
                        showingAddBookmark = true
                    } label: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    .buttonStyle(.borderless)
                    .help("收藏当前坐标")
                }

                // 坐标输入行
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("纬度:").font(.caption).foregroundStyle(.secondary)
                        TextField("37.33490", text: $latText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                    HStack(spacing: 4) {
                        Text("经度:").font(.caption).foregroundStyle(.secondary)
                        TextField("-122.00900", text: $lonText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }

                    Button {
                        syncFromMapTarget()
                    } label: {
                        Image(systemName: "mappin.and.ellipse")
                    }
                    .help("从右侧地图选点同步坐标")

                    Spacer()
                }

                // 瞬移按钮
                Button {
                    guard !selectedUDID.isEmpty,
                          let lat = Double(latText),
                          let lon = Double(lonText) else { return }
                    gps.teleport(lat: lat, lon: lon, udid: selectedUDID)
                    mapVM.moveTo(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                } label: {
                    Label("立即瞬移到此坐标 (静态)", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(selectedUDID.isEmpty)

                Divider()

                // 环形巡航设置
                VStack(alignment: .leading, spacing: 8) {
                    Text("环形巡航参数")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Picker("巡航速度", selection: $speedMode) {
                        ForEach(SpeedMode.allCases) { m in
                            Text(m.label).tag(m)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Text("巡航半径: \(Int(loopRadiusMeters)) 米")
                            .font(.caption)
                            .frame(width: 110, alignment: .leading)
                        Slider(value: $loopRadiusMeters, in: 50...1200, step: 25)
                    }

                    Button {
                        guard !selectedUDID.isEmpty else { return }
                        if gps.activeMode == .loop {
                            gps.stopAll(keepCoord: true)
                        } else {
                            guard let lat = Double(latText), let lon = Double(lonText) else { return }
                            gps.startLoop(lat: lat, lon: lon, speed: speedMode, radiusMeters: loopRadiusMeters, udid: selectedUDID)
                            mapVM.moveTo(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), meters: loopRadiusMeters * 3)
                        }
                    } label: {
                        Label(gps.activeMode == .loop ? "停止环形巡航" : "启动环形巡航",
                              systemImage: gps.activeMode == .loop ? "stop.fill" : "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(gps.activeMode == .loop ? .orange : .blue)
                    .controlSize(.large)
                    .disabled(selectedUDID.isEmpty)
                }
            }
        } label: {
            Label("坐标与环形巡航", systemImage: "bicycle")
                .font(.subheadline.bold())
        }
        .sheet(isPresented: $showingAddBookmark) {
            addBookmarkSheet
        }
    }

    // MARK: Add Bookmark Sheet
    var addBookmarkSheet: some View {
        VStack(spacing: 14) {
            Text("收藏当前地点")
                .font(.headline)

            TextField("地点名称 (如 我的办公室、常去咖啡厅)", text: $newBookmarkName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)

            Text("坐标: \(latText), \(lonText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("取消") {
                    showingAddBookmark = false
                }
                Spacer()
                Button("保存") {
                    guard !newBookmarkName.isEmpty,
                          let lat = Double(latText),
                          let lon = Double(lonText) else { return }
                    gps.addCustomPreset(name: newBookmarkName, lat: lat, lon: lon)
                    showingAddBookmark = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newBookmarkName.isEmpty)
            }
            .frame(width: 280)
        }
        .padding(20)
    }

    private func applyPreset(id: String) {
        if id.starts(with: "kDefault_"),
           let idxStr = id.split(separator: "_").last,
           let idx = Int(idxStr), idx < kDefaultPresets.count {
            let p = kDefaultPresets[idx]
            latText = String(format: "%.5f", p.lat)
            lonText = String(format: "%.5f", p.lon)
            mapVM.targetCoordinate = CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon)
            mapVM.moveTo(coordinate: mapVM.targetCoordinate)
        } else if let custom = gps.customPresets.first(where: { $0.id.uuidString == id }) {
            latText = String(format: "%.5f", custom.lat)
            lonText = String(format: "%.5f", custom.lon)
            mapVM.targetCoordinate = CLLocationCoordinate2D(latitude: custom.lat, longitude: custom.lon)
            mapVM.moveTo(coordinate: mapVM.targetCoordinate)
        }
    }

    private func syncFromMapTarget() {
        latText = String(format: "%.5f", mapVM.targetCoordinate.latitude)
        lonText = String(format: "%.5f", mapVM.targetCoordinate.longitude)
        GPSLogger.shared.add("已从地图选点同步坐标: \(latText), \(lonText)")
    }

    // MARK: - Tab 2: Route Navigation Section
    var routeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("基于 Apple MapKit 真实道路规划，沿马路行进")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // 终点与途经点管理
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("导航终点:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(String(format: "%.5f, %.5f", mapVM.targetCoordinate.latitude, mapVM.targetCoordinate.longitude))")
                            .font(.system(size: 11, design: .monospaced))
                        Spacer()
                        Button("设为终点") {
                            syncFromMapTarget()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }

                    HStack {
                        Text("途经点 (\(mapVM.waypoints.count) 个):")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("➕ 加当前选点为途经点") {
                            mapVM.addWaypoint(coordinate: mapVM.targetCoordinate)
                            GPSLogger.shared.add("已添加途经点: \(String(format: "%.5f, %.5f", mapVM.targetCoordinate.latitude, mapVM.targetCoordinate.longitude))")
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)

                        if !mapVM.waypoints.isEmpty {
                            Button("清空") {
                                mapVM.clearWaypoints()
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    }

                    if !mapVM.waypoints.isEmpty {
                        VStack(spacing: 4) {
                            ForEach(Array(mapVM.waypoints.enumerated()), id: \.element.id) { idx, wp in
                                HStack {
                                    Circle()
                                        .fill(.orange)
                                        .frame(width: 18, height: 18)
                                        .overlay(Text("\(idx + 1)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white))
                                    Text(wp.name)
                                        .font(.caption)
                                    Text(String(format: "(%.4f, %.4f)", wp.coordinate.latitude, wp.coordinate.longitude))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button {
                                        mapVM.removeWaypoint(id: wp.id)
                                    } label: {
                                        Image(systemName: "xmark.circle")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }

                Divider()

                // 出行方式与偏好设置
                VStack(alignment: .leading, spacing: 6) {
                    Picker("出行方式", selection: $routeTransportMode) {
                        ForEach(RouteTransportMode.allCases) { m in
                            Text(m.label).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        Toggle("🛣️ 避开高速", isOn: $mapVM.avoidHighways)
                            .font(.caption)
                        Toggle("💰 避开收费站", isOn: $mapVM.avoidTolls)
                            .font(.caption)
                        Spacer()
                        Toggle("🔊 语音播报", isOn: $mapVM.voiceGuidanceEnabled)
                            .font(.caption)
                    }
                }

                HStack {
                    Text("模拟速度: \(Int(routeSpeedKmh)) km/h")
                        .font(.caption)
                        .frame(width: 120, alignment: .leading)
                    Slider(value: $routeSpeedKmh, in: 5...120, step: 5)
                }

                Button {
                    guard let start = gps.currentCoord ?? (Double(latText).flatMap { lat in Double(lonText).map { lon in CLLocationCoordinate2D(latitude: lat, longitude: lon) } }) else {
                        return
                    }
                    Task {
                        _ = await mapVM.calculateRoute(from: start, to: mapVM.targetCoordinate, transportType: routeTransportMode.mkType)
                    }
                } label: {
                    if mapVM.isCalculatingRoute {
                        ProgressView().controlSize(.small)
                        Text("Apple Maps 正在规划真实道路路线…")
                    } else {
                        Label("计算路线 (Apple Maps)", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(mapVM.isCalculatingRoute)

                if let err = mapVM.routeError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if !mapVM.routeCoordinates.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("总里程: \(String(format: "%.1f", mapVM.routeDistanceMeters / 1000.0)) km")
                            Spacer()
                            Text("预计耗时: \(Int(mapVM.routeExpectedTravelTime / 60)) 分钟")
                            Spacer()
                            Text("节点: \(mapVM.routeCoordinates.count) 个")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        // 实时导航转弯 HUD 横幅（模拟中显示）
                        if gps.activeMode == .route && !gps.currentStepInstruction.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.turn.up.right.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("当前指引:")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                    Text(gps.currentStepInstruction)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.green)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        }

                        // 逐向转弯指引列表 (Turn-by-turn steps)
                        if !mapVM.routeSteps.isEmpty {
                            DisclosureGroup("查看详细导航指引 (\(mapVM.routeSteps.count) 步)") {
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 4) {
                                        ForEach(Array(mapVM.routeSteps.enumerated()), id: \.element.id) { idx, step in
                                            HStack(spacing: 6) {
                                                Image(systemName: step.iconName)
                                                    .font(.caption)
                                                    .foregroundStyle(idx == gps.currentStepIndex && gps.activeMode == .route ? .green : .blue)
                                                    .frame(width: 16)
                                                Text("\(idx + 1). \(step.instruction)")
                                                    .font(.caption)
                                                    .foregroundStyle(idx == gps.currentStepIndex && gps.activeMode == .route ? .green : .primary)
                                                Spacer()
                                                Text(step.distanceDisplay)
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.vertical, 2)
                                            Divider()
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .frame(maxHeight: 120)
                            }
                            .font(.caption)
                        }

                        Button {
                            guard !selectedUDID.isEmpty else { return }
                            if gps.activeMode == .route {
                                gps.stopAll(keepCoord: true)
                            } else {
                                gps.startRouteNavigation(
                                    waypoints: mapVM.routeCoordinates,
                                    routeSteps: mapVM.routeSteps,
                                    speedKmh: routeSpeedKmh,
                                    voiceEnabled: mapVM.voiceGuidanceEnabled,
                                    udid: selectedUDID
                                )
                            }
                        } label: {
                            Label(gps.activeMode == .route ? "停止路线模拟" : "启动道路模拟导航 (含语音)",
                                  systemImage: gps.activeMode == .route ? "stop.fill" : "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(gps.activeMode == .route ? .orange : .green)
                        .controlSize(.large)
                        .disabled(selectedUDID.isEmpty)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        } label: {
            Label("真实道路导航模拟", systemImage: "arrow.triangle.swap")
                .font(.subheadline.bold())
        }
    }

    // MARK: - Tab 3: Native Scenario Section
    var scenarioSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Apple CoreLocation 系统官方拟真模型，轨迹最逼真")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("", selection: $selectedScenario) {
                    ForEach(kScenarios) { s in
                        Text(s.label).tag(s)
                    }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)

                Button {
                    guard !selectedUDID.isEmpty else { return }
                    gps.startScenario(selectedScenario, udid: selectedUDID)
                } label: {
                    Label("开始模拟该原生场景", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedUDID.isEmpty)
            }
        } label: {
            Label("Apple 官方拟真场景", systemImage: "figure.run")
                .font(.subheadline.bold())
        }
    }

    // MARK: - Tab 4: Joystick Section
    var joystickSection: some View {
        GroupBox {
            VStack(spacing: 10) {
                HStack {
                    Text("单次步长:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $joystickStepMeters) {
                        Text("5 米").tag(5.0)
                        Text("10 米").tag(10.0)
                        Text("25 米").tag(25.0)
                        Text("50 米").tag(50.0)
                        Text("100 米").tag(100.0)
                    }
                    .pickerStyle(.segmented)
                }

                // 3x3 八方向摇杆控制盘
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        nudgeButton(label: "↖", dir: .northWest)
                        nudgeButton(label: "↑ 北", dir: .north)
                        nudgeButton(label: "↗", dir: .northEast)
                    }
                    HStack(spacing: 6) {
                        nudgeButton(label: "← 西", dir: .west)
                        Button {
                            syncFromMapTarget()
                        } label: {
                            Image(systemName: "scope")
                                .font(.headline)
                                .frame(width: 54, height: 40)
                        }
                        .buttonStyle(.bordered)
                        .help("对齐目标点")

                        nudgeButton(label: "东 →", dir: .east)
                    }
                    HStack(spacing: 6) {
                        nudgeButton(label: "↙", dir: .southWest)
                        nudgeButton(label: "↓ 南", dir: .south)
                        nudgeButton(label: "↘", dir: .southEast)
                    }
                }
                .padding(.vertical, 4)

                Text("💡 也可直接敲击键盘方向键 ↑ ↓ ← → 即时微调")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        } label: {
            Label("虚拟方向摇杆", systemImage: "dpad.fill")
                .font(.subheadline.bold())
        }
    }

    private func nudgeButton(label: String, dir: NudgeDirection) -> some View {
        Button {
            guard !selectedUDID.isEmpty else { return }
            gps.nudge(direction: dir, stepMeters: joystickStepMeters, udid: selectedUDID)
            if let current = gps.currentCoord {
                latText = String(format: "%.5f", current.latitude)
                lonText = String(format: "%.5f", current.longitude)
                mapVM.targetCoordinate = current
            }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 54, height: 40)
        }
        .buttonStyle(.bordered)
        .disabled(selectedUDID.isEmpty)
    }

    // MARK: - Anti-Detection Section
    var antiDetectionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("拟真 GPS 自然漂移 (Anti-Detection)", isOn: $gps.isJitterEnabled)
                    .font(.subheadline.bold())

                if gps.isJitterEnabled {
                    HStack {
                        Text("微弱漂移幅度: ±\(String(format: "%.1f", gps.jitterMeters)) 米")
                            .font(.caption)
                            .frame(width: 140, alignment: .leading)
                        Slider(value: $gps.jitterMeters, in: 0.5...4.0, step: 0.2)
                    }
                    Text("模拟真实卫星硬件的多径效应与信号延迟，防止被反作弊或系统识别为固定假坐标。")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            Label("真实感与防检测", systemImage: "shield.lefthalf.filled")
                .font(.caption.bold())
        }
    }

    // MARK: - Stop / Restore Button
    var restoreRealGPSButton: some View {
        Button {
            guard !selectedUDID.isEmpty else { return }
            gps.clearSimulation(udid: selectedUDID)
        } label: {
            Label("停止模拟，恢复手机物理真实 GPS", systemImage: "location.slash.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .controlSize(.large)
        .disabled(selectedUDID.isEmpty)
    }

    // MARK: - Log Section
    var logSection: some View {
        GroupBox {
            VStack(spacing: 4) {
                HStack {
                    Spacer()
                    Button("清空") {
                        logger.clear()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(logger.entries.enumerated()), id: \.offset) { idx, entry in
                                Text(entry)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(
                                        entry.contains("🟢") ? Color.green :
                                        entry.contains("🔴") ? Color.red   :
                                        entry.contains("⭐") ? Color.yellow: Color.secondary
                                    )
                                    .id(idx)
                            }
                        }
                        .padding(6)
                    }
                    .frame(minHeight: 100, maxHeight: 140)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onChange(of: logger.entries.count) { _, count in
                        if count > 0 {
                            proxy.scrollTo(count - 1, anchor: .bottom)
                        }
                    }
                }
            }
        } label: {
            Label("运行日志", systemImage: "terminal")
                .font(.caption.bold())
        }
    }

    // MARK: - Right Panel (Map)
    var rightMapPanel: some View {
        ZStack(alignment: .top) {
            // Map View
            MapReader { proxy in
                Map(position: $mapVM.cameraPosition) {
                    // 当前设备真实/模拟位置
                    if let current = gps.currentCoord {
                        Annotation("设备当前位置", coordinate: current) {
                            ZStack {
                                Circle().fill(.green.opacity(0.3)).frame(width: 34, height: 34)
                                Circle().fill(.green).frame(width: 16, height: 16)
                                Circle().stroke(.white, lineWidth: 2).frame(width: 16, height: 16)
                            }
                        }
                    }

                    // 目标选点 Pin
                    Annotation("目标选点", coordinate: mapVM.targetCoordinate) {
                        VStack(spacing: 0) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundStyle(.red)
                                .shadow(radius: 2)
                        }
                    }

                    // 途经点标注 (带序号 1, 2, 3...)
                    ForEach(Array(mapVM.waypoints.enumerated()), id: \.element.id) { idx, wp in
                        Annotation(wp.name, coordinate: wp.coordinate) {
                            ZStack {
                                Circle().fill(.orange).frame(width: 24, height: 24)
                                Circle().stroke(.white, lineWidth: 2).frame(width: 24, height: 24)
                                Text("\(idx + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .shadow(radius: 2)
                        }
                    }

                    // 环形巡航轨迹预览圈
                    if selectedTab == .cruise {
                        MapCircle(center: mapVM.targetCoordinate, radius: loopRadiusMeters)
                            .foregroundStyle(.blue.opacity(0.12))
                            .stroke(.blue, lineWidth: 2)
                    }

                    // 真实道路导航折线
                    if !mapVM.routeCoordinates.isEmpty {
                        MapPolyline(coordinates: mapVM.routeCoordinates)
                            .stroke(.blue, lineWidth: 5)
                    }
                }
                .mapStyle(mapVM.selectedMapStyle.mapStyle)
                .onTapGesture { screenPoint in
                    if let coord = proxy.convert(screenPoint, from: .local) {
                        mapVM.targetCoordinate = coord
                        latText = String(format: "%.5f", coord.latitude)
                        lonText = String(format: "%.5f", coord.longitude)
                    }
                }
            }

            // 顶部悬浮工具条 (搜索 + 地图样式 + 定位按钮)
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    // 搜索输入框
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("搜索全球地名 / 景点 / 道路 (如 Apple Park, 尖沙咀)...", text: $mapVM.searchQuery)
                            .textFieldStyle(.plain)
                            .onChange(of: mapVM.searchQuery) { _, query in
                                mapVM.search(query: query)
                            }
                        if !mapVM.searchQuery.isEmpty {
                            Button {
                                mapVM.searchQuery = ""
                                mapVM.searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

                    // 地图样式切换
                    Picker("", selection: $mapVM.selectedMapStyle) {
                        ForEach(AppMapStyle.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 140)

                    // 归位到当前模拟点按钮
                    Button {
                        if let current = gps.currentCoord {
                            mapVM.moveTo(coordinate: current)
                        } else {
                            mapVM.moveTo(coordinate: mapVM.targetCoordinate)
                        }
                    } label: {
                        Image(systemName: "location")
                            .padding(6)
                    }
                    .buttonStyle(.bordered)
                    .help("视角移动到当前坐标")
                }
                .padding(10)

                // 搜索联想结果弹出层
                if !mapVM.searchResults.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(mapVM.searchResults.prefix(6)) { place in
                            Button {
                                mapVM.targetCoordinate = place.coordinate
                                latText = String(format: "%.5f", place.coordinate.latitude)
                                lonText = String(format: "%.5f", place.coordinate.longitude)
                                mapVM.moveTo(coordinate: place.coordinate)
                                mapVM.searchResults = []
                                mapVM.searchQuery = place.title
                            } label: {
                                HStack {
                                    Image(systemName: "mappin")
                                        .foregroundStyle(.red)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(place.title)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        if !place.subtitle.isEmpty {
                                            Text(place.subtitle)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(8)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                    .frame(maxWidth: 460)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 6)
                    .padding(.horizontal, 10)
                }

                Spacer()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .frame(width: 1100, height: 750)
}
