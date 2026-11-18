import Foundation

public enum MessageSender: String, Codable {
    case user
    case ai
    case system
}

public struct ChatMessage: Identifiable, Equatable {
    public let id: UUID
    public let sender: MessageSender
    public var text: String
    public let timestamp: Date
    public var name: String?

    public init(id: UUID = UUID(), sender: MessageSender, text: String, timestamp: Date = Date(), name: String? = nil) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.name = name
    }
}

public struct ServerDisplayText: Codable {
    public let text: String?
    public let name: String?
    public let avatar: String?

    public init(text: String? = nil, name: String? = nil, avatar: String? = nil) {
        self.text = text
        self.name = name
        self.avatar = avatar
    }
}

public struct ServerAction: Codable {
    public let expressions: [String]?
    public let motions: [String]?

    public init(expressions: [String]? = nil, motions: [String]? = nil) {
        self.expressions = expressions
        self.motions = motions
    }
}

public struct ServerAudioPayload: Codable {
    public let type: String
    public let audio: String?
    public let volumes: [Float]?
    public let slice_length: Int?
    public let display_text: ServerDisplayText?
    public let actions: ServerAction?
    public let forwarded: Bool?
}
