import Foundation

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let responseFormat: ResponseFormat?
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model, messages
        case responseFormat = "response_format"
        case maxTokens = "max_tokens"
    }

    struct ResponseFormat: Codable {
        let type: String
    }
}

private struct OpenAIResponse: Codable {
    let choices: [Choice]
    struct Choice: Codable {
        let message: OpenAIMessage
    }
}

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case httpError(Int)
    case decodingFailed
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is not set. Add it in Settings."
        case .httpError(let code):
            return "OpenAI request failed with HTTP \(code). Check your API key."
        case .decodingFailed:
            return "Could not parse OpenAI response."
        case .emptyResponse:
            return "OpenAI returned an empty response."
        }
    }
}

enum AIModel: String {
    /// Fast and cheap — use for recommendations, onboarding chat, most calls.
    case mini = "gpt-4o-mini"
    /// Smarter — reserve for structured JSON extraction where accuracy matters.
    case full = "gpt-4o"
}

final class OpenAIService {
    static let shared = OpenAIService()
    private init() {}

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    }

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func chat(
        messages: [OpenAIMessage],
        model: AIModel = .mini,
        jsonMode: Bool = false,
        maxTokens: Int = 300
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body = OpenAIRequest(
            model: model.rawValue,
            messages: messages,
            responseFormat: jsonMode ? .init(type: "json_object") : nil,
            maxTokens: maxTokens
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw OpenAIError.httpError(http.statusCode)
        }

        guard let decoded = try? JSONDecoder().decode(OpenAIResponse.self, from: data) else {
            throw OpenAIError.decodingFailed
        }

        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw OpenAIError.emptyResponse
        }

        return content
    }
}
