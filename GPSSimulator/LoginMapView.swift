import SwiftUI

// MARK: - Palette

extension Color {
    init(loginHex hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// 登录界面的色彩令牌，深色 / 浅色外观各一套取值（与设计稿「组件与状态」一致）
struct LoginPalette {
    let isDark: Bool

    init(_ scheme: ColorScheme) {
        isDark = scheme == .dark
    }

    private func pick(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(loginHex: isDark ? dark : light)
    }

    // 表单
    var window: Color           { pick(0xFFFFFF, 0x12151B) }
    var panelBorder: Color      { pick(0xDDE2E9, 0x1E2430) }
    var field: Color            { pick(0xF6F7F9, 0x1A1E26) }
    var fieldBorder: Color      { pick(0xD5D9E0, 0x2C323D) }
    var fieldBorderHover: Color { pick(0xB9C0CB, 0x3A4250) }
    var textPrimary: Color      { pick(0x111318, 0xF2F4F7) }
    var textSecondary: Color    { pick(0x5A6271, 0x9AA3B2) }
    var textLabel: Color        { pick(0x2B303A, 0xC9D0DB) }
    var textMuted: Color        { pick(0x646C7C, 0x7D8696) }
    var accentFill: Color       { pick(0x0071E3, 0x0868F0) }
    var accentFillHover: Color  { pick(0x0062CC, 0x0A5CD6) }
    var accentText: Color       { pick(0x0062CC, 0x5AA9FF) }
    var focus: Color            { pick(0x0071E3, 0x0A84FF) }
    var error: Color            { pick(0xC62828, 0xFF6B6B) }
    var errorBorder: Color      { pick(0xD93036, 0xE5484D) }
    var warning: Color          { pick(0x9A5B00, 0xF5B54A) }
    var success: Color          { pick(0x12834F, 0x3DD68C) }
    var successBg: Color        { pick(0xE5F6EC, 0x0F2A20) }
    var divider: Color          { pick(0xE3E7ED, 0x232833) }
    var segTrack: Color         { pick(0xF1F3F6, 0x171B22) }
    var segTrackBorder: Color   { pick(0xE3E7ED, 0x232933) }
    var segOn: Color            { pick(0xFFFFFF, 0x2A313D) }
    var ghostHover: Color       { pick(0xEEF1F5, 0x1F242E) }
    var card: Color             { pick(0xF8F9FB, 0x151920) }
    var cardDivider: Color      { pick(0xE9ECF1, 0x1F242E) }
    var badgeBg: Color          { pick(0xE8F1FC, 0x1F2836) }
    var badgeFg: Color          { pick(0x0062CC, 0x9AC8FF) }
    var shieldBg: Color         { pick(0xE8F1FC, 0x14233A) }

    // 地图
    var mapGround: Color        { pick(0xE9EEF4, 0x090E16) }
    var mapGrid: Color          { pick(0xCDD6E2, 0x152033) }
    var contour: Color          { pick(0xCFD9E6, 0x142038) }
    var contourDim: Color       { pick(0xD3DCE8, 0x121C31) }
    var contourIndex: Color     { pick(0xB6C4D6, 0x1C2B48) }
    var minorRoad: Color        { pick(0xF7F9FC, 0x0E1520) }
    var majorRoadCasing: Color  { pick(0xD3DBE6, 0x090E16) }
    var majorRoad: Color        { pick(0xFFFFFF, 0x141D2B) }
    var routeCorridor: Color    { pick(0xD6E6FA, 0x0D1B30) }
    var route: Color            { pick(0x0071E3, 0x0A84FF) }
    var marker: Color           { pick(0xFFFFFF, 0xF2F4F7) }
    var startStroke: Color      { pick(0x1D2533, 0xC9D3E3) }
    var hudBackground: Color    { pick(0xFFFFFF, 0x0E141F) }
    var hudBorder: Color        { pick(0xD5DDE8, 0x22304A) }
    var hudDivider: Color       { pick(0xE3E8EF, 0x1E2838) }
    var hudValue: Color         { pick(0x111318, 0xE6EAF0) }
    var leader: Color           { pick(0xAEBBCC, 0x2B3B57) }
    var mapMeta: Color          { pick(0x5A6271, 0x7D8BA3) }
    var mapBody: Color          { pick(0x4A5260, 0x9AA3B2) }
    var scaleBar: Color         { pick(0x8A96A8, 0x3A4A64) }
    var compassDim: Color       { pick(0xC3CDD9, 0x22304A) }
    var brandBadgeBg: Color     { pick(0xD6E6FA, 0x0F2747) }
    var brandBadgeFg: Color     { pick(0x0058B8, 0x7DB8FF) }
}

// MARK: - Map Geometry

/// 地图插画按 660×780 的设计坐标绘制，按面板尺寸等比铺满并居中裁切
struct LoginMapFit {
    static let design = CGSize(width: 660, height: 780)

    let scale: CGFloat
    let origin: CGPoint

    init(size: CGSize) {
        let s = max(size.width / Self.design.width, size.height / Self.design.height)
        scale = s
        origin = CGPoint(x: (size.width - Self.design.width * s) / 2,
                         y: (size.height - Self.design.height * s) / 2)
    }

    func point(_ p: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale)
    }
}

private enum LoginMapArt {
    static let cycle: TimeInterval = 9
    static let travelEnd = 0.78

    static let start = CGPoint(x: 160, y: 445)
    static let pin = CGPoint(x: 568.2, y: 130)

    /// 沿道路网的规划路线（转角圆角半径 14）
    static let route: Path = {
        var p = Path()
        p.move(to: start)
        p.addArc(tangent1End: CGPoint(x: 393.2, y: 438.5), tangent2End: CGPoint(x: 388.3, y: 243), radius: 14)
        p.addArc(tangent1End: CGPoint(x: 388.3, y: 243), tangent2End: CGPoint(x: 572.2, y: 235.3), radius: 14)
        p.addArc(tangent1End: CGPoint(x: 572.2, y: 235.3), tangent2End: pin, radius: 14)
        p.addLine(to: pin)
        return p
    }()

    static let contourBlob: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 2, y: -64))
        p.addCurve(to: CGPoint(x: 62, y: -22), control1: CGPoint(x: 30, y: -62), control2: CGPoint(x: 52, y: -48))
        p.addCurve(to: CGPoint(x: 34, y: 50), control1: CGPoint(x: 72, y: 4), control2: CGPoint(x: 58, y: 34))
        p.addCurve(to: CGPoint(x: -44, y: 46), control1: CGPoint(x: 12, y: 64), control2: CGPoint(x: -22, y: 62))
        p.addCurve(to: CGPoint(x: -58, y: -24), control1: CGPoint(x: -64, y: 32), control2: CGPoint(x: -70, y: 2))
        p.addCurve(to: CGPoint(x: 2, y: -64), control1: CGPoint(x: -46, y: -50), control2: CGPoint(x: -24, y: -66))
        p.closeSubpath()
        return p
    }()

    struct Ring {
        let rotation: Double
        let scale: CGFloat
        var isIndex = false
    }

    struct ContourGroup {
        let center: CGPoint
        let isDim: Bool
        let rings: [Ring]
    }

    static let contours: [ContourGroup] = [
        ContourGroup(center: CGPoint(x: 112, y: 238), isDim: false, rings: [
            Ring(rotation: 0, scale: 0.32), Ring(rotation: 8, scale: 0.6), Ring(rotation: 16, scale: 0.92),
            Ring(rotation: 24, scale: 1.28, isIndex: true), Ring(rotation: 32, scale: 1.68), Ring(rotation: 40, scale: 2.12),
            Ring(rotation: 48, scale: 2.6), Ring(rotation: 56, scale: 3.12, isIndex: true), Ring(rotation: 64, scale: 3.7),
        ]),
        ContourGroup(center: CGPoint(x: 600, y: 700), isDim: false, rings: [
            Ring(rotation: -10, scale: 0.4), Ring(rotation: -20, scale: 0.78), Ring(rotation: -30, scale: 1.2, isIndex: true),
            Ring(rotation: -40, scale: 1.66), Ring(rotation: -50, scale: 2.16), Ring(rotation: -60, scale: 2.7),
            Ring(rotation: -70, scale: 3.3, isIndex: true),
        ]),
        ContourGroup(center: CGPoint(x: 470, y: 340), isDim: true, rings: [
            Ring(rotation: 12, scale: 0.28), Ring(rotation: 24, scale: 0.55), Ring(rotation: 36, scale: 0.85),
        ]),
    ]

    static let minorRoads = lines([
        (-20, 150, 700, 128), (262, -20, 287, 800), (478, -20, 498, 800),
        (55, -20, 80, 800), (655, -20, 685, 800), (-20, 350, 700, 325),
    ])

    static let majorRoads = lines([
        (-20, 450, 700, 430), (-20, 260, 700, 230), (142.6, -20, 173.4, 800),
        (381.8, -20, 402.3, 800), (562.6, -20, 593.4, 800), (230, 800, 700, 480),
    ])

    static let graticule: Path = {
        var p = Path()
        for i in 1...7 {
            let x = CGFloat(i) * 82.5
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: 780))
            let y = CGFloat(i) * 97.5
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: 660, y: y))
        }
        return p
    }()

    private static func lines(_ segments: [(CGFloat, CGFloat, CGFloat, CGFloat)]) -> Path {
        var p = Path()
        for s in segments {
            p.move(to: CGPoint(x: s.0, y: s.1))
            p.addLine(to: CGPoint(x: s.2, y: s.3))
        }
        return p
    }

    private static func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    private static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    /// `time` 为 nil 时（减少动态效果）绘制静止的完整路线
    static func draw(in context: inout GraphicsContext, fit: LoginMapFit, palette p: LoginPalette, time: TimeInterval?) {
        context.translateBy(x: fit.origin.x, y: fit.origin.y)
        context.scaleBy(x: fit.scale, y: fit.scale)

        context.stroke(graticule, with: .color(p.mapGrid), style: StrokeStyle(lineWidth: 1, dash: [2, 6]))

        for group in contours {
            for ring in group.rings {
                let transform = CGAffineTransform(rotationAngle: ring.rotation * .pi / 180)
                    .scaledBy(x: ring.scale, y: ring.scale)
                    .concatenating(CGAffineTransform(translationX: group.center.x, y: group.center.y))
                let color = ring.isIndex ? p.contourIndex : (group.isDim ? p.contourDim : p.contour)
                context.stroke(contourBlob.applying(transform), with: .color(color), lineWidth: 1)
            }
        }

        let roundCap = StrokeStyle(lineWidth: 3, lineCap: .round)
        context.stroke(minorRoads, with: .color(p.minorRoad), style: roundCap)
        context.stroke(majorRoads, with: .color(p.majorRoadCasing), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        context.stroke(majorRoads, with: .color(p.majorRoad), style: StrokeStyle(lineWidth: 7, lineCap: .round))

        // 时间轴：0 → 78% 行进，78% → 86% 停留，86% → 96% 淡出
        var progress = 1.0
        var travelOpacity = 1.0
        if let time {
            let t = time.truncatingRemainder(dividingBy: cycle) / cycle
            progress = t < travelEnd ? easeInOut(t / travelEnd) : 1
            if t < 0.05 { travelOpacity = t / 0.05 }
            else if t < 0.86 { travelOpacity = 1 }
            else if t < 0.96 { travelOpacity = 1 - (t - 0.86) / 0.1 }
            else { travelOpacity = 0 }
        }

        let line = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        context.stroke(route, with: .color(p.routeCorridor), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
        context.stroke(route, with: .color(p.route.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [0.1, 9]))
        let traveled = route.trimmedPath(from: 0, to: CGFloat(max(progress, 0.0001)))
        context.stroke(traveled, with: .color(p.route.opacity(travelOpacity)), style: line)

        context.fill(circle(start, 6.5), with: .color(p.mapGround))
        context.stroke(circle(start, 5.25), with: .color(p.startStroke), lineWidth: 2.5)

        if let time {
            for offset in [0.0, 1.2] {
                let phase = (time + offset).truncatingRemainder(dividingBy: 2.4) / 2.4
                let eased = 1 - pow(1 - phase, 2)
                let radius = 28 * CGFloat(0.35 + 1.45 * eased)
                context.stroke(circle(pin, radius), with: .color(p.route.opacity(0.9 * (1 - eased))), lineWidth: 1.5)
            }
        }

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(p.isDark ? 0.5 : 0.25), radius: 4, x: 0, y: 2))
            layer.fill(circle(pin, 9), with: .color(p.marker))
            layer.fill(circle(pin, 6), with: .color(p.route))
        }

        if time != nil, travelOpacity > 0, let dot = traveled.currentPoint {
            context.opacity = travelOpacity
            context.fill(circle(dot, 14), with: .color(p.route.opacity(0.22)))
            context.fill(circle(dot, 8), with: .color(p.marker))
            context.stroke(circle(dot, 6.5), with: .color(p.route), lineWidth: 3)
        }
    }
}

// MARK: - Map Hero View

/// 登录窗口左侧：夜航图风格的地形图，模拟定位点沿真实道路行进
struct LoginMapView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let p = LoginPalette(colorScheme)
        GeometryReader { geo in
            let fit = LoginMapFit(size: geo.size)
            let pin = fit.point(LoginMapArt.pin)
            let pinRadius = 9 * fit.scale
            let cardWidth: CGFloat = 200
            let cardX = pin.x - pinRadius - 22 - cardWidth

            ZStack(alignment: .topLeading) {
                p.mapGround

                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { timeline in
                    Canvas { context, _ in
                        LoginMapArt.draw(in: &context, fit: fit, palette: p,
                                         time: reduceMotion ? nil : timeline.date.timeIntervalSinceReferenceDate)
                    }
                }

                if cardX > 16 {
                    Rectangle()
                        .fill(p.leader)
                        .frame(width: 22, height: 1)
                        .offset(x: cardX + cardWidth, y: pin.y)
                    hudCard(p)
                        .frame(width: cardWidth)
                        .offset(x: cardX, y: pin.y - 60)
                }

                brand(p)
                    .padding(.leading, 40)
                    .padding(.top, 52)

                compass(p)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 22)
                    .padding(.top, 16)

                headline(p)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 48)
                    .padding(.bottom, 52)

                scaleBar(p)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 28)
                    .padding(.bottom, 56)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
    }

    private func brand(_ p: LoginPalette) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(p.route)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("GPS 模拟器")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(p.textPrimary)
                    Text("PRO")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(0.4)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(p.brandBadgeBg, in: Capsule())
                        .foregroundStyle(p.brandBadgeFg)
                }
                Text("Location Anywhere")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(p.mapMeta)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func hudCard(_ p: LoginPalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("模拟位置")
                    .font(.system(size: 12))
                    .foregroundStyle(p.textSecondary)
                Spacer()
                HStack(spacing: 6) {
                    LiveDot(color: p.success, animated: !reduceMotion)
                    Text("注入中")
                        .font(.system(size: 11))
                        .foregroundStyle(p.success)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow {
                    Text("LAT").foregroundStyle(p.textMuted)
                    Text("31.230416° N").foregroundStyle(p.hudValue)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                GridRow {
                    Text("LON").foregroundStyle(p.textMuted)
                    Text("121.473701° E").foregroundStyle(p.hudValue)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .font(.system(size: 12, design: .monospaced))
            Rectangle().fill(p.hudDivider).frame(height: 1)
            HStack {
                Text("道路导航").foregroundStyle(p.textSecondary)
                Spacer()
                Text("36 km/h")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(p.hudValue)
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(p.hudBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(p.hudBorder, lineWidth: 1))
        .shadow(color: .black.opacity(p.isDark ? 0.45 : 0.12), radius: 16, y: 12)
        .accessibilityHidden(true)
    }

    private func headline(_ p: LoginPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("iOS 17 · 18 · 27 — CoreDevice")
                .font(.system(size: 11, design: .monospaced))
                .tracking(1.3)
                .foregroundStyle(p.mapMeta)
            Text("把定位，\n放在任何地方。")
                .font(.system(size: 36, weight: .semibold))
                .tracking(-0.7)
                .lineSpacing(4)
                .foregroundStyle(p.textPrimary)
            Text("硬件级位置注入，真实路网导航与逐向中文语音。无需越狱，USB 连接即可开始。")
                .font(.system(size: 14))
                .lineSpacing(5)
                .foregroundStyle(p.mapBody)
                .frame(maxWidth: 400, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 460, alignment: .leading)
    }

    private func compass(_ p: LoginPalette) -> some View {
        VStack(spacing: 3) {
            Text("N")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(p.mapMeta)
            ZStack {
                CompassNeedle(half: false).fill(p.compassDim)
                CompassNeedle(half: true).fill(p.mapMeta)
            }
            .frame(width: 14, height: 18)
        }
        .accessibilityHidden(true)
    }

    private func scaleBar(_ p: LoginPalette) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("200 m")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(p.mapMeta)
            ScaleBarShape()
                .stroke(p.scaleBar, lineWidth: 1)
                .frame(width: 64, height: 6)
        }
        .accessibilityHidden(true)
    }
}

private struct LiveDot: View {
    let color: Color
    let animated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animated)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .opacity(animated ? 0.675 + 0.325 * cos(phase * 2 * .pi) : 1)
        }
    }
}

private struct CompassNeedle: Shape {
    let half: Bool

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 14, sy = rect.height / 18
        var p = Path()
        p.move(to: CGPoint(x: 7 * sx, y: 1 * sy))
        if !half { p.addLine(to: CGPoint(x: 12 * sx, y: 17 * sy)) }
        p.addLine(to: CGPoint(x: 7 * sx, y: 13 * sy))
        p.addLine(to: CGPoint(x: 2 * sx, y: 17 * sy))
        p.closeSubpath()
        return p
    }
}

private struct ScaleBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 0.5, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + 0.5, y: rect.maxY - 0.5))
        p.addLine(to: CGPoint(x: rect.maxX - 0.5, y: rect.maxY - 0.5))
        p.addLine(to: CGPoint(x: rect.maxX - 0.5, y: rect.minY))
        return p
    }
}
