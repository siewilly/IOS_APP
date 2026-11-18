import Foundation
import Combine

public struct UserProfile: Codable, Identifiable {
    public let id: Int
    public let username: String
    public var display_name: String
    public var emilia_callname: String

    public init(id: Int, username: String, display_name: String, emilia_callname: String) {
        self.id = id
        self.username = username
        self.display_name = display_name
        self.emilia_callname = emilia_callname
    }
}

public struct AuthResultResponse: Codable {
    public let status: String
    public let token: String?
    public let user: UserProfile?
    public let message: String?
}

public final class AuthService: ObservableObject {
    public static let shared = AuthService()

    private enum Keys {
        static let token = "emilia_auth_token"
        static let user = "emilia_auth_user"
    }

    @Published public var currentUser: UserProfile? {
        didSet {
            if let user = currentUser, let data = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(data, forKey: Keys.user)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.user)
            }
        }
    }

    @Published public var token: String? {
        didSet {
            if let token = token {
                UserDefaults.standard.set(token, forKey: Keys.token)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.token)
            }
        }
    }

    public var isAuthenticated: Bool {
        return token != nil && currentUser != nil
    }

    public init() {
        self.token = UserDefaults.standard.string(forKey: Keys.token)
        if let data = UserDefaults.standard.data(forKey: Keys.user),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.currentUser = user
        } else {
            // Default primary companion user
            self.currentUser = UserProfile(id: 1, username: "siewilly", display_name: "有栖", emilia_callname: "有栖")
        }
        Task {
            await self.autoLogin()
        }
    }

    private func getBaseURL() -> String {
        return ServerConfigManager.shared.serverBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    public func autoLogin() async {
        let base = getBaseURL()
        // If we have token, check /api/auth/me
        if let token = self.token, !token.isEmpty {
            await fetchCurrentUser()
            if self.currentUser != nil { return }
        }

        // Try /api/auth/me (backend provides token and user 1 fallback automatically)
        if let url = URL(string: "\(base)/api/auth/me") {
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            if let (data, response) = try? await URLSession.shared.data(for: req),
               let http = response as? HTTPURLResponse, http.statusCode == 200 {
                if let decoded = try? JSONDecoder().decode(AuthResultResponse.self, from: data),
                   let user = decoded.user {
                    await MainActor.run {
                        if let tok = decoded.token { self.token = tok }
                        self.currentUser = user
                    }
                    return
                }
            }
        }

        // Attempt login with default companion credentials
        do {
            _ = try await login(username: "siewilly", password: "backey513")
        } catch {
            print("[AuthService] autoLogin error: \(error.localizedDescription)")
        }
    }

    public func login(username: String, password: String) async throws -> UserProfile {
        let base = getBaseURL()
        guard let url = URL(string: "\(base)/api/auth/login") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["username": username, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(AuthResultResponse.self, from: data)
        if httpResponse.statusCode == 200, let token = decoded.token, let user = decoded.user {
            await MainActor.run {
                self.token = token
                self.currentUser = user
            }
            return user
        } else {
            throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: decoded.message ?? "登入失敗"])
        }
    }

    public func register(username: String, password: String, displayName: String, callname: String) async throws -> UserProfile {
        let base = getBaseURL()
        guard let url = URL(string: "\(base)/api/auth/register") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "username": username,
            "password": password,
            "display_name": displayName,
            "emilia_callname": callname
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(AuthResultResponse.self, from: data)
        if httpResponse.statusCode == 200, let token = decoded.token, let user = decoded.user {
            await MainActor.run {
                self.token = token
                self.currentUser = user
            }
            return user
        } else {
            throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: decoded.message ?? "註冊失敗"])
        }
    }

    public func updateProfile(displayName: String, callname: String, newPassword: String?) async throws -> UserProfile {
        let base = getBaseURL()
        guard let url = URL(string: "\(base)/api/auth/profile") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = self.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = [
            "display_name": displayName,
            "emilia_callname": callname
        ]
        if let newPassword = newPassword, !newPassword.isEmpty {
            body["new_password"] = newPassword
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 401 {
            await autoLogin()
            if let token = self.token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
                if let retryHttp = retryResponse as? HTTPURLResponse, retryHttp.statusCode == 200 {
                    let decoded = try JSONDecoder().decode(AuthResultResponse.self, from: retryData)
                    if let user = decoded.user {
                        await MainActor.run { self.currentUser = user }
                        return user
                    }
                }
            }
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = (try? JSONDecoder().decode(AuthResultResponse.self, from: data))?.message ?? "伺服器回應異常 (\(httpResponse.statusCode))"
            throw NSError(domain: "Auth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        let decoded = try JSONDecoder().decode(AuthResultResponse.self, from: data)
        if let user = decoded.user {
            await MainActor.run {
                self.currentUser = user
            }
            return user
        }
        throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "更新失敗"])
    }

    public func logout() {
        self.token = nil
        self.currentUser = nil
    }

    public func fetchCurrentUser() async {
        let base = getBaseURL()
        guard let url = URL(string: "\(base)/api/auth/me") else { return }
        var request = URLRequest(url: url)
        if let token = self.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoded = try JSONDecoder().decode(AuthResultResponse.self, from: data)
                await MainActor.run {
                    if let user = decoded.user {
                        self.currentUser = user
                    }
                    if let token = decoded.token, !token.isEmpty {
                        self.token = token
                    }
                }
            }
        } catch {
            print("[AuthService] fetchCurrentUser error:", error)
        }
    }
}
