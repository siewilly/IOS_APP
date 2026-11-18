import SwiftUI

public enum AuthViewMode {
    case login
    case register
    case profile
}

public struct AuthSheetView: View {
    @ObservedObject public var authService = AuthService.shared
    @State public var mode: AuthViewMode
    public var onAuthCompleted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    // Form states
    @State private var username = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var callname = ""
    @State private var newPassword = ""

    // UI states
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    public init(mode: AuthViewMode = .login, onAuthCompleted: (() -> Void)? = nil) {
        _mode = State(initialValue: mode)
        self.onAuthCompleted = onAuthCompleted
    }

    public var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.08, blue: 0.20),
                        Color(red: 0.16, green: 0.12, blue: 0.30),
                        Color(red: 0.08, green: 0.06, blue: 0.15)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection

                        if let err = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(err)
                                    .font(.footnote)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.25))
                            .cornerRadius(10)
                        }

                        if let succ = successMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(succ)
                                    .font(.footnote)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.25))
                            .cornerRadius(10)
                        }

                        formCard

                        switchModeButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .onAppear {
                initFields()
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: mode == .profile ? "person.crop.circle.badge.checkmark" : "sparkles")
                .font(.system(size: 42))
                .foregroundColor(Color(red: 0.75, green: 0.55, blue: 1.0))
                .padding(.bottom, 4)

            Text(headerTitle)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(headerSubtitle)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    private var navigationTitle: String {
        switch mode {
        case .login: return "登入愛蜜莉雅"
        case .register: return "新使用者註冊"
        case .profile: return "伴侶基本資料設定"
        }
    }

    private var headerTitle: String {
        switch mode {
        case .login: return "歡迎回到愛蜜莉雅身邊"
        case .register: return "開始與愛蜜莉雅的專屬契約"
        case .profile: return "伴侶個人資料與稱謂"
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .login: return "每個使用者的記憶、好感度與稱謂皆獨立保存"
        case .register: return "帳號為英文識別名，登入後可隨時自訂暱稱與愛蜜莉雅稱謂"
        case .profile: return "修改你希望愛蜜莉雅如何稱呼你，以及你對她的專屬稱號"
        }
    }

    // MARK: - Form Card
    private var formCard: some View {
        VStack(spacing: 16) {
            if mode == .login || mode == .register {
                // Username field
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("英文帳號 (Username)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        if mode == .login {
                            Button("填入預設 siewilly") {
                                username = "siewilly"
                                password = "backey513"
                            }
                            .font(.caption2)
                            .foregroundColor(Color(red: 0.8, green: 0.6, blue: 1.0))
                        }
                    }
                    TextField("僅限英文字母、數字與底線", text: $username)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }

                // Password field
                VStack(alignment: .leading, spacing: 6) {
                    Text("密碼 (Password)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    SecureField("輸入帳號密碼", text: $password)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }
            }

            if mode == .register || mode == .profile {
                // Display Name / Nickname
                VStack(alignment: .leading, spacing: 6) {
                    Text("你的暱稱 (愛蜜莉雅稱呼你)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    TextField("例如：有栖、菜月昴", text: $displayName)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }

                // Emilia Callname
                VStack(alignment: .leading, spacing: 6) {
                    Text("你稱呼愛蜜莉雅 (專屬稱謂)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    TextField("例如：愛蜜莉雅、莉雅、EMT", text: $callname)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }
            }

            if mode == .profile {
                // New Password (Optional)
                VStack(alignment: .leading, spacing: 6) {
                    Text("修改密碼 (留空則不變更)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    SecureField("新密碼 (至少 6 個字元)", text: $newPassword)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }
            }

            // Action Button
            Button(action: handleSubmit) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(submitButtonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.65, green: 0.40, blue: 0.95),
                            Color(red: 0.50, green: 0.25, blue: 0.85)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color.purple.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .disabled(isLoading)
            .padding(.top, 8)

            if mode == .profile {
                Button(action: handleLogout) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("登出此帳號")
                    }
                    .font(.subheadline)
                    .foregroundColor(.red.opacity(0.9))
                    .padding(.top, 4)
                }
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.35))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var submitButtonTitle: String {
        switch mode {
        case .login: return "登入"
        case .register: return "註冊並登入"
        case .profile: return "儲存設定"
        }
    }

    // MARK: - Switch Mode Buttons
    private var switchModeButtons: some View {
        VStack(spacing: 12) {
            if mode == .login {
                Button(action: {
                    errorMessage = nil
                    successMessage = nil
                    mode = .register
                }) {
                    Text("還沒有帳號？立即註冊")
                        .font(.footnote)
                        .foregroundColor(Color(red: 0.80, green: 0.65, blue: 1.0))
                }
            } else if mode == .register {
                Button(action: {
                    errorMessage = nil
                    successMessage = nil
                    mode = .login
                }) {
                    Text("已有帳號？返回登入")
                        .font(.footnote)
                        .foregroundColor(Color(red: 0.80, green: 0.65, blue: 1.0))
                }
            }
        }
    }

    // MARK: - Handlers
    private func initFields() {
        if let current = authService.currentUser {
            displayName = current.display_name
            callname = current.emilia_callname
        } else {
            displayName = ""
            callname = "愛蜜莉雅"
        }
    }

    private func handleSubmit() {
        errorMessage = nil
        successMessage = nil

        switch mode {
        case .login:
            let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedUser.isEmpty || password.isEmpty {
                errorMessage = "請輸入帳號與密碼"
                return
            }
            isLoading = true
            Task {
                do {
                    _ = try await authService.login(username: trimmedUser, password: password)
                    await MainActor.run {
                        isLoading = false
                        onAuthCompleted?()
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = error.localizedDescription
                    }
                }
            }

        case .register:
            let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedUser.isEmpty || password.isEmpty {
                errorMessage = "請輸入帳號與密碼"
                return
            }
            isLoading = true
            Task {
                do {
                    let dName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? trimmedUser : displayName
                    let cName = callname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "愛蜜莉雅" : callname
                    _ = try await authService.register(username: trimmedUser, password: password, displayName: dName, callname: cName)
                    await MainActor.run {
                        isLoading = false
                        onAuthCompleted?()
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = error.localizedDescription
                    }
                }
            }

        case .profile:
            isLoading = true
            Task {
                do {
                    let dName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (authService.currentUser?.username ?? "使用者") : displayName
                    let cName = callname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "愛蜜莉雅" : callname
                    _ = try await authService.updateProfile(displayName: dName, callname: cName, newPassword: newPassword.isEmpty ? nil : newPassword)
                    await MainActor.run {
                        isLoading = false
                        newPassword = ""
                        successMessage = "伴侶資料已成功儲存！"
                        onAuthCompleted?()
                    }
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    await MainActor.run {
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        let desc = error.localizedDescription
                        if desc.contains("-1011") || desc.contains("badServerResponse") {
                            errorMessage = "伺服器驗證處理中，請稍候重試或重新整理連線。"
                        } else {
                            errorMessage = desc
                        }
                    }
                }
            }
        }
    }

    private func handleLogout() {
        authService.logout()
        mode = .login
        onAuthCompleted?()
        dismiss()
    }
}
