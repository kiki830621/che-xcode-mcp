import Foundation
import MCP

/// Shared argument extraction helpers for all ToolProvider implementations.
extension ToolProvider {
    func requireString(_ args: [String: Value], _ key: String) throws -> String {
        guard let value = args[key]?.stringValue else {
            throw ASCClientError.missingParameter(key)
        }
        return value
    }

    func stringValue(_ args: [String: Value], _ key: String) -> String? {
        args[key]?.stringValue
    }

    func intValue(_ args: [String: Value], _ key: String) -> Int? {
        if let v = args[key] {
            return Int(v, strict: false)
        }
        return nil
    }

    func boolValue(_ args: [String: Value], _ key: String) -> Bool? {
        if let v = args[key] {
            return Bool(v, strict: false)
        }
        return nil
    }

    /// Shared date formatter for human-readable display
    static var displayDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    func formatDate(_ date: Date?) -> String {
        guard let date else { return "N/A" }
        return Self.displayDateFormatter.string(from: date)
    }
}
