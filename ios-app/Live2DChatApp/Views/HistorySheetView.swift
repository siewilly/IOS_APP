import SwiftUI

public struct HistorySheetView: View {
    @ObservedObject var networkService: ChatNetworkService
    var onClose: () -> Void

    @State private var searchText: String = ""

    public init(networkService: ChatNetworkService, onClose: @escaping () -> Void) {
        self.networkService = networkService
        self.onClose = onClose
    }

    private var filteredMessages: [ChatMessage] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return networkService.messages
        }
        return networkService.messages.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.08, blue: 0.18),
                    Color(red: 0.06, green: 0.04, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Text("📜")
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("歷史對話記憶錄")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("與愛蜜莉雅的美好聊天回憶")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }

                    Spacer()

                    Button(action: {
                        HapticManager.shared.light()
                        onClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.4))
                    TextField("搜尋對話記錄...", text: $searchText)
                        .foregroundColor(.white)
                        .font(.system(size: 13))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                Divider()
                    .background(Color.white.opacity(0.12))

                // Messages List
                if filteredMessages.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 36))
                            .foregroundColor(.purple.opacity(0.5))
                        Text(networkService.messages.isEmpty ? "目前尚無聊天記錄" : "找不到符合的對話")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredMessages) { msg in
                                ChatMessageBubble(message: msg)
                            }

                            if networkService.isAiThinkingOrSpeaking && networkService.messages.last?.sender == .user {
                                HStack {
                                    HStack(spacing: 6) {
                                        Circle().fill(Color.purple).frame(width: 6, height: 6)
                                        Circle().fill(Color.pink).frame(width: 6, height: 6)
                                        Circle().fill(Color.white).frame(width: 6, height: 6)
                                        Text("愛蜜莉雅正在思考回覆中...")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color(red: 0.22, green: 0.16, blue: 0.38).opacity(0.85))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.85), .large])
    }
}
