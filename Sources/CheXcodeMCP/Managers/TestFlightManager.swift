import Foundation
import MCP

/// Stub — will be fully implemented in Task 7
actor TestFlightManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    var tools: [Tool] { [] }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        throw ASCClientError.invalidResponse("Not implemented: \(name)")
    }
}
