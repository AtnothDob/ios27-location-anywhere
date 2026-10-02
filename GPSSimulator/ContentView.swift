import SwiftUI
import MapKit

// MARK: - Control Tabs

enum ControlTab: String, CaseIterable, Identifiable {
    case teleport = "📍 坐标瞬移"
    case route    = "🗺️ 真实导航"
    case roaming  = "🚶 智能漫游"
    case scenario = "🏃 原生拟真"
    case joystick = "🕹️ 摇杆走位"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .teleport: return "location.fill"
        case .route:    return "arrow.triangle.turn.up.right.diamond.fill"
        case .roaming:  return "figure.walk"
        case .scenario: return "figure.run"
        case .joystick: return "dpad.fill"
        }
    }

    var shortTitle: String {
        switch self {
        case .teleport: return "瞬移"
        case .route:    return "导航"
        case .roaming:  return "漫游"
        case .scenario: return "拟真"
        case .joystick: return "摇杆"
        }
    }
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

// MARK: - Modern Section Card Container
struct ModernSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    var badge: String? = nil
    var badgeColor: Color = .secondary
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 24, height: 24)
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(iconColor)
                }

                Text(title)
                    .font(.system(size: 13, weight: .bold))

                Spacer()

                if let b = badge {
                    Text(b)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(badgeColor.opacity(0.14), in: Capsule())
                        .foregroundStyle(badgeColor)
                }
            }

            content()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }
}

// MARK: - Reusable Traffic Light HUD Component
struct TrafficLightHUDView: View {
    let isRed: Bool
    let statusText: String
    let subtitleWaiting: String
    let subtitlePass: String
    let detailWaiting: String
    let detailPass: String

    var body: some View {
        let tint = isRed ? Color.red : Color.green
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Circle().fill(isRed ? Color.red : Color.red.opacity(0.2)).frame(width: 8, height: 8)
                Circle().fill(Color.yellow.opacity(0.2)).frame(width: 8, height: 8)
                Circle().fill(!isRed ? Color.green : Color.green.opacity(0.2)).frame(width: 8, height: 8)
            }
            .padding(4)
            .background(Color.black.opacity(0.6), in: Capsule())

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(statusText)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(tint)
                    Spacer()
                    Text(isRed ? subtitleWaiting : subtitlePass)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }
                Text(isRed ? detailWaiting : detailPass)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(tint.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var scanner = DeviceScanner()
    @StateObject private var gps     = GPSController()
    @StateObject private var logger  = GPSLogger.shared
    @StateObject private var mapVM   = MapViewModel()
    @StateObject private var roaming = RoamingEngine()

    // Device
    @AppStorage("lastSelectedUDID") private var selectedUDID: String = ""

    // Active Control Tab
    @State private var selectedTab: ControlTab = .teleport

    // Coordinates & Presets
    @State private var selectedPresetID: String = "kDefault_0"
    @State private var latText: String = "37.33490"
    @State private var lonText: String = "-122.00900"
    @State private var newBookmarkName: String = ""
    @State private var showingAddBookmark: Bool = false

    // Route Navigation Settings
    @State private var routeTransportMode: RouteTransportMode = .automobile
    @State private var routeSpeedKmh: Double = 45.0

    // Scenario Simulation States
    @State private var selectedScenario: Scenario = kScenarios[0]
    @State private var scenarioRunMode: ScenarioRunMode = .customOrigin
    @State private var scenarioStartCoord: CLLocationCoordinate2D? = nil
    @State private var scenarioStartTitle: String = "未设置 (默认使用当前定位)"
    @State private var scenarioUseCustomDest: Bool = false
    @State private var scenarioCustomDestCoord: CLLocationCoordinate2D? = nil
    @State private var scenarioCustomDestTitle: String = "未设置 (请在地图选点)"
    @State private var scenarioCustomSpeedKmh: Double = 8.0
    @State private var scenarioFollowCamera: Bool = true
    @State private var isScenarioPlanning: Bool = false

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
        .onReceive(NotificationCenter.default.publisher(for: .authSessionWillSignOut)) { _ in
            gps.stopAll()
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
                    case .teleport:
                        teleportSection
                    case .route:
                        routeSection
                    case .roaming:
                        roamingSection
                    case .joystick:
                        joystickSection
                    case .scenario:
                        scenarioSection
                    }

                    chinaCoordinateCorrectionSection
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
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.blue.gradient)
                    .frame(width: 32, height: 32)
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("iOS GPS 模拟器")
                        .font(.system(size: 14, weight: .bold))
                    Text("Pro")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.blue.opacity(0.18), in: Capsule())
                        .foregroundStyle(.blue)
                }
                Text("CoreDevice 硬件级位置注入引擎")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if gps.isRunning {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("\(gps.activeMode.rawValue)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                    Text(gps.currentCoordString)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)

                    if let c = gps.currentCoord {
                        if ChinaCoordinateCorrector.isInChina(c) && gps.chinaCorrectionMode != .directWGS84 {
                            Text("🇨🇳自动防漂移")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.2), in: Capsule())
                                .foregroundStyle(.green)
                        } else {
                            Text("🌐海外直通")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.2), in: Capsule())
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.12), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.green.opacity(0.25), lineWidth: 1)
                )
            } else {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 6, height: 6)
                    Text("待命中")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(Color.secondary.opacity(0.1), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.secondary.opacity(0.12)),
            alignment: .bottom
        )
    }

    // MARK: Device Section
    var deviceSection: some View {
        ModernSectionCard(
            title: "目标 iOS 设备",
            icon: "iphone.gen3",
            iconColor: .blue,
            badge: scanner.devices.isEmpty ? "未连接" : "\(scanner.devices.count) 台在线",
            badgeColor: scanner.devices.isEmpty ? .secondary : .green
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Picker("", selection: $selectedUDID) {
                        if scanner.devices.isEmpty {
                            Text("⚠️ 未发现物理设备 (请 USB 连接或配对)").tag("")
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
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("刷新")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack(spacing: 6) {
                    Text(scanner.dotChar)
                        .foregroundStyle(.green)
                        .font(.system(size: 12, design: .monospaced))
                    Text(scanner.statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("自动热插拔", isOn: $scanner.isAutoScanning)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11))
                }
            }
        }
    }

    // MARK: Tab Selector Section (Modern Segmented Pill Bar)
    var tabSelectorSection: some View {
        HStack(spacing: 4) {
            ForEach(ControlTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: selectedTab == tab ? .bold : .medium))
                        Text(tab.shortTitle)
                            .font(.system(size: 10.5, weight: selectedTab == tab ? .bold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        selectedTab == tab
                            ? AnyShapeStyle(Color.accentColor)
                            : AnyShapeStyle(Color.clear)
                    )
                    .foregroundStyle(selectedTab == tab ? Color.white : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    // Quick City List
    private var quickCities: [(name: String, lat: Double, lon: Double)] {
        [
            ("上海", 31.2304, 121.4737),
            ("深圳", 22.5431, 114.0579),
            ("广州", 23.1291, 113.2644),
            ("成都", 30.5728, 104.0668),
            ("武汉", 30.5928, 114.3055),
            ("硅谷", 37.3349, -122.0090),
            ("尔湾", 33.6846, -117.8265)
        ]
    }

    // MARK: - Tab 1: Teleport & Presets Section
    var teleportSection: some View {
        ModernSectionCard(
            title: "坐标瞬移与预设",
            icon: "location.north.circle.fill",
            iconColor: .blue
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // 热门城市快捷芯片
                VStack(alignment: .leading, spacing: 5) {
                    Text("热门城市一键直达:")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(quickCities, id: \.name) { city in
                                Button {
                                    latText = String(format: "%.5f", city.lat)
                                    lonText = String(format: "%.5f", city.lon)
                                    mapVM.targetCoordinate = CLLocationCoordinate2D(latitude: city.lat, longitude: city.lon)
                                    mapVM.moveTo(coordinate: mapVM.targetCoordinate)
                                    GPSLogger.shared.add("快速跳转至热门城市: \(city.name) (\(latText), \(lonText))")
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "mappin")
                                            .font(.system(size: 9))
                                        Text(city.name)
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Divider()

                // 地标预设选择
                HStack(spacing: 8) {
                    Text("地标收藏:")
                        .font(.system(size: 11))
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
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.yellow)
                    }
                    .buttonStyle(.plain)
                    .help("收藏当前坐标为新地标")
                }

                // 坐标输入面板
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        // 纬度框
                        HStack(spacing: 4) {
                            Text("LAT")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                            TextField("37.33490", text: $latText)
                                .font(.system(size: 11, design: .monospaced))
                                .textFieldStyle(.plain)
                                .frame(width: 78)
                                .onChange(of: latText) { _, newText in
                                    handleLatChange(newText)
                                }
                                .onSubmit {
                                    centerMapOnInputs()
                                }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.18), lineWidth: 1))

                        // 经度框
                        HStack(spacing: 4) {
                            Text("LON")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                            TextField("-122.00900", text: $lonText)
                                .font(.system(size: 11, design: .monospaced))
                                .textFieldStyle(.plain)
                                .frame(width: 82)
                                .onChange(of: lonText) { _, newText in
                                    handleLonChange(newText)
                                }
                                .onSubmit {
                                    centerMapOnInputs()
                                }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.18), lineWidth: 1))

                        Spacer(minLength: 0)

                        // 快捷工具按钮
                        HStack(spacing: 4) {
                            Button {
                                pasteCoordinates()
                            } label: {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("粘贴剪贴板坐标 (支持多种经纬度格式)")

                            Button {
                                centerMapOnInputs()
                            } label: {
                                Image(systemName: "scope")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("居中定位到输入坐标")

                            Button {
                                syncFromMapTarget()
                            } label: {
                                Image(systemName: "arrow.down.left.circle")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("从右侧地图选点提取坐标")
                        }
                    }

                    // 校验提示
                    if let lat = Double(latText.trimmingCharacters(in: .whitespaces)),
                       let lon = Double(lonText.trimmingCharacters(in: .whitespaces)),
                       (-90...90).contains(lat) && (-180...180).contains(lon) {
                        // 合法
                    } else {
                        Text("⚠️ 请输入有效经纬度（纬度 -90~90，经度 -180~180）或点击📋粘贴")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                }

                // 瞬移大按钮
                Button {
                    guard !selectedUDID.isEmpty,
                          let lat = Double(latText.trimmingCharacters(in: .whitespaces)),
                          let lon = Double(lonText.trimmingCharacters(in: .whitespaces)) else { return }
                    gps.teleport(lat: lat, lon: lon, udid: selectedUDID)
                    mapVM.moveTo(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                        let latVal = Double(latText.trimmingCharacters(in: .whitespaces)) ?? 0
                        let lonVal = Double(lonText.trimmingCharacters(in: .whitespaces)) ?? 0
                        let inChina = ChinaCoordinateCorrector.isInChina(lat: latVal, lon: lonVal)
                        let tag = inChina ? (gps.chinaCorrectionMode == .directWGS84 ? "原始WGS-84直通" : "🇨🇳 自动防漂移注入") : "🌐 国际WGS-84直通"
                        Text("立即瞬移至此坐标 (\(tag))")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(selectedUDID.isEmpty || Double(latText.trimmingCharacters(in: .whitespaces)) == nil || Double(lonText.trimmingCharacters(in: .whitespaces)) == nil)
            }
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

    private func pasteCoordinates() {
        if let str = NSPasteboard.general.string(forType: .string),
           let parsed = CoordinateParser.parse(text: str) {
            latText = String(format: "%.5f", parsed.lat)
            lonText = String(format: "%.5f", parsed.lon)
            mapVM.targetCoordinate = CLLocationCoordinate2D(latitude: parsed.lat, longitude: parsed.lon)
            mapVM.moveTo(coordinate: mapVM.targetCoordinate)
            GPSLogger.shared.add("已从剪贴板一键粘贴坐标: \(latText), \(lonText)")
        } else {
            GPSLogger.shared.add("⚠️ 剪贴板中未找到有效经纬度格式 (例如 33.6846, -117.8265)")
        }
    }

    private func centerMapOnInputs() {
        guard let lat = Double(latText.trimmingCharacters(in: .whitespaces)),
              let lon = Double(lonText.trimmingCharacters(in: .whitespaces)),
              (-90...90).contains(lat) && (-180...180).contains(lon) else {
            GPSLogger.shared.add("⚠️ 请输入有效的经纬度数值 (纬度 -90~90, 经度 -180~180)")
            return
        }
        mapVM.targetCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        mapVM.moveTo(coordinate: mapVM.targetCoordinate)
        GPSLogger.shared.add("地图视角已居中至: \(latText), \(lonText)")
    }

    private func handleLatChange(_ newText: String) {
        if let parsed = CoordinateParser.parse(text: newText) {
            latText = String(format: "%.5f", parsed.lat)
            lonText = String(format: "%.5f", parsed.lon)
            mapVM.targetCoordinate = CLLocationCoordinate2D(latitude: parsed.lat, longitude: parsed.lon)
            mapVM.moveTo(coordinate: mapVM.targetCoordinate)
            GPSLogger.shared.add("已自动识别粘贴经纬度对: \(latText), \(lonText)")
        } else if let lat = Double(newText.trimmingCharacters(in: .whitespaces)),
                  let lon = Double(lonText.trimmingCharacters(in: .whitespaces)),
                  (-90...90).contains(lat) && (-180...180).contains(lon) {
            mapVM.targetCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    private func handleLonChange(_ newText: String) {
        if let parsed = CoordinateParser.parse(text: newText) {
            latText = String(format: "%.5f", parsed.lat)
            lonText = String(format: "%.5f", parsed.lon)
            mapVM.targetCoordinate = CLLocationCoordinate2D(latitude: parsed.lat, longitude: parsed.lon)
            mapVM.moveTo(coordinate: mapVM.targetCoordinate)
            GPSLogger.shared.add("已自动识别粘贴经纬度对: \(latText), \(lonText)")
        } else if let lat = Double(latText.trimmingCharacters(in: .whitespaces)),
                  let lon = Double(newText.trimmingCharacters(in: .whitespaces)),
                  (-90...90).contains(lat) && (-180...180).contains(lon) {
            mapVM.targetCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }


    // MARK: - Tab 2: Route Navigation 2.0 Section
    var routeSection: some View {
        ModernSectionCard(
            title: "真实道路导航 2.0",
            icon: "arrow.triangle.turn.up.right.diamond.fill",
            iconColor: .teal,
            badge: "Apple MapKit",
            badgeColor: .teal
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("基于 Apple MapKit 真实道路网规划，毫秒级平滑注入")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)

                // 1. 起终点路线规划卡片
                VStack(spacing: 0) {
                    // 起点
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .padding(.leading, 4)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("起点")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(mapVM.startTitle)
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Button("当前位置") {
                                if let c = gps.currentCoord {
                                    mapVM.setStart(coordinate: c, title: "当前设备定位")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)

                            Button("选点") {
                                mapVM.setStart(coordinate: mapVM.targetCoordinate, title: "地图选点")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                    // 互换行 (连线中间)
                    HStack {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 2, height: 16)
                            .padding(.leading, 12)

                        Spacer()

                        Button {
                            mapVM.swapStartAndDestination()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                Text("互换起终点")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.vertical, 1)

                    // 终点
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .padding(.leading, 4)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("终点")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(mapVM.destinationTitle)
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)
                        }

                        Spacer()

                        Button("设为终点") {
                            mapVM.setDestination(coordinate: mapVM.targetCoordinate, title: "地图选点")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                )

                // 途经点管理
                HStack {
                    Text("途经点 (\(mapVM.waypoints.count) 个)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        mapVM.addWaypoint(coordinate: mapVM.targetCoordinate)
                        GPSLogger.shared.add("已添加途经点: \(String(format: "%.5f, %.5f", mapVM.targetCoordinate.latitude, mapVM.targetCoordinate.longitude))")
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus.circle")
                            Text("加地图选点")
                        }
                        .font(.system(size: 10.5))
                    }
                    .buttonStyle(.borderless)

                    if !mapVM.waypoints.isEmpty {
                        Button("清空") {
                            mapVM.clearWaypoints()
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.red)
                    }
                }

                if !mapVM.waypoints.isEmpty {
                    VStack(spacing: 3) {
                        ForEach(Array(mapVM.waypoints.enumerated()), id: \.element.id) { idx, wp in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 16, height: 16)
                                    .overlay(Text("\(idx + 1)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white))
                                Text(wp.name).font(.system(size: 11))
                                Text(String(format: "(%.4f, %.4f)", wp.coordinate.latitude, wp.coordinate.longitude))
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    mapVM.removeWaypoint(id: wp.id)
                                } label: {
                                    Image(systemName: "xmark.circle").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }

                Divider()

                // 出行方式与路线偏好
                VStack(alignment: .leading, spacing: 6) {
                    Picker("出行方式", selection: $routeTransportMode) {
                        ForEach(RouteTransportMode.allCases) { m in
                            Text(m.label).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        Toggle("🛣️ 避高速", isOn: $mapVM.avoidHighways).font(.system(size: 11))
                        Toggle("💰 避收费", isOn: $mapVM.avoidTolls).font(.system(size: 11))
                        Toggle("🔊 语音", isOn: $mapVM.voiceGuidanceEnabled).font(.system(size: 11))
                        Spacer()
                        Toggle("🎥 跟随小车", isOn: $mapVM.isTrackingCar).font(.system(size: 11))
                    }
                }

                // 规划路线按钮
                Button {
                    let start = mapVM.startCoordinate ?? gps.currentCoord ?? CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
                    let dest = mapVM.destinationCoordinate ?? mapVM.targetCoordinate
                    Task {
                        _ = await mapVM.calculateRoute(from: start, to: dest, transportType: routeTransportMode.mkType)
                    }
                } label: {
                    if mapVM.isCalculatingRoute {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Apple Maps 正在规划真实道路…")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            Text("规划真实路线 (Apple Maps)")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(mapVM.isCalculatingRoute)

                if let err = mapVM.routeError {
                    Text(err).font(.system(size: 11)).foregroundStyle(.red)
                }

                // 路线已生成：播放与巡航控制器
                if !mapVM.routeCoordinates.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        // 路线概览胶囊
                        HStack {
                            Label("\(String(format: "%.1f", mapVM.routeDistanceMeters / 1000.0)) km", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                            Spacer()
                            Label("\(Int(mapVM.routeExpectedTravelTime / 60)) 分钟", systemImage: "clock")
                            Spacer()
                            Label("\(mapVM.routeCoordinates.count) 节点", systemImage: "chart.dots.scatter")
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

                        // 进度条可拖拽 Scrubber
                        VStack(spacing: 3) {
                            HStack {
                                Text("导航进度: \(Int(gps.navigationProgress * 100))%")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                                if gps.activeMode == .route {
                                    Text("剩余 \(String(format: "%.1f", gps.navigationRemainingDistMeters / 1000.0)) km · 约 \(Int(gps.navigationRemainingTimeSec / 60)) 分钟")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Slider(value: Binding(
                                get: { gps.navigationProgress },
                                set: { newProg in
                                    gps.seekTo(progress: newProg)
                                }
                            ), in: 0...1)
                        }

                        // 实时动态调速与拟真时速浮动
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("设定时速: \(Int(gps.navigationSpeedKmh)) km/h")
                                    .font(.system(size: 11, weight: .bold))
                                Spacer()
                                if gps.activeMode == .route {
                                    if gps.isWaitingForTrafficLight {
                                        Text("🔴 停车等灯中")
                                            .font(.system(size: 10.5, weight: .bold))
                                            .foregroundStyle(.red)
                                    } else if gps.isSpeedDriftEnabled {
                                        Text("实时: \(String(format: "%.1f", gps.liveSimulatedSpeedKmh)) km/h (±\(Int(gps.speedDriftPercentage))%)")
                                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.teal)
                                    }
                                }
                            }
                            Slider(value: $gps.navigationSpeedKmh, in: 5...120, step: 5)
                        }

                        // 播放器控制按钮行
                        HStack(spacing: 8) {
                            if gps.activeMode != .route {
                                Button {
                                    guard !selectedUDID.isEmpty else { return }
                                    gps.startRouteNavigation(
                                        waypoints: mapVM.routeCoordinates,
                                        routeSteps: mapVM.routeSteps,
                                        initialSpeedKmh: gps.navigationSpeedKmh,
                                        voiceEnabled: mapVM.voiceGuidanceEnabled,
                                        udid: selectedUDID
                                    )
                                } label: {
                                    Label("启动导航", systemImage: "play.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            } else {
                                if gps.isNavigationPaused {
                                    Button {
                                        gps.resumeNavigation()
                                    } label: {
                                        Label("继续", systemImage: "play.fill")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                } else {
                                    Button {
                                        gps.pauseNavigation()
                                    } label: {
                                        Label("暂停", systemImage: "pause.fill")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.orange)
                                }

                                Button {
                                    gps.stopAll(keepCoord: true)
                                } label: {
                                    Label("停止", systemImage: "stop.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                        .controlSize(.regular)
                        .disabled(selectedUDID.isEmpty)

                        // 模拟路口红绿灯 HUD 横幅 (支持红灯等待与绿灯直行直接通过)
                        if gps.activeMode == .route && (gps.isWaitingForTrafficLight || (!gps.trafficLightStatusText.isEmpty && gps.trafficLightStatusText.contains("绿灯"))) {
                            TrafficLightHUDView(
                                isRed: gps.isWaitingForTrafficLight,
                                statusText: gps.trafficLightStatusText,
                                subtitleWaiting: "怠速微抖动防检测中",
                                subtitlePass: "绿灯直通 · 匀速行驶",
                                detailWaiting: "减速避让红灯，保持微弱自然物理漂移，绿灯后自动恢复导航",
                                detailPass: "路口信号灯为绿灯，直接平稳通过，无需停车等待"
                            )
                        }

                        // 实时导航转弯 HUD 横幅
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
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.green)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        }

                        // 逐向转弯指引列表
                        if !mapVM.routeSteps.isEmpty {
                            DisclosureGroup("查看详细道路指引 (\(mapVM.routeSteps.count) 步)") {
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 4) {
                                        ForEach(Array(mapVM.routeSteps.enumerated()), id: \.element.id) { idx, step in
                                            HStack(spacing: 6) {
                                                Image(systemName: step.iconName)
                                                    .font(.caption)
                                                    .foregroundStyle(idx == gps.currentStepIndex && gps.activeMode == .route ? .green : .blue)
                                                    .frame(width: 16)
                                                Text("\(idx + 1). \(step.instruction)")
                                                    .font(.system(size: 11))
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
                            .font(.system(size: 11))
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Tab 3: Daily Roaming Section
    var roamingSection: some View {
        ModernSectionCard(
            title: "智能生活漫游",
            icon: "figure.walk",
            iconColor: .purple,
            badge: "每日不重复",
            badgeColor: .purple
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("基于周边真实店铺、名胜、绿地编排一日生活轨迹，每日不重复")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)

                // 漫游基准中心点
                HStack {
                    Text("漫游寓所/起点:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.4f, %.4f", mapVM.targetCoordinate.latitude, mapVM.targetCoordinate.longitude))
                        .font(.system(size: 11, design: .monospaced))
                    Spacer()
                    Button("设为地图选点") {
                        syncFromMapTarget()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                }
                .padding(6)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))

                // 人设偏好选择
                VStack(alignment: .leading, spacing: 4) {
                    Text("漫游人设风格:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $roaming.persona) {
                        ForEach(RoamingPersona.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(roaming.persona.summary)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                }

                // 生成按钮组
                HStack(spacing: 8) {
                    Button {
                        Task {
                            let center = mapVM.targetCoordinate
                            _ = await roaming.generateDailyPlan(center: center, reRoll: false)
                        }
                    } label: {
                        if roaming.isGenerating {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("正在检索周边真实商铺…")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Label("生成今日生活轨迹", systemImage: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.regular)
                    .disabled(roaming.isGenerating)

                    if !roaming.stops.isEmpty {
                        Button {
                            Task {
                                let center = mapVM.targetCoordinate
                                _ = await roaming.generateDailyPlan(center: center, reRoll: true)
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .help("换一批 (随机抽取不同店铺与路线)")
                        .disabled(roaming.isGenerating)
                    }
                }

                Text(roaming.statusMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(roaming.statusMessage.contains("⚠️") ? .orange : .secondary)

                // 模式偏好 (快进演示 vs 真实挂机)
                Toggle(isOn: $roaming.isAccelerated) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(roaming.isAccelerated ? "⚡ 快进演示模式 (方便快速体验与测试)" : "⏱️ 1:1 真实挂机模式 (全天候生活伴随)")
                            .font(.system(size: 11, weight: .bold))
                        Text(roaming.isAccelerated ? "地点间高速行驶，每站停留 15 秒" : "全天按真实作息与时速行进并真实停留")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)

                // 今日日程展示与漫游控制器
                if !roaming.stops.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("今日日程 (\(roaming.stops.count) 个节点)")
                                .font(.system(size: 11, weight: .bold))
                            Spacer()
                            Text("每日不重样")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.green)
                        }

                        // 日程节点卡片流
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(roaming.stops) { stop in
                                    HStack(spacing: 8) {
                                        Image(systemName: stop.icon)
                                            .font(.caption)
                                            .frame(width: 18)
                                            .foregroundStyle(.purple)

                                        VStack(alignment: .leading, spacing: 1) {
                                            HStack {
                                                Text(stop.title)
                                                    .font(.system(size: 11, weight: .bold))
                                                Text(stop.categoryTag)
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(.secondary)
                                            }
                                            Text(stop.poiName)
                                                .font(.system(size: 10.5))
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 1) {
                                            Text(stop.plannedTimeStr)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                            if stop.stayMinutes > 0 {
                                                Text("留 \(stop.stayMinutes)m")
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundStyle(.orange)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                                }
                            }
                        }
                        .frame(maxHeight: 140)

                        // 漫游实时状态 HUD
                        if roaming.state != .idle {
                            HStack(spacing: 8) {
                                Image(systemName: "figure.walk.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.purple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("漫游状态:")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                    Text(roaming.state.description)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.purple)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        }

                        // 漫游控制按钮组
                        HStack(spacing: 8) {
                            if roaming.state == .idle || roaming.state == .completed {
                                Button {
                                    guard !selectedUDID.isEmpty else { return }
                                    roaming.startRoaming(udid: selectedUDID, gps: gps, mapVM: mapVM)
                                } label: {
                                    Label("启动漫游", systemImage: "play.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.purple)
                            } else {
                                if roaming.state == .paused {
                                    Button {
                                        roaming.resumeRoaming()
                                    } label: {
                                        Label("继续", systemImage: "play.fill")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                } else {
                                    Button {
                                        roaming.pauseRoaming()
                                    } label: {
                                        Label("暂停", systemImage: "pause.fill")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.orange)
                                }

                                Button {
                                    roaming.stopRoaming()
                                    gps.stopAll(keepCoord: true)
                                } label: {
                                    Label("停止", systemImage: "stop.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                        .controlSize(.regular)
                        .disabled(selectedUDID.isEmpty)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Scenario Running Subview
    @ViewBuilder
    private var scenarioRunningView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: gps.scenarioMode == .customOrigin ? "figure.run" : "applelogo")
                        .foregroundStyle(.green)
                        .font(.system(size: 16, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(gps.currentScenario?.label ?? "拟真巡航中")
                        .font(.system(size: 13, weight: .bold))
                    Text(gps.scenarioMode == .customOrigin ? "沿真实道路行进 · \(gps.scenarioDestinationName)" : "Apple 官方硅谷原版")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if gps.isScenarioCompleted {
                    Text("🏁 已到达")
                        .font(.system(size: 10.5, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                } else {
                    Text(gps.isScenarioPaused ? "⏸️ 已暂停" : "🟢 巡航中")
                        .font(.system(size: 10.5, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(gps.isScenarioPaused ? Color.orange.opacity(0.15) : Color.green.opacity(0.15), in: Capsule())
                        .foregroundStyle(gps.isScenarioPaused ? .orange : .green)
                }
            }

            if gps.scenarioMode == .customOrigin {
                Divider()

                HStack {
                    Text("已前行: \(String(format: "%.2f", gps.scenarioTotalDistanceMeters / 1000.0)) km")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text("路线全长: \(String(format: "%.2f", gps.scenarioPlannedDistanceMeters / 1000.0)) km")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: gps.scenarioProgress)
                    .tint(.green)

                HStack {
                    Label(gps.scenarioDestinationName.isEmpty ? "真实公路探索" : "目的地: \(gps.scenarioDestinationName)", systemImage: "flag.checkered")
                    Spacer()
                    Text("100% 真实路网匹配")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

                // 实时动态调速与拟真时速浮动
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("设定时速: \(Int(gps.scenarioSpeedKmh)) km/h")
                            .font(.system(size: 11, weight: .bold))
                        Spacer()
                        if gps.isWaitingForTrafficLight {
                            Text("🔴 停车等灯中")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(.red)
                        } else if gps.isSpeedDriftEnabled {
                            Text("实时: \(String(format: "%.1f", gps.liveSimulatedSpeedKmh)) km/h (±\(Int(gps.speedDriftPercentage))%)")
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                    }
                    Slider(value: $gps.scenarioSpeedKmh, in: 2...130, step: 1)
                }

                // 模拟路口红绿灯 HUD 横幅
                if gps.isWaitingForTrafficLight || (!gps.trafficLightStatusText.isEmpty && gps.trafficLightStatusText.contains("绿灯")) {
                    TrafficLightHUDView(
                        isRed: gps.isWaitingForTrafficLight,
                        statusText: gps.trafficLightStatusText,
                        subtitleWaiting: "怠速微抖动防检测中",
                        subtitlePass: "绿灯直通 · 匀速巡航",
                        detailWaiting: "减速避让红灯，保持微弱自然物理漂移，绿灯后自动恢复巡航",
                        detailPass: "路口信号灯为绿灯，平稳直行直接通过，持续顺畅巡航"
                    )
                }
            } else {
                Text("Apple 官方原生指令被系统硬编码在加州硅谷 (Cupertino/I-280)，切换为自选起点可在任意城市巡航。")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            // 控制按钮行
            HStack(spacing: 8) {
                if gps.scenarioMode == .customOrigin {
                    if gps.isScenarioCompleted {
                        Button {
                            gps.reverseScenarioRoute(udid: selectedUDID) { curCoord in
                                if scenarioFollowCamera {
                                    mapVM.moveTo(coordinate: curCoord, meters: 1500)
                                }
                            }
                        } label: {
                            Label("原路返回", systemImage: "arrow.uturn.backward")
                                .font(.system(size: 11, weight: .bold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    } else {
                        Button {
                            if gps.isScenarioPaused {
                                gps.resumeScenario()
                            } else {
                                gps.pauseScenario()
                            }
                        } label: {
                            Label(gps.isScenarioPaused ? "继续" : "暂停", systemImage: gps.isScenarioPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 11, weight: .bold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Button(role: .destructive) {
                    gps.stopScenario()
                } label: {
                    Label("停止拟真", systemImage: "stop.fill")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if gps.scenarioMode == .customOrigin {
                    Button {
                        if let cur = gps.currentCoord {
                            mapVM.moveTo(coordinate: cur, meters: 1200)
                        }
                    } label: {
                        Image(systemName: "location.north.fill")
                    }
                    .buttonStyle(.bordered)
                    .help("对齐视角至设备当前坐标")
                }
            }
        }
        .padding(10)
        .background(Color.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Tab 4: Native Scenario Section
    var scenarioSection: some View {
        ModernSectionCard(
            title: "Apple 官方拟真场景",
            icon: "figure.run",
            iconColor: .indigo,
            badge: "100% 真实路网",
            badgeColor: .indigo
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // 运行中状态卡片
                if gps.isScenarioRunning {
                    scenarioRunningView
                } else {
                    // 配置与启动卡片
                    Text("沿当地真实道路行进（绝无假直线、绝不穿墙），智能匹配周边路网")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)

                    // 模式选择 Segmented
                    Picker("模式", selection: $scenarioRunMode) {
                        ForEach(ScenarioRunMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    // 2x2 拟真形态卡片矩阵
                    VStack(alignment: .leading, spacing: 6) {
                        Text("选择拟真形态:")
                            .font(.system(size: 11, weight: .bold))

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(Array(kScenarios.prefix(4))) { s in
                                Button {
                                    selectedScenario = s
                                    scenarioCustomSpeedKmh = s.defaultSpeedKmh
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(s.command == "City Run" ? "🏃" :
                                                 s.command == "City Bicycle Ride" ? "🚴" :
                                                 s.command == "City Drive" ? "🚙" : "🏎️")
                                                .font(.system(size: 14))
                                            Text(s.command)
                                                .font(.system(size: 11, weight: .bold))
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        Text(s.subtitle)
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        HStack {
                                            Text("~ \(Int(s.defaultSpeedKmh)) km/h")
                                                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                                .foregroundStyle(selectedScenario.id == s.id ? Color.accentColor : Color.secondary)
                                            Spacer()
                                        }
                                    }
                                    .padding(7)
                                    .background(selectedScenario.id == s.id ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .stroke(selectedScenario.id == s.id ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if scenarioRunMode == .customOrigin {
                        // 自选出发点与终点卡片
                        VStack(alignment: .leading, spacing: 8) {
                            // 出发点
                            HStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                                Text("拟真出发点:")
                                    .font(.system(size: 11, weight: .bold))
                                Spacer()
                                Text(scenarioStartTitle)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            HStack(spacing: 6) {
                                Button {
                                    if let c = gps.currentCoord {
                                        scenarioStartCoord = c
                                        scenarioStartTitle = String(format: "当前定位 (%.4f, %.4f)", c.latitude, c.longitude)
                                        mapVM.moveTo(coordinate: c)
                                        GPSLogger.shared.add("拟真起点设为当前定位: \(scenarioStartTitle)")
                                    }
                                } label: {
                                    Label("当前定位", systemImage: "location.fill")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)

                                Button {
                                    scenarioStartCoord = mapVM.targetCoordinate
                                    scenarioStartTitle = String(format: "地图选点 (%.4f, %.4f)", mapVM.targetCoordinate.latitude, mapVM.targetCoordinate.longitude)
                                    mapVM.moveTo(coordinate: mapVM.targetCoordinate)
                                    GPSLogger.shared.add("拟真起点设为地图选点: \(scenarioStartTitle)")
                                } label: {
                                    Label("地图选点", systemImage: "scope")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)

                                Button {
                                    if let text = NSPasteboard.general.string(forType: .string),
                                       let parsed = CoordinateParser.parse(text: text) {
                                        let c = CLLocationCoordinate2D(latitude: parsed.lat, longitude: parsed.lon)
                                        scenarioStartCoord = c
                                        scenarioStartTitle = String(format: "剪贴板 (%.4f, %.4f)", c.latitude, c.longitude)
                                        mapVM.targetCoordinate = c
                                        mapVM.moveTo(coordinate: c)
                                        GPSLogger.shared.add("拟真起点粘贴自剪贴板: \(scenarioStartTitle)")
                                    } else {
                                        GPSLogger.shared.add("⚠️ 剪贴板中未包含有效经纬度格式")
                                    }
                                } label: {
                                    Label("粘贴坐标", systemImage: "doc.on.clipboard")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }

                            Divider()

                            // 目的地设置
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Text("巡航目的地:")
                                        .font(.system(size: 11, weight: .bold))
                                    Spacer()
                                }

                                Picker("", selection: $scenarioUseCustomDest) {
                                    Text("🎲 智能顺路 (自动匹配真实路网地标)").tag(false)
                                    Text("🎯 自选地图选点为终点").tag(true)
                                }
                                .pickerStyle(.radioGroup)
                                .labelsHidden()
                                .onChange(of: scenarioUseCustomDest) { _, isCustom in
                                    if isCustom && scenarioCustomDestCoord == nil {
                                        scenarioCustomDestCoord = mapVM.targetCoordinate
                                        scenarioCustomDestTitle = String(format: "地图选点 (%.4f, %.4f)", mapVM.targetCoordinate.latitude, mapVM.targetCoordinate.longitude)
                                    }
                                }

                                if scenarioUseCustomDest {
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack(spacing: 6) {
                                            Button {
                                                scenarioCustomDestCoord = mapVM.targetCoordinate
                                                scenarioCustomDestTitle = String(format: "地图选点 (%.4f, %.4f)", mapVM.targetCoordinate.latitude, mapVM.targetCoordinate.longitude)
                                                GPSLogger.shared.add("巡航终点设为地图选点: \(scenarioCustomDestTitle)")
                                            } label: {
                                                Label("设地图选点为终点", systemImage: "mappin.and.ellipse")
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)

                                            Button {
                                                if let text = NSPasteboard.general.string(forType: .string),
                                                   let parsed = CoordinateParser.parse(text: text) {
                                                    let c = CLLocationCoordinate2D(latitude: parsed.lat, longitude: parsed.lon)
                                                    scenarioCustomDestCoord = c
                                                    scenarioCustomDestTitle = String(format: "剪贴板 (%.4f, %.4f)", c.latitude, c.longitude)
                                                    mapVM.targetCoordinate = c
                                                    mapVM.moveTo(coordinate: c)
                                                    GPSLogger.shared.add("巡航终点粘贴自剪贴板: \(scenarioCustomDestTitle)")
                                                } else {
                                                    GPSLogger.shared.add("⚠️ 剪贴板中未包含有效经纬度格式")
                                                }
                                            } label: {
                                                Label("粘贴坐标", systemImage: "doc.on.clipboard")
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)
                                        }

                                        HStack(spacing: 4) {
                                            Text(scenarioCustomDestTitle)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)

                                            let sCoord = scenarioStartCoord ?? gps.currentCoord ?? mapVM.targetCoordinate
                                            if let dCoord = scenarioCustomDestCoord ?? (scenarioUseCustomDest ? mapVM.targetCoordinate : nil) {
                                                let sLoc = CLLocation(latitude: sCoord.latitude, longitude: sCoord.longitude)
                                                let dLoc = CLLocation(latitude: dCoord.latitude, longitude: dCoord.longitude)
                                                let dKm = sLoc.distance(from: dLoc) / 1000.0
                                                Text("· 直线约 \(String(format: "%.1f", dKm)) km")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundStyle(.blue)
                                            }
                                        }
                                    }
                                }
                            }

                            Divider()

                            // 时速设置与路线预览
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("预设巡航时速:")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(scenarioCustomSpeedKmh)) km/h")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                Slider(value: $scenarioCustomSpeedKmh, in: 2...130, step: 1)

                                HStack {
                                    Text("路网规划: 约 \(Int(selectedScenario.defaultDistanceMeters / 1000.0)) km")
                                    Spacer()
                                    Toggle("视角跟随", isOn: $scenarioFollowCamera)
                                        .toggleStyle(.checkbox)
                                }
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)

                                // 路线预先规划预览
                                Button {
                                    let start = scenarioStartCoord ?? gps.currentCoord ?? mapVM.targetCoordinate
                                    let dest = scenarioUseCustomDest ? (scenarioCustomDestCoord ?? mapVM.targetCoordinate) : nil
                                    isScenarioPlanning = true
                                    Task {
                                        let success = await gps.previewScenarioRoute(selectedScenario, startCoord: start, destinationCoord: dest)
                                        isScenarioPlanning = false
                                        if success, !gps.scenarioRouteCoords.isEmpty {
                                            let total = gps.scenarioPlannedDistanceMeters
                                            let midIdx = gps.scenarioRouteCoords.count / 2
                                            let midCoord = gps.scenarioRouteCoords[midIdx]
                                            mapVM.moveTo(coordinate: midCoord, meters: max(3500, total * 1.25))
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if isScenarioPlanning {
                                            ProgressView().controlSize(.mini)
                                        } else {
                                            Image(systemName: "map.fill")
                                        }
                                        Text("预先规划并预览真实路网")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    } else {
                        // Apple 官方原版说明
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "applelogo")
                                    .foregroundStyle(.secondary)
                                Text("Apple 官方原版提示")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text("Apple 官方内置场景（City Run, Freeway Drive 等）由苹果硬编码在加州硅谷 Apple Park 或 I-280 高速。若想在本地模拟，请切换到【自选起点】模式。")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    }

                    Button {
                        guard !selectedUDID.isEmpty else { return }
                        if scenarioRunMode == .customOrigin {
                            let start = scenarioStartCoord ?? gps.currentCoord ?? mapVM.targetCoordinate
                            let dest = scenarioUseCustomDest ? (scenarioCustomDestCoord ?? mapVM.targetCoordinate) : nil
                            gps.startCustomScenario(
                                selectedScenario,
                                startCoord: start,
                                destinationCoord: dest,
                                speedKmh: scenarioCustomSpeedKmh,
                                udid: selectedUDID
                            ) { curCoord in
                                if scenarioFollowCamera {
                                    mapVM.moveTo(coordinate: curCoord, meters: 1500)
                                }
                            }
                        } else {
                            gps.startOfficialScenario(selectedScenario, udid: selectedUDID)
                        }
                    } label: {
                        Label(scenarioRunMode == .customOrigin ? "开始沿真实道路拟真巡航" : "启动 Apple 官方加州场景", systemImage: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.regular)
                    .disabled(selectedUDID.isEmpty)
                }
            }
        }
    }

    // MARK: - Tab 5: Joystick Section (Controller D-Pad)
    var joystickSection: some View {
        ModernSectionCard(
            title: "虚拟方向摇杆",
            icon: "dpad.fill",
            iconColor: .cyan,
            badge: "方向键支持",
            badgeColor: .cyan
        ) {
            VStack(spacing: 10) {
                HStack {
                    Text("单次步长:")
                        .font(.system(size: 11))
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

                // 3x3 D-pad 控制盘
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
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 54, height: 38)
                        }
                        .buttonStyle(.bordered)
                        .help("对齐目标选点")

                        nudgeButton(label: "东 →", dir: .east)
                    }
                    HStack(spacing: 6) {
                        nudgeButton(label: "↙", dir: .southWest)
                        nudgeButton(label: "↓ 南", dir: .south)
                        nudgeButton(label: "↘", dir: .southEast)
                    }
                }
                .padding(.vertical, 4)

                HStack(spacing: 4) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 11))
                    Text("也可敲击键盘 ↑ ↓ ← → 即时微调走位")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
            }
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
                .font(.system(size: 11.5, weight: .bold))
                .frame(width: 54, height: 38)
        }
        .buttonStyle(.bordered)
        .disabled(selectedUDID.isEmpty)
    }

    // MARK: - China Coordinate Correction Section (Automated Anti-Drift)
    private var chinaCorrectionBadgeText: String {
        if gps.chinaCorrectionMode == .directWGS84 { return "🌐 原始直通" }
        if let coord = gps.currentCoord, ChinaCoordinateCorrector.isInChina(coord) {
            return "🇨🇳 自动防漂移生效中"
        }
        return "🌐 海外标准直通"
    }

    private var chinaCorrectionBadgeColor: Color {
        if gps.chinaCorrectionMode == .directWGS84 { return .secondary }
        if let coord = gps.currentCoord, ChinaCoordinateCorrector.isInChina(coord) {
            return .green
        }
        return .blue
    }

    private var chinaCorrectionStatusTitle: String {
        if gps.chinaCorrectionMode == .directWGS84 {
            return "已开启 WGS-84 原始坐标直通模式"
        }
        if let coord = gps.currentCoord, ChinaCoordinateCorrector.isInChina(coord) {
            return "已自动识别位于中国大陆 (全自动反偏纠偏)"
        }
        return "已自动识别处于境外/港澳台区域 (标准直通)"
    }

    private var chinaCorrectionStatusDesc: String {
        if gps.chinaCorrectionMode == .directWGS84 {
            return "不执行任何坐标变换，以原始 WGS-84 经纬度直接注入真机底层硬件。"
        }
        if let coord = gps.currentCoord, ChinaCoordinateCorrector.isInChina(coord) {
            return "高德/微信等国内地图默认带 300~500 米加偏。系统已全自动逆解为标准 WGS-84 注入真机，手机显示 0 漂移 0 偏位！"
        }
        return "境外/港澳台/日韩/东南亚/欧美等区域无需偏转，直接注入纯正 WGS-84 硬件坐标，0 偏移 0 误差！"
    }

    private var chinaCorrectionStatusIcon: String {
        if gps.chinaCorrectionMode == .directWGS84 { return "globe.americas" }
        if let coord = gps.currentCoord, ChinaCoordinateCorrector.isInChina(coord) {
            return "checkmark.shield.fill"
        }
        return "globe.americas.fill"
    }

    var chinaCoordinateCorrectionSection: some View {
        let isAuto = gps.chinaCorrectionMode == .auto
        let tintColor = chinaCorrectionBadgeColor

        return ModernSectionCard(
            title: "中国区坐标防漂移 (全自动)",
            icon: "globe.asia.australia.fill",
            iconColor: .orange,
            badge: chinaCorrectionBadgeText,
            badgeColor: tintColor
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // 1. 自动化运行状态横幅
                HStack(spacing: 10) {
                    Image(systemName: chinaCorrectionStatusIcon)
                        .font(.system(size: 18))
                        .foregroundStyle(tintColor)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(chinaCorrectionStatusTitle)
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(tintColor)
                            Spacer()
                            Text(isAuto ? "🤖 全自动托管" : "🛠️ 手动指定")
                                .font(.system(size: 9.5, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background((isAuto ? Color.green : Color.orange).opacity(0.15), in: Capsule())
                                .foregroundStyle(isAuto ? .green : .orange)
                        }
                        Text(chinaCorrectionStatusDesc)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                }
                .padding(8)
                .background(tintColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tintColor.opacity(0.2), lineWidth: 1)
                )

                // 2. 模式选择 (默认全自动推荐，亦可手动覆盖特殊需求)
                HStack(spacing: 8) {
                    Text("纠偏模式:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $gps.chinaCorrectionMode) {
                        ForEach(ChinaCorrectionMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                // 3. 实时经纬度双轨对照监控
                if !gps.displayGcj02CoordString.isEmpty || !gps.displayWgs84CoordString.isEmpty {
                    VStack(spacing: 5) {
                        HStack {
                            Label("火星坐标 (GCJ-02/高德/腾讯/微信/地图选点):", systemImage: "map.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(gps.displayGcj02CoordString.isEmpty ? "境外无加偏" : gps.displayGcj02CoordString)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.primary)
                        }

                        HStack {
                            Label("真机注入 (WGS-84 原始硬件坐标):", systemImage: "cpu")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.blue)
                            Spacer()
                            Text(gps.displayWgs84CoordString)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Anti-Detection & Realism Section
    var antiDetectionSection: some View {
        ModernSectionCard(
            title: "巡航拟真与防检测",
            icon: "shield.lefthalf.filled",
            iconColor: .mint,
            badge: (gps.isJitterEnabled || gps.isSpeedDriftEnabled || gps.isTrafficLightSimulationEnabled) ? "拟真全开" : "基础模式",
            badgeColor: (gps.isJitterEnabled || gps.isSpeedDriftEnabled || gps.isTrafficLightSimulationEnabled) ? .mint : .secondary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // 1. 拟真坐标微抖动
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("拟真 GPS 坐标自然漂移 (Anti-Detection Jitter)", isOn: $gps.isJitterEnabled)
                        .font(.system(size: 11.5, weight: .bold))

                    if gps.isJitterEnabled {
                        HStack {
                            Text("微弱漂移幅度: ±\(String(format: "%.1f", gps.jitterMeters)) 米")
                                .font(.system(size: 10.5))
                                .frame(width: 140, alignment: .leading)
                            Slider(value: $gps.jitterMeters, in: 0.5...4.0, step: 0.2)
                        }
                        Text("模拟真实卫星硬件的多径效应与大气延迟，防止被系统或应用识别为固定虚假坐标。")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // 2. 巡航时速自然浮动 (模拟油门与坡度动态)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("巡航时速自然浮动 (模拟油门动态与道路阻力)", isOn: $gps.isSpeedDriftEnabled)
                        .font(.system(size: 11.5, weight: .bold))

                    if gps.isSpeedDriftEnabled {
                        HStack {
                            Text("时速浮动区间: ±\(Int(gps.speedDriftPercentage))%")
                                .font(.system(size: 10.5))
                                .frame(width: 140, alignment: .leading)
                            Slider(value: $gps.speedDriftPercentage, in: 5...25, step: 1)
                        }
                        Text("避免机器恒定速度特征，以平滑缓动算法在基准速度周围微幅浮动，大幅提升拟真度。")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // 3. 路口模拟红绿灯随机等待
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("路口模拟红绿灯 (随机减速刹停等待)", isOn: $gps.isTrafficLightSimulationEnabled)
                        .font(.system(size: 11.5, weight: .bold))

                    if gps.isTrafficLightSimulationEnabled {
                        VStack(spacing: 6) {
                            HStack {
                                Text("遇到红灯概率: \(Int(gps.trafficLightProbabilityPercent))%")
                                    .font(.system(size: 10.5))
                                    .frame(width: 140, alignment: .leading)
                                Slider(value: $gps.trafficLightProbabilityPercent, in: 10...90, step: 5)
                            }

                            HStack {
                                Text("等待时长区间: \(gps.trafficLightMinWaitSec)s ~ \(gps.trafficLightMaxWaitSec)s")
                                    .font(.system(size: 10.5))
                                    .frame(width: 140, alignment: .leading)

                                Stepper("最短 \(gps.trafficLightMinWaitSec)s", value: $gps.trafficLightMinWaitSec, in: 5...30, step: 5)
                                    .font(.system(size: 10))
                                    .onChange(of: gps.trafficLightMinWaitSec) { _, newVal in
                                        if gps.trafficLightMaxWaitSec < newVal {
                                            gps.trafficLightMaxWaitSec = newVal + 10
                                        }
                                    }
                                Stepper("最长 \(gps.trafficLightMaxWaitSec)s", value: $gps.trafficLightMaxWaitSec, in: 10...90, step: 5)
                                    .font(.system(size: 10))
                                    .onChange(of: gps.trafficLightMaxWaitSec) { _, newVal in
                                        if gps.trafficLightMinWaitSec > newVal {
                                            gps.trafficLightMinWaitSec = max(5, newVal - 10)
                                        }
                                    }
                            }
                        }
                        Text("行进至路网交叉路口时平稳减速停车，等待期间启动怠速自然微抖动，绿灯放行后自动加速。")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Stop / Restore Button
    var restoreRealGPSButton: some View {
        Button {
            guard !selectedUDID.isEmpty else { return }
            gps.clearSimulation(udid: selectedUDID)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "location.slash.fill")
                Text("停止模拟，恢复物理真实 GPS")
                    .font(.system(size: 13, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .controlSize(.regular)
        .disabled(selectedUDID.isEmpty)
    }

    // MARK: - Log Section (Modern Terminal Aesthetic)
    var logSection: some View {
        ModernSectionCard(
            title: "运行控制台",
            icon: "terminal",
            iconColor: .gray
        ) {
            VStack(spacing: 4) {
                HStack {
                    // macOS 风格三色灯
                    HStack(spacing: 4) {
                        Circle().fill(Color.red.opacity(0.8)).frame(width: 8, height: 8)
                        Circle().fill(Color.yellow.opacity(0.8)).frame(width: 8, height: 8)
                        Circle().fill(Color.green.opacity(0.8)).frame(width: 8, height: 8)
                    }

                    Spacer()

                    Button {
                        logger.clear()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "trash")
                            Text("清空")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.bottom, 2)

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
                        .padding(8)
                    }
                    .frame(minHeight: 100, maxHeight: 130)
                    .background(Color.black.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onChange(of: logger.entries.count) { _, count in
                        if count > 0 {
                            proxy.scrollTo(count - 1, anchor: .bottom)
                        }
                    }
                }
            }
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

                    // 导航起点标注
                    if let start = mapVM.startCoordinate {
                        Annotation("起点: \(mapVM.startTitle)", coordinate: start) {
                            ZStack {
                                Circle().fill(.green).frame(width: 22, height: 22)
                                Circle().stroke(.white, lineWidth: 2).frame(width: 22, height: 22)
                                Image(systemName: "flag.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            }
                            .shadow(radius: 2)
                        }
                    }

                    // 导航终点标注
                    if let dest = mapVM.destinationCoordinate {
                        Annotation("终点: \(mapVM.destinationTitle)", coordinate: dest) {
                            ZStack {
                                Circle().fill(.red).frame(width: 22, height: 22)
                                Circle().stroke(.white, lineWidth: 2).frame(width: 22, height: 22)
                                Image(systemName: "flag.checkered").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            }
                            .shadow(radius: 2)
                        }
                    }

                    // 漫游站点标注
                    if selectedTab == .roaming {
                        ForEach(roaming.stops) { stop in
                            Annotation(stop.poiName, coordinate: stop.coordinate) {
                                VStack(spacing: 2) {
                                    ZStack {
                                        Circle().fill(.purple).frame(width: 26, height: 26)
                                        Circle().stroke(.white, lineWidth: 2).frame(width: 26, height: 26)
                                        Image(systemName: stop.icon).font(.system(size: 11)).foregroundStyle(.white)
                                    }
                                    Text(stop.title)
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                                .shadow(radius: 2)
                            }
                        }

                        // 漫游全天道路折线 (紫色)
                        if !roaming.fullRouteCoordinates.isEmpty {
                            MapPolyline(coordinates: roaming.fullRouteCoordinates)
                                .stroke(.purple, lineWidth: 4)
                        }
                    }

                    // 真实道路导航折线 (蓝色)
                    if selectedTab == .route && !mapVM.routeCoordinates.isEmpty {
                        MapPolyline(coordinates: mapVM.routeCoordinates)
                            .stroke(.blue, lineWidth: 5)
                    }

                    // 拟真路网回路折线 (橙色)
                    if !gps.scenarioRouteCoords.isEmpty {
                        MapPolyline(coordinates: gps.scenarioRouteCoords)
                            .stroke(.orange, lineWidth: 5)
                    }

                    // 拟真起点标注
                    if let sCoord = gps.scenarioStartCoord ?? (selectedTab == .scenario ? scenarioStartCoord : nil),
                       (selectedTab == .scenario || gps.activeMode == .scenario) {
                        Annotation("拟真起点", coordinate: sCoord) {
                            ZStack {
                                Circle().fill(.orange).frame(width: 24, height: 24)
                                Circle().stroke(.white, lineWidth: 2).frame(width: 24, height: 24)
                                Image(systemName: "flag.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            }
                            .shadow(radius: 2)
                        }
                    }

                    // 拟真终点标注
                    if let eCoord = gps.scenarioRouteCoords.last ?? (selectedTab == .scenario && scenarioUseCustomDest ? scenarioCustomDestCoord : nil),
                       (selectedTab == .scenario || gps.activeMode == .scenario) {
                        Annotation(gps.scenarioDestinationName.isEmpty ? "拟真终点" : gps.scenarioDestinationName, coordinate: eCoord) {
                            ZStack {
                                Circle().fill(.red).frame(width: 24, height: 24)
                                Circle().stroke(.white, lineWidth: 2).frame(width: 24, height: 24)
                                Image(systemName: "flag.checkered").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            }
                            .shadow(radius: 2)
                        }
                    }
                }
                .mapStyle(mapVM.selectedMapStyle.mapStyle)
                .onMapCameraChange(frequency: .continuous) { context in
                    mapVM.updateCameraContext(context)
                }
                .onTapGesture { screenPoint in
                    if let coord = proxy.convert(screenPoint, from: .local) {
                        mapVM.targetCoordinate = coord
                        latText = String(format: "%.5f", coord.latitude)
                        lonText = String(format: "%.5f", coord.longitude)
                        if selectedTab == .scenario && !gps.isScenarioRunning {
                            if scenarioUseCustomDest {
                                scenarioCustomDestCoord = coord
                                scenarioCustomDestTitle = String(format: "地图选点 (%.4f, %.4f)", coord.latitude, coord.longitude)
                            } else {
                                scenarioStartCoord = coord
                                scenarioStartTitle = String(format: "地图选点 (%.4f, %.4f)", coord.latitude, coord.longitude)
                            }
                        }
                    }
                }
            }

            // 顶部悬浮工具条 (搜索 + 地图样式 + 缩放 + 定位按钮)
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    // 搜索输入框 (Apple 风格胶囊)
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("搜索全球地名 / 景点 / 道路 / 坐标 (如 尔湾, Irvine, Apple Park)...", text: $mapVM.searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .onChange(of: mapVM.searchQuery) { _, query in
                                mapVM.search(query: query)
                            }
                            .onSubmit {
                                if let first = mapVM.searchResults.first {
                                    mapVM.targetCoordinate = first.coordinate
                                    latText = String(format: "%.5f", first.coordinate.latitude)
                                    lonText = String(format: "%.5f", first.coordinate.longitude)
                                    mapVM.moveTo(coordinate: first.coordinate)
                                    mapVM.searchResults = []
                                    mapVM.searchQuery = first.title
                                    GPSLogger.shared.add("已从搜索定位至: \(first.title) (\(latText), \(lonText))")
                                }
                            }

                        if !mapVM.searchQuery.isEmpty {
                            Button {
                                mapVM.searchQuery = ""
                                mapVM.searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 3)

                    // 地图样式切换
                    Picker("", selection: $mapVM.selectedMapStyle) {
                        ForEach(AppMapStyle.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 145)
                    .padding(3)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 3)

                    // 顶部快捷缩放与归位组合
                    HStack(spacing: 3) {
                        Button {
                            mapVM.zoomIn()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
                        .help("放大地图 (Cmd +)")
                        .keyboardShortcut("+", modifiers: .command)

                        Divider().frame(height: 14)

                        Button {
                            mapVM.zoomOut()
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
                        .help("缩小地图 (Cmd -)")
                        .keyboardShortcut("-", modifiers: .command)

                        Divider().frame(height: 14)

                        Button {
                            if let current = gps.currentCoord {
                                mapVM.moveTo(coordinate: current)
                            } else {
                                mapVM.moveTo(coordinate: mapVM.targetCoordinate)
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
                        .help("视角移动到当前坐标")
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 3)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                // 搜索联想结果弹出层 (支持全球与坐标直达)
                if !mapVM.searchResults.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(mapVM.searchResults.prefix(8)) { place in
                            Button {
                                mapVM.targetCoordinate = place.coordinate
                                latText = String(format: "%.5f", place.coordinate.latitude)
                                lonText = String(format: "%.5f", place.coordinate.longitude)
                                mapVM.moveTo(coordinate: place.coordinate)
                                mapVM.searchResults = []
                                mapVM.searchQuery = place.title
                                GPSLogger.shared.add("已从搜索定位至: \(place.title) (\(latText), \(lonText))")
                            } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill((place.sourceTag == "坐标" ? Color.blue : Color.red).opacity(0.15))
                                            .frame(width: 26, height: 26)
                                        Image(systemName: place.sourceTag == "坐标" ? "location.circle.fill" : "mappin.circle.fill")
                                            .foregroundStyle(place.sourceTag == "坐标" ? .blue : .red)
                                            .font(.system(size: 13))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(place.title)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.primary)
                                            if let tag = place.sourceTag {
                                                Text(tag)
                                                    .font(.system(size: 9, weight: .bold))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1.5)
                                                    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        if !place.subtitle.isEmpty {
                                            Text(place.subtitle)
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.horizontal, 8)
                        }
                    }
                    .frame(maxWidth: 520)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                    .padding(.horizontal, 14)
                }

                Spacer()
            }

            // 右下角悬浮地图控制器 (放大、缩小、复位视角)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 0) {
                        Button {
                            mapVM.zoomIn()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("放大地图 (Zoom In)")

                        Divider().frame(width: 22)

                        Button {
                            mapVM.zoomOut()
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 13, weight: .bold))
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("缩小地图 (Zoom Out)")

                        Divider().frame(width: 22)

                        Button {
                            if let current = gps.currentCoord {
                                mapVM.moveTo(coordinate: current)
                            } else {
                                mapVM.moveTo(coordinate: mapVM.targetCoordinate)
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("视角移动到当前坐标")
                    }
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 2)
                    .padding(.trailing, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

}

// MARK: - Preview

#Preview {
    ContentView()
        .frame(width: 1100, height: 750)
}
