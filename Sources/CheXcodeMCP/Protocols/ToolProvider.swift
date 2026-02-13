import Foundation
import MCP

/// Protocol for modular tool providers. Each domain Manager implements this.
protocol ToolProvider: Actor {
    /// All tools this provider exposes
    var tools: [Tool] { get }

    /// Handle a tool call by name
    func handle(_ name: String, arguments: [String: Value]) async throws -> String
}
