import Foundation

// MARK: - Response Types

struct TranscriptionResponse: Codable {
    let text: String
    let duration: Double?
    let language: String?
}

struct ProcessingResponse: Codable {
    let text: String
    let mode: String?
}

struct HealthResponse: Codable {
    let status: String
    let timestamp: String?
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case notConfigured
    case unauthorized
    case serverError(statusCode: Int, message: String?)
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse
    case fileTooLarge(maxMB: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL. Please check your settings."
        case .notConfigured:
            return "Server URL and auth token must be configured in settings."
        case .unauthorized:
            return "Authentication failed. Please check your auth token."
        case .serverError(let code, let message):
            if let message = message {
                return "Server error (\(code)): \(message)"
            }
            return "Server error (\(code))."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError:
            return "Failed to parse server response."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .fileTooLarge(let maxMB):
            return "Audio file exceeds maximum size of \(maxMB)MB."
        }
    }
}

// MARK: - API Client

@Observable
final class APIClient {
    private let settings: AppSettings
    private let session: URLSession
    private let maxFileSizeMB = 25

    init(settings: AppSettings) {
        self.settings = settings

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Transcribe

    /// Send an audio file to the server for transcription.
    func transcribe(audioURL: URL) async throws -> TranscriptionResponse {
        guard settings.isConfigured else {
            throw APIError.notConfigured
        }

        let baseURL = settings.normalizedServerURL
        guard let url = URL(string: "\(baseURL)/api/transcribe") else {
            throw APIError.invalidURL
        }

        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
        if let fileSize = attributes[.size] as? Int,
           fileSize > maxFileSizeMB * 1024 * 1024 {
            throw APIError.fileTooLarge(maxMB: maxFileSizeMB)
        }

        let audioData = try Data(contentsOf: audioURL)
        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add audio file part
        let filename = audioURL.lastPathComponent
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
        let mimeType = audioURL.pathExtension.lowercased() == "wav" ? "audio/wav" : "audio/m4a"

        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(audioData)
        body.appendString("\r\n")

        // Close boundary
        body.appendString("--\(boundary)--\r\n")

        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)
            return try decodeResponse(TranscriptionResponse.self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Process

    /// Send transcribed text to the server for AI post-processing.
    func process(text: String, mode: ProcessingMode, customPrompt: String? = nil) async throws -> ProcessingResponse {
        guard settings.isConfigured else {
            throw APIError.notConfigured
        }

        let baseURL = settings.normalizedServerURL
        guard let url = URL(string: "\(baseURL)/api/process") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "text": text,
            "mode": mode.rawValue
        ]
        if let customPrompt = customPrompt, mode == .custom {
            payload["customPrompt"] = customPrompt
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)
            return try decodeResponse(ProcessingResponse.self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Health Check

    /// Check if the server is reachable and healthy.
    func healthCheck() async throws -> HealthResponse {
        guard settings.isConfigured else {
            throw APIError.notConfigured
        }

        let baseURL = settings.normalizedServerURL
        guard let url = URL(string: "\(baseURL)/api/health") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(settings.authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)
            return try decodeResponse(HealthResponse.self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Helpers

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401, 403:
            throw APIError.unauthorized
        default:
            let message = parseErrorMessage(from: data)
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json["error"] as? String ?? json["message"] as? String
        }
        if let raw = String(data: data, encoding: .utf8) {
            return String(raw.prefix(200))
        }
        return nil
    }
}

// MARK: - Data Extension

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
