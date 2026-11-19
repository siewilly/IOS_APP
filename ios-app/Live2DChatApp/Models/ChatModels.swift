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

    private enum CodingKeys: String, CodingKey {
        case expressions
        case motions
    }

    private enum ExpressionElement: Codable {
        case string(String)
        case int(Int)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let intVal = try? container.decode(Int.self) {
                self = .int(intVal)
            } else if let strVal = try? container.decode(String.self) {
                self = .string(strVal)
            } else {
                throw DecodingError.typeMismatch(
                    String.self,
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Int for expression")
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .int(let v): try container.encode(v)
            case .string(let v): try container.encode(v)
            }
        }

        var stringValue: String {
            switch self {
            case .int(let v): return String(v)
            case .string(let v): return v
            }
        }
    }

    public init(expressions: [String]? = nil, motions: [String]? = nil) {
        self.expressions = expressions
        self.motions = motions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let rawExps = try? container.decodeIfPresent([ExpressionElement].self, forKey: .expressions) {
            self.expressions = rawExps.map { $0.stringValue }
        } else {
            self.expressions = nil
        }
        self.motions = try? container.decodeIfPresent([String].self, forKey: .motions)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(expressions, forKey: .expressions)
        try container.encodeIfPresent(motions, forKey: .motions)
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
