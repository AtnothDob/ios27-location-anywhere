import Foundation
import SwiftUI

// MARK: - Account Models

struct AuthAccount: Codable, Equatable {
    let displayName: String
    let identifier: String
    let viaLicense: Bool
}

struct TwoFactorChallenge: Equatable {
    let identifier: String
    /// 已脱敏的验证码接收地址，例如 n•••@example.com
    let maskedDestination: String
}

enum AuthError: LocalizedError, Equatable {
    case invalidCredentials
    case invalidCode
    case invalidLicense
    case passkeyUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "邮箱或密码不正确，请重试"
        case .invalidCode:        return "验证码不正确，请重新输入"
        case .invalidLicense:     return "激活码无效，请检查后重试"
        case .passkeyUnavailable: return "此版本暂不支持通行密钥登录"
        }
    }
}

// MARK: - Auth Service

/// 账户服务接口。接入真实后端时实现此协议，并在 `AuthSession(service:)` 中替换。
protocol AuthService {
    func signIn(identifier: String, password: String) async throws -> TwoFactorChallenge
    func verify(code: String, for challenge: TwoFactorChallenge) async throws -> AuthAccount
    func resendCode(for challenge: TwoFactorChallenge) async throws
    func activate(licenseKey: String) async throws -> AuthAccount
    func signInWithPasskey() async throws -> AuthAccount
}

/// 本地演示服务：项目目前没有账户后端，这里只模拟网络延迟与校验结果。
/// 任意账号密码均可通过；验证码 000000 视为错误，便于预览错误状态。
struct DemoAuthService: AuthService {
    func signIn(identifier: String, password: String) async throws -> TwoFactorChallenge {
        try await Task.sleep(nanoseconds: 1_100_000_000)
        return TwoFactorChallenge(identifier: identifier, maskedDestination: Self.mask(identifier))
    }

    func verify(code: String, for challenge: TwoFactorChallenge) async throws -> AuthAccount {
        try await Task.sleep(nanoseconds: 900_000_000)
        if code == "000000" { throw AuthError.invalidCode }
        let name = challenge.identifier.split(separator: "@").first.map(String.init) ?? challenge.identifier
        return AuthAccount(displayName: name, identifier: challenge.identifier, viaLicense: false)
    }

    func resendCode(for challenge: TwoFactorChallenge) async throws {
        try await Task.sleep(nanoseconds: 400_000_000)
    }

    func activate(licenseKey: String) async throws -> AuthAccount {
        try await Task.sleep(nanoseconds: 1_100_000_000)
        return AuthAccount(displayName: "Pro", identifier: licenseKey, viaLicense: true)
    }

    func signInWithPasskey() async throws -> AuthAccount {
        throw AuthError.passkeyUnavailable
    }

    static func mask(_ identifier: String) -> String {
        guard let at = identifier.firstIndex(of: "@"), at > identifier.startIndex else {
            return "你的注册邮箱"
        }
        return String(identifier[identifier.startIndex]) + "•••" + String(identifier[at...])
    }
}

// MARK: - Session

extension Notification.Name {
    /// 退出登录前发出，控制台借此停止正在进行的模拟任务
    static let authSessionWillSignOut = Notification.Name("AuthSessionWillSignOut")
}

@MainActor
final class AuthSession: ObservableObject {
    enum Step: Equatable {
        case signIn
        case verify(TwoFactorChallenge)
        case success(AuthAccount)
    }

    @Published private(set) var isSignedIn: Bool
    @Published private(set) var step: Step = .signIn
    @Published private(set) var isWorking = false
    @Published private(set) var lastIdentifier = ""
    @Published var rememberMe = true

    private(set) var account: AuthAccount?

    private let service: AuthService
    private let defaults: UserDefaults
    private static let accountKey = "auth.rememberedAccount"

    init(service: AuthService = DemoAuthService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.accountKey),
           let saved = try? JSONDecoder().decode(AuthAccount.self, from: data) {
            account = saved
            isSignedIn = true
        } else {
            isSignedIn = false
        }
    }

    func signIn(identifier: String, password: String) async throws {
        isWorking = true
        defer { isWorking = false }
        lastIdentifier = identifier
        let challenge = try await service.signIn(identifier: identifier, password: password)
        step = .verify(challenge)
    }

    func verify(code: String) async throws {
        guard case .verify(let challenge) = step else { return }
        isWorking = true
        defer { isWorking = false }
        let verified = try await service.verify(code: code, for: challenge)
        account = verified
        step = .success(verified)
    }

    func resendCode() async throws {
        guard case .verify(let challenge) = step else { return }
        try await service.resendCode(for: challenge)
    }

    func activate(licenseKey: String) async throws {
        isWorking = true
        defer { isWorking = false }
        let activated = try await service.activate(licenseKey: licenseKey)
        account = activated
        step = .success(activated)
    }

    func signInWithPasskey() async throws {
        isWorking = true
        defer { isWorking = false }
        let signedIn = try await service.signInWithPasskey()
        account = signedIn
        step = .success(signedIn)
    }

    func backToSignIn() {
        step = .signIn
    }

    /// 登录成功页点击「进入控制台」
    func enterConsole() {
        guard case .success(let current) = step else { return }
        if rememberMe, let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: Self.accountKey)
        } else {
            defaults.removeObject(forKey: Self.accountKey)
        }
        isSignedIn = true
    }

    func signOut() {
        NotificationCenter.default.post(name: .authSessionWillSignOut, object: self)
        defaults.removeObject(forKey: Self.accountKey)
        account = nil
        step = .signIn
        isSignedIn = false
    }
}
