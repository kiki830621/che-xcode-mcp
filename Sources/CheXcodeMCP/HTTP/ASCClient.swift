import Foundation

/// Generic HTTP client for App Store Connect API.
/// Handles JWT authentication, JSON:API parsing, pagination, and error handling.
actor ASCClient {
    private let jwtManager: JWTManager
    private let baseURL = "https://api.appstoreconnect.apple.com"
    private let session: URLSession
    private let decoder: JSONDecoder

    init(jwtManager: JWTManager) {
        self.jwtManager = jwtManager
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public API

    /// GET request returning a single resource
    func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> ASCResponse<T> {
        let data = try await request(method: "GET", path: path, queryItems: queryItems)
        return try decoder.decode(ASCResponse<T>.self, from: data)
    }

    /// GET request returning a list of resources
    func getList<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> ASCListResponse<T> {
        let data = try await request(method: "GET", path: path, queryItems: queryItems)
        return try decoder.decode(ASCListResponse<T>.self, from: data)
    }

    /// GET request with automatic pagination — fetches all pages
    func getAllPages<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        maxPages: Int = 10
    ) async throws -> [T] {
        var allData: [T] = []
        var nextURL: String? = nil
        var page = 0

        while page < maxPages {
            let response: ASCListResponse<T>
            if let next = nextURL {
                let data = try await requestAbsoluteURL(method: "GET", urlString: next)
                response = try decoder.decode(ASCListResponse<T>.self, from: data)
            } else {
                let data = try await request(method: "GET", path: path, queryItems: queryItems)
                response = try decoder.decode(ASCListResponse<T>.self, from: data)
            }

            allData.append(contentsOf: response.data)
            nextURL = response.links?.next
            page += 1

            if nextURL == nil { break }
        }

        return allData
    }

    /// POST request with JSON body
    func post<T: Decodable>(
        path: String,
        body: [String: Any]
    ) async throws -> ASCResponse<T> {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await request(method: "POST", path: path, body: bodyData)
        return try decoder.decode(ASCResponse<T>.self, from: data)
    }

    /// PATCH request with JSON body
    func patch<T: Decodable>(
        path: String,
        body: [String: Any]
    ) async throws -> ASCResponse<T> {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let data = try await request(method: "PATCH", path: path, body: bodyData)
        return try decoder.decode(ASCResponse<T>.self, from: data)
    }

    /// DELETE request (no response body expected)
    func delete(path: String) async throws {
        _ = try await request(method: "DELETE", path: path)
    }

    /// DELETE request with JSON body (for relationship endpoints)
    func deleteWithBody(path: String, body: [String: Any]) async throws {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await request(method: "DELETE", path: path, body: bodyData)
    }

    /// Raw GET that returns String (for reports/CSV endpoints)
    func getRaw(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> String {
        let data = try await request(method: "GET", path: path, queryItems: queryItems)
        guard let string = String(data: data, encoding: .utf8) else {
            throw ASCClientError.invalidResponse("Could not decode response as UTF-8 string")
        }
        return string
    }

    // MARK: - URL Building

    static func buildURL(path: String, queryItems: [URLQueryItem] = []) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.appstoreconnect.apple.com"
        components.path = path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url
    }

    // MARK: - Internal

    private func request(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> Data {
        guard let url = Self.buildURL(path: path, queryItems: queryItems) else {
            throw ASCClientError.invalidURL(path)
        }
        return try await executeRequest(method: method, url: url, body: body)
    }

    private func requestAbsoluteURL(
        method: String,
        urlString: String,
        body: Data? = nil
    ) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw ASCClientError.invalidURL(urlString)
        }
        return try await executeRequest(method: method, url: url, body: body)
    }

    private func executeRequest(
        method: String,
        url: URL,
        body: Data?,
        retryCount: Int = 0
    ) async throws -> Data {
        let token = try await jwtManager.getToken()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = body
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ASCClientError.invalidResponse("Not an HTTP response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 204:
            // No content (successful DELETE)
            return Data()
        case 401 where retryCount == 0:
            // Token expired, invalidate and retry once
            await jwtManager.invalidateToken()
            return try await executeRequest(method: method, url: url, body: body, retryCount: 1)
        case 429:
            // Rate limited — wait and retry
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap(Double.init) ?? 5.0
            if retryCount < 3 {
                try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                return try await executeRequest(method: method, url: url, body: body, retryCount: retryCount + 1)
            }
            throw ASCClientError.rateLimited
        default:
            // Parse ASC error response
            if let errorResponse = try? decoder.decode(ASCErrorResponse.self, from: data) {
                let messages = errorResponse.errors.map { $0.errorDescription ?? "Unknown error" }
                throw ASCClientError.apiError(httpResponse.statusCode, messages.joined(separator: "; "))
            }
            throw ASCClientError.httpError(httpResponse.statusCode)
        }
    }
}

// MARK: - Errors

enum ASCClientError: LocalizedError {
    case invalidURL(String)
    case invalidResponse(String)
    case httpError(Int)
    case apiError(Int, String)
    case rateLimited
    case missingParameter(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let path): return "Invalid URL: \(path)"
        case .invalidResponse(let msg): return "Invalid response: \(msg)"
        case .httpError(let code): return "HTTP error \(code)"
        case .apiError(let code, let msg): return "ASC API error (\(code)): \(msg)"
        case .rateLimited: return "Rate limited by ASC API. Try again later."
        case .missingParameter(let name): return "Missing required parameter: \(name)"
        }
    }
}
