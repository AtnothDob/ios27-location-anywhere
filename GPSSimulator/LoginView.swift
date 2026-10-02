import SwiftUI
import AppKit

// MARK: - Links

/// 登录界面的外部链接。账户相关链接需在接入真实账户服务后配置；为 nil 时对应入口不显示。
enum LoginLinks {
    static let help = URL(string: "https://github.com/AtnothDob/ios27-location-anywhere#readme")
    static let createAccount: URL? = nil
    static let forgotPassword: URL? = nil
    static let purchase: URL? = nil
    static let privacy: URL? = nil
    static let terms: URL? = nil
}

// MARK: - Validation

enum LoginValidation {
    static func identifierError(_ identifier: String) -> String? {
        if identifier.isEmpty { return "请输入邮箱或用户名" }
        if identifier.contains("@"),
           identifier.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) == nil {
            return "邮箱格式不正确"
        }
        return nil
    }

    static func passwordError(_ password: String) -> String? {
        if password.isEmpty { return "请输入密码" }
        if password.count < 6 { return "密码至少需要 6 位" }
        return nil
    }

    /// 只保留字母与数字，转大写，每 4 位插入一个连字符：XXXX-XXXX-XXXX-XXXX
    static func formatLicense(_ raw: String) -> String {
        let chars = raw.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(16)
        var out = ""
        for (i, c) in chars.enumerated() {
            if i > 0 && i % 4 == 0 { out.append("-") }
            out.append(c)
        }
        return out
    }

    static func licenseError(_ key: String) -> String? {
        let count = key.filter { $0 != "-" }.count
        if count == 0 { return "请输入激活码" }
        if count != 16 { return "激活码应为 16 位字母或数字" }
        return nil
    }
}

// MARK: - Login View

struct LoginView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let p = LoginPalette(colorScheme)
        HStack(spacing: 0) {
            LoginMapView()
                .frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity)
            LoginFormPanel()
                .frame(width: 520)
                .frame(maxHeight: .infinity)
                .background(p.window)
                .overlay(alignment: .leading) {
                    Rectangle().fill(p.panelBorder).frame(width: 1)
                }
        }
        .frame(minWidth: 960, minHeight: 680)
        .ignoresSafeArea()
        .background(LoginWindowChrome())
    }
}

private struct LoginFormPanel: View {
    @EnvironmentObject private var auth: AuthSession
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var stepID: String {
        switch auth.step {
        case .signIn: return "signIn"
        case .verify: return "verify"
        case .success: return "success"
        }
    }

    private var isSignInStep: Bool {
        if case .signIn = auth.step { return true }
        return false
    }

    var body: some View {
        let p = LoginPalette(colorScheme)
        ZStack {
            Group {
                switch auth.step {
                case .signIn:
                    SignInStep()
                case .verify(let challenge):
                    VerifyStep(challenge: challenge)
                case .success(let account):
                    SuccessStep(account: account)
                }
            }
            .frame(width: 360)
            .id(stepID)
            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 8)), removal: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 56)
        .animation(reduceMotion ? nil : Animation.easeOut(duration: 0.32), value: stepID)
        .overlay(alignment: .topTrailing) {
            if isSignInStep, let url = LoginLinks.createAccount {
                HStack(spacing: 2) {
                    Text("还没有账户？").foregroundStyle(p.textSecondary)
                    Link("创建账户", destination: url)
                        .foregroundStyle(p.accentText)
                        .fontWeight(.medium)
                        .frame(height: 44)
                        .padding(.horizontal, 8)
                }
                .font(.system(size: 13))
                .padding(.top, 10)
                .padding(.trailing, 20)
            }
        }
        .overlay(alignment: .bottom) {
            footer(p)
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func footer(_ p: LoginPalette) -> some View {
        HStack {
            Text("v\(version)")
                .font(.system(size: 12, design: .monospaced))
            Spacer()
            HStack(spacing: 16) {
                if let help = LoginLinks.help { Link("帮助", destination: help) }
                if let privacy = LoginLinks.privacy { Link("隐私政策", destination: privacy) }
                if let terms = LoginLinks.terms { Link("服务条款", destination: terms) }
            }
            .font(.system(size: 12))
        }
        .foregroundStyle(p.textMuted)
        .tint(p.textMuted)
        .frame(height: 44)
        .padding(.horizontal, 80)
        .padding(.bottom, 6)
    }
}

// MARK: - Step 1: Sign In

private struct SignInStep: View {
    enum Method: Hashable { case account, license }
    enum Field: Hashable { case identifier, password, license }

    @EnvironmentObject private var auth: AuthSession
    @Environment(\.colorScheme) private var colorScheme

    @State private var method: Method = .account
    @State private var identifier = ""
    @State private var password = ""
    @State private var license = ""
    @State private var showPassword = false
    @State private var identifierError: String?
    @State private var passwordError: String?
    @State private var licenseError: String?
    @State private var formError: String?
    @State private var capsLockOn = false
    @State private var capsMonitor: Any?
    @FocusState private var focus: Field?
    @Namespace private var segmentNamespace

    var body: some View {
        let p = LoginPalette(colorScheme)
        VStack(alignment: .leading, spacing: 24) {
            StepHeader(title: "欢迎回来", palette: p) {
                Text("登录以继续使用 GPS 模拟器 Pro。")
            }
            methodPicker(p)
            switch method {
            case .account: accountForm(p)
            case .license: licenseForm(p)
            }
        }
        .onAppear {
            if identifier.isEmpty { identifier = auth.lastIdentifier }
            capsLockOn = NSEvent.modifierFlags.contains(.capsLock)
            capsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                capsLockOn = event.modifierFlags.contains(.capsLock)
                return event
            }
        }
        .onDisappear {
            if let monitor = capsMonitor { NSEvent.removeMonitor(monitor) }
            capsMonitor = nil
        }
    }

    // MARK: Method Picker

    private func methodPicker(_ p: LoginPalette) -> some View {
        HStack(spacing: 4) {
            segment(.account, title: "账号密码", icon: "person", p)
            segment(.license, title: "激活码", icon: "key", p)
        }
        .padding(4)
        .frame(height: 44)
        .background(p.segTrack, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(p.segTrackBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func segment(_ value: Method, title: String, icon: String, _ p: LoginPalette) -> some View {
        let selected = method == value
        Button {
            guard !auth.isWorking else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { method = value }
            clearErrors()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13, weight: .medium))
                Text(title)
            }
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(selected ? p.textPrimary : p.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(p.segOn)
                        .shadow(color: .black.opacity(p.isDark ? 0.45 : 0.12), radius: 1, y: 1)
                        .matchedGeometryEffect(id: "segment", in: segmentNamespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Account Form

    private func accountForm(_ p: LoginPalette) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "邮箱或用户名", palette: p)
                    HStack(spacing: 10) {
                        FieldIcon(name: "person", palette: p)
                        TextField("", text: $identifier, prompt: Text("name@example.com").foregroundColor(p.textMuted))
                            .loginInput(p)
                            .focused($focus, equals: .identifier)
                            .textContentType(.username)
                            .accessibilityLabel("邮箱或用户名")
                            .onSubmit { focus = .password }
                    }
                    .modifier(LoginFieldChrome(isFocused: focus == .identifier, isError: identifierError != nil, palette: p))
                    if let identifierError {
                        FieldMessage(text: identifierError, color: p.error)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        FieldLabel(text: "密码", palette: p)
                        Spacer()
                        if let url = LoginLinks.forgotPassword {
                            Link("忘记密码？", destination: url)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(p.accentText)
                        }
                    }
                    HStack(spacing: 10) {
                        FieldIcon(name: "lock", palette: p)
                        Group {
                            if showPassword {
                                TextField("", text: $password, prompt: Text("至少 6 位").foregroundColor(p.textMuted))
                            } else {
                                SecureField("", text: $password, prompt: Text("至少 6 位").foregroundColor(p.textMuted))
                            }
                        }
                        .loginInput(p)
                        .focused($focus, equals: .password)
                        .textContentType(.password)
                        .accessibilityLabel("密码")
                        .onSubmit(submitAccount)

                        Button {
                            showPassword.toggle()
                            DispatchQueue.main.async { focus = .password }
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .font(.system(size: 14))
                                .frame(width: 40, height: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(LoginIconButtonStyle(palette: p))
                        .accessibilityLabel(showPassword ? "隐藏密码" : "显示密码")
                        .help(showPassword ? "隐藏密码" : "显示密码")
                    }
                    .modifier(LoginFieldChrome(isFocused: focus == .password, isError: passwordError != nil,
                                               palette: p, trailingPadding: 4))
                    if let passwordError {
                        FieldMessage(text: passwordError, color: p.error)
                    }
                    if capsLockOn && focus == .password {
                        FieldMessage(text: "大写锁定已开启", color: p.warning, icon: "capslock.fill")
                    }
                }

                Toggle("在此 Mac 上保持登录", isOn: $auth.rememberMe)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13.5))
                    .foregroundStyle(p.textLabel)

                if let formError {
                    FieldMessage(text: formError, color: p.error)
                }

                Button(action: submitAccount) {
                    ButtonContent(loading: auth.isWorking, loadingTitle: "正在登录…") {
                        HStack(spacing: 8) {
                            Text("登录")
                            Image(systemName: "arrow.right").font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
                .buttonStyle(LoginPrimaryButtonStyle(palette: p, isLoading: auth.isWorking))
                .padding(.top, 4)
            }

            HStack(spacing: 12) {
                Rectangle().fill(p.divider).frame(height: 1)
                Text("或").font(.system(size: 12)).foregroundStyle(p.textMuted)
                Rectangle().fill(p.divider).frame(height: 1)
            }
            .accessibilityHidden(true)

            Button(action: signInWithPasskey) {
                HStack(spacing: 10) {
                    Image(systemName: "touchid").font(.system(size: 17))
                    Text("使用通行密钥登录")
                }
            }
            .buttonStyle(LoginSecondaryButtonStyle(palette: p))
        }
    }

    // MARK: License Form

    private func licenseForm(_ p: LoginPalette) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "激活码", palette: p)
                HStack(spacing: 10) {
                    FieldIcon(name: "key", palette: p)
                    TextField("", text: $license, prompt: Text("XXXX-XXXX-XXXX-XXXX").foregroundColor(p.textMuted))
                        .loginInput(p, monospaced: true)
                        .tracking(0.9)
                        .focused($focus, equals: .license)
                        .accessibilityLabel("激活码")
                        .onSubmit(submitLicense)
                        .onChange(of: license) { _, newValue in
                            let formatted = LoginValidation.formatLicense(newValue)
                            if formatted != newValue { license = formatted }
                            licenseError = nil
                        }
                }
                .modifier(LoginFieldChrome(isFocused: focus == .license, isError: licenseError != nil, palette: p))
                if let licenseError {
                    FieldMessage(text: licenseError, color: p.error)
                } else {
                    Text("激活码在购买确认邮件中，共 16 位字母或数字。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(p.textSecondary)
                }
            }

            if let formError {
                FieldMessage(text: formError, color: p.error)
            }

            Button(action: submitLicense) {
                ButtonContent(loading: auth.isWorking, loadingTitle: "正在激活…") {
                    Text("激活 Pro")
                }
            }
            .buttonStyle(LoginPrimaryButtonStyle(palette: p, isLoading: auth.isWorking))

            if let url = LoginLinks.purchase {
                HStack(spacing: 0) {
                    Text("还没有激活码？").foregroundStyle(p.textSecondary)
                    Link("购买 Pro", destination: url).foregroundStyle(p.accentText).fontWeight(.medium)
                }
                .font(.system(size: 13.5))
            }
        }
    }

    // MARK: Actions

    private func clearErrors() {
        identifierError = nil
        passwordError = nil
        licenseError = nil
        formError = nil
    }

    private func submitAccount() {
        guard !auth.isWorking else { return }
        let id = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        clearErrors()
        identifierError = LoginValidation.identifierError(id)
        passwordError = LoginValidation.passwordError(password)
        if let message = identifierError ?? passwordError {
            focus = identifierError != nil ? .identifier : .password
            announce(message)
            return
        }
        Task { @MainActor in
            do {
                try await auth.signIn(identifier: id, password: password)
            } catch {
                formError = error.localizedDescription
            }
        }
    }

    private func submitLicense() {
        guard !auth.isWorking else { return }
        clearErrors()
        if let message = LoginValidation.licenseError(license) {
            licenseError = message
            focus = .license
            announce(message)
            return
        }
        let key = license
        Task { @MainActor in
            do {
                try await auth.activate(licenseKey: key)
            } catch {
                formError = error.localizedDescription
            }
        }
    }

    private func signInWithPasskey() {
        guard !auth.isWorking else { return }
        clearErrors()
        Task { @MainActor in
            do {
                try await auth.signInWithPasskey()
            } catch {
                formError = error.localizedDescription
            }
        }
    }
}

// MARK: - Step 2: Two-Factor Verification

private struct VerifyStep: View {
    let challenge: TwoFactorChallenge

    @EnvironmentObject private var auth: AuthSession
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var code = ""
    @State private var codeError: String?
    @State private var cooldown = 0
    @FocusState private var codeFocused: Bool

    private static let length = 6

    private var resendTitle: String {
        cooldown > 0 ? "重新发送（\(cooldown) 秒）" : "重新发送"
    }

    var body: some View {
        let p = LoginPalette(colorScheme)
        VStack(alignment: .leading, spacing: 24) {
            Button {
                auth.backToSignIn()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                    Text("返回")
                }
                .font(.system(size: 13.5))
                .padding(.leading, 8)
                .padding(.trailing, 14)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(LoginIconButtonStyle(palette: p))
            .disabled(auth.isWorking)
            .padding(.leading, -12)
            .padding(.vertical, -10)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(p.shieldBg)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 22))
                        .foregroundStyle(p.accentText)
                )
                .accessibilityHidden(true)

            StepHeader(title: "两步验证", palette: p) {
                Text("输入发送至 ")
                    + Text(challenge.maskedDestination).foregroundColor(p.textPrimary).fontWeight(.medium)
                    + Text(" 的 6 位验证码。")
            }

            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    TextField("", text: $code)
                        .textFieldStyle(.plain)
                        .focused($codeFocused)
                        .textContentType(.oneTimeCode)
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                        .accessibilityLabel("6 位验证码")
                        .onSubmit(submit)
                        .onChange(of: code) { _, newValue in
                            let digits = String(newValue.filter { $0.isASCII && $0.isNumber }.prefix(Self.length))
                            if digits != newValue {
                                code = digits
                                return
                            }
                            if !digits.isEmpty { codeError = nil }
                            if digits.count == Self.length { submit() }
                        }

                    HStack(spacing: 12) {
                        ForEach(0..<Self.length, id: \.self) { index in
                            codeBox(index, p)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { codeFocused = true }
                    .accessibilityHidden(true)
                }
                if let codeError {
                    FieldMessage(text: codeError, color: p.error)
                }
            }

            Button(action: submit) {
                ButtonContent(loading: auth.isWorking, loadingTitle: "正在验证…") {
                    Text("验证")
                }
            }
            .buttonStyle(LoginPrimaryButtonStyle(palette: p, isLoading: auth.isWorking))

            HStack(spacing: 0) {
                Text("没有收到验证码？").foregroundStyle(p.textSecondary)
                Button(resendTitle, action: resend)
                    .buttonStyle(LoginLinkButtonStyle(color: cooldown > 0 ? p.textMuted : p.accentText))
                    .disabled(cooldown > 0)
            }
            .font(.system(size: 13.5))
            .padding(.top, -10)
        }
        .onAppear {
            DispatchQueue.main.async { codeFocused = true }
        }
        .task(id: cooldown) {
            guard cooldown > 0 else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if !Task.isCancelled { cooldown -= 1 }
        }
    }

    @ViewBuilder
    private func codeBox(_ index: Int, _ p: LoginPalette) -> some View {
        let chars = Array(code)
        let character = index < chars.count ? String(chars[index]) : ""
        let active = codeFocused && !auth.isWorking && index == min(chars.count, Self.length - 1)
        let hasError = codeError != nil
        let border: Color = hasError ? p.errorBorder : (active ? p.focus : (character.isEmpty ? p.fieldBorder : p.fieldBorderHover))

        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(p.field)
            RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(border, lineWidth: 1)
            if !character.isEmpty {
                Text(character)
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundStyle(p.textPrimary)
            } else if active {
                BlinkingCaret(color: p.accentText, animated: !reduceMotion)
            }
        }
        .frame(width: 50, height: 58)
        .background(
            RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                .stroke((hasError ? p.errorBorder : p.focus).opacity(0.28), lineWidth: 3)
                .padding(-1.5)
                .opacity(active ? 1 : 0)
        )
        .animation(.easeOut(duration: 0.15), value: active)
    }

    private func submit() {
        guard !auth.isWorking else { return }
        guard code.count == Self.length else {
            codeError = "请输入完整的 6 位验证码"
            codeFocused = true
            return
        }
        let value = code
        Task { @MainActor in
            do {
                try await auth.verify(code: value)
            } catch {
                code = ""
                codeError = error.localizedDescription
                codeFocused = true
                announce(error.localizedDescription)
            }
        }
    }

    private func resend() {
        guard cooldown == 0 else { return }
        code = ""
        codeError = nil
        cooldown = 30
        codeFocused = true
        Task { @MainActor in
            try? await auth.resendCode()
        }
    }
}

// MARK: - Step 3: Success

private struct SuccessStep: View {
    let account: AuthAccount

    @EnvironmentObject private var auth: AuthSession
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var checkProgress: CGFloat = 0

    private let steps: [(title: String, detail: String)] = [
        ("开启开发者模式", "设置 › 隐私与安全性 › 开发者模式"),
        ("连接并信任此电脑", "用 USB 连接，在设备上点按「信任」并输入密码"),
        ("选择你的设备", "在控制台顶部的设备列表中选择 iPhone 或 iPad"),
    ]

    private var message: String {
        if account.viaLicense {
            return "许可证已绑定到这台 Mac。下一步，连接你的 iPhone 或 iPad。"
        }
        let greeting = account.displayName.isEmpty ? "欢迎回来。" : "\(account.displayName)，欢迎回来。"
        return greeting + "下一步，连接你的 iPhone 或 iPad。"
    }

    var body: some View {
        let p = LoginPalette(colorScheme)
        VStack(alignment: .leading, spacing: 24) {
            Circle()
                .fill(p.successBg)
                .frame(width: 56, height: 56)
                .overlay(
                    CheckmarkShape()
                        .trim(from: 0, to: checkProgress)
                        .stroke(p.success, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                        .frame(width: 28, height: 28)
                )
                .accessibilityHidden(true)

            StepHeader(title: account.viaLicense ? "Pro 已激活" : "已登录", palette: p) {
                Text(message)
            }

            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 14) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(p.badgeFg)
                            .frame(width: 24, height: 24)
                            .background(p.badgeBg, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(p.textPrimary)
                            Text(item.detail)
                                .font(.system(size: 12.5))
                                .foregroundStyle(p.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .accessibilityElement(children: .combine)
                    if index < steps.count - 1 {
                        Rectangle().fill(p.cardDivider).frame(height: 1)
                    }
                }
            }
            .background(p.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(p.segTrackBorder, lineWidth: 1))

            VStack(spacing: 4) {
                Button {
                    auth.enterConsole()
                } label: {
                    HStack(spacing: 8) {
                        Text("进入控制台")
                        Image(systemName: "arrow.right").font(.system(size: 14, weight: .semibold))
                    }
                }
                .buttonStyle(LoginPrimaryButtonStyle(palette: p))
                .keyboardShortcut(.defaultAction)

                Button("退出登录") { auth.signOut() }
                    .buttonStyle(LoginLinkButtonStyle(color: p.textSecondary))
                    .font(.system(size: 13.5))
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : Animation.easeOut(duration: 0.5).delay(0.15)) {
                checkProgress = 1
            }
        }
    }
}

// MARK: - Building Blocks

/// 让 VoiceOver 播报校验结果
private func announce(_ message: String) {
    NSAccessibility.post(element: NSApp as Any,
                         notification: .announcementRequested,
                         userInfo: [.announcement: message,
                                    .priority: NSAccessibilityPriorityLevel.high.rawValue])
}

private struct StepHeader<Subtitle: View>: View {
    let title: String
    let palette: LoginPalette
    @ViewBuilder let subtitle: () -> Subtitle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            subtitle()
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FieldLabel: View {
    let text: String
    let palette: LoginPalette

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(palette.textLabel)
            .accessibilityHidden(true)
    }
}

private struct FieldIcon: View {
    let name: String
    let palette: LoginPalette

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 14))
            .foregroundStyle(palette.textMuted)
            .frame(width: 18)
            .accessibilityHidden(true)
    }
}

private struct FieldMessage: View {
    let text: String
    let color: Color
    var icon = "exclamationmark.circle"

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            Text(text)
        }
        .font(.system(size: 12.5))
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    func loginInput(_ p: LoginPalette, monospaced: Bool = false) -> some View {
        self
            .textFieldStyle(.plain)
            .font(.system(size: 15, design: monospaced ? .monospaced : .default))
            .foregroundStyle(p.textPrimary)
            .autocorrectionDisabled()
            .focusEffectDisabled()
    }
}

/// 输入框外观：48pt 高、圆角 10、聚焦时 3pt 焦点环，错误时红色描边
private struct LoginFieldChrome: ViewModifier {
    let isFocused: Bool
    let isError: Bool
    let palette: LoginPalette
    var trailingPadding: CGFloat = 14

    @State private var hovering = false

    func body(content: Content) -> some View {
        let border: Color = isError ? palette.errorBorder
            : (isFocused ? palette.focus : (hovering ? palette.fieldBorderHover : palette.fieldBorder))
        let ring: Color = isError ? palette.errorBorder : palette.focus

        content
            .padding(.leading, 14)
            .padding(.trailing, trailingPadding)
            .frame(height: 48)
            .background(palette.field, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(border, lineWidth: 1))
            .background(
                RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                    .stroke(ring.opacity(0.28), lineWidth: 3)
                    .padding(-1.5)
                    .opacity(isFocused ? 1 : 0)
            )
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: isFocused)
            .animation(.easeOut(duration: 0.15), value: isError)
    }
}

private struct ButtonContent<Content: View>: View {
    let loading: Bool
    let loadingTitle: String
    @ViewBuilder let label: () -> Content

    var body: some View {
        if loading {
            HStack(spacing: 10) {
                LoginSpinner()
                Text(loadingTitle)
            }
        } else {
            label()
        }
    }
}

private struct LoginPrimaryButtonStyle: ButtonStyle {
    let palette: LoginPalette
    var isLoading = false

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, palette: palette, isLoading: isLoading)
    }

    private struct StyledBody: View {
        let configuration: ButtonStyleConfiguration
        let palette: LoginPalette
        let isLoading: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(hovering && !isLoading ? palette.accentFillHover : palette.accentFill)
                )
                .contentShape(Rectangle())
                .scaleEffect(configuration.isPressed && !isLoading ? 0.985 : 1)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.15), value: hovering)
                .allowsHitTesting(!isLoading)
        }
    }
}

private struct LoginSecondaryButtonStyle: ButtonStyle {
    let palette: LoginPalette

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, palette: palette)
    }

    private struct StyledBody: View {
        let configuration: ButtonStyleConfiguration
        let palette: LoginPalette
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(hovering || configuration.isPressed ? palette.field : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(hovering ? palette.fieldBorderHover : palette.fieldBorder, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.15), value: hovering)
        }
    }
}

private struct LoginIconButtonStyle: ButtonStyle {
    let palette: LoginPalette

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, palette: palette)
    }

    private struct StyledBody: View {
        let configuration: ButtonStyleConfiguration
        let palette: LoginPalette
        @State private var hovering = false

        var body: some View {
            configuration.label
                .foregroundStyle(hovering ? palette.textPrimary : palette.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(hovering || configuration.isPressed ? palette.ghostHover : Color.clear)
                )
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.15), value: hovering)
        }
    }
}

private struct LoginLinkButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, color: color)
    }

    private struct StyledBody: View {
        let configuration: ButtonStyleConfiguration
        let color: Color
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .fontWeight(.medium)
                .foregroundStyle(color)
                .underline(hovering && isEnabled)
                .padding(.horizontal, 4)
                .frame(height: 44)
                .contentShape(Rectangle())
                .opacity(configuration.isPressed ? 0.7 : 1)
                .onHover { hovering = $0 }
        }
    }
}

private struct LoginSpinner: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let angle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.7) / 0.7 * 360
            ZStack {
                Circle().stroke(Color.white.opacity(0.35), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(angle))
            }
            .frame(width: 16, height: 16)
        }
        .accessibilityHidden(true)
    }
}

private struct BlinkingCaret: View {
    let color: Color
    let animated: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let visible = !animated || Int(timeline.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 2, height: 24)
                .opacity(visible ? 1 : 0)
        }
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 24, sy = rect.height / 24
        var p = Path()
        p.move(to: CGPoint(x: 5 * sx, y: 12.5 * sy))
        p.addLine(to: CGPoint(x: 9.5 * sx, y: 17 * sy))
        p.addLine(to: CGPoint(x: 19 * sx, y: 7.5 * sy))
        return p
    }
}

// MARK: - Window Chrome

/// 登录界面显示期间隐藏标题栏、让内容延伸到窗口顶部；离开登录界面时恢复原样
private struct LoginWindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> ChromeView { ChromeView() }
    func updateNSView(_ nsView: ChromeView, context: Context) {}
    static func dismantleNSView(_ nsView: ChromeView, coordinator: ()) { nsView.restore() }

    final class ChromeView: NSView {
        private struct Saved {
            let transparent: Bool
            let visibility: NSWindow.TitleVisibility
            let fullSize: Bool
            let movable: Bool
        }

        private weak var configuredWindow: NSWindow?
        private var saved: Saved?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window = self.window, window !== configuredWindow else { return }
            restore()
            saved = Saved(transparent: window.titlebarAppearsTransparent,
                          visibility: window.titleVisibility,
                          fullSize: window.styleMask.contains(.fullSizeContentView),
                          movable: window.isMovableByWindowBackground)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            configuredWindow = window
        }

        func restore() {
            guard let window = configuredWindow, let saved else { return }
            window.titlebarAppearsTransparent = saved.transparent
            window.titleVisibility = saved.visibility
            if !saved.fullSize { window.styleMask.remove(.fullSizeContentView) }
            window.isMovableByWindowBackground = saved.movable
            configuredWindow = nil
            self.saved = nil
        }
    }
}
