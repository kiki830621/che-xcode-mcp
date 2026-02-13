import Foundation
import MCP

// MARK: - ASC Attribute Models

struct PerfPowerMetricAttributes: Decodable {
    let metricType: String?
    let platform: String?
    let deviceType: String?
}

struct DiagnosticSignatureAttributes: Decodable {
    let diagnosticType: String?
    let signature: String?
    let weight: Double?
    let insight: String?
}

struct DiagnosticLogAttributes: Decodable {
    // Logs are typically raw — the URL is in relationships
}

// MARK: - Type aliases

private typealias PerfPowerMetric = ASCResource<PerfPowerMetricAttributes>
private typealias DiagnosticSignature = ASCResource<DiagnosticSignatureAttributes>
private typealias DiagnosticLog = ASCResource<DiagnosticLogAttributes>

// MARK: - PerformanceManager

actor PerformanceManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "performance_get_power_metrics",
                description: "Get power and performance metrics for an app. Returns data on disk, hang, battery, launch, memory, animation, and termination metrics.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "App Store Connect app ID (required)"
                        ]),
                        "metric_type": .object([
                            "type": "string",
                            "description": "Filter by metric type: DISK, HANG, BATTERY, LAUNCH, MEMORY, ANIMATION, TERMINATION"
                        ]),
                        "platform": .object([
                            "type": "string",
                            "description": "Platform filter (default: IOS)"
                        ])
                    ]),
                    "required": .array([.string("app_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "performance_list_diagnostic_signatures",
                description: "List diagnostic signatures (crash groups) for an app. Signatures group similar diagnostic events together.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "App Store Connect app ID (required)"
                        ]),
                        "diagnostic_type": .object([
                            "type": "string",
                            "description": "Filter by diagnostic type: DISK_WRITES, HANGS"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of signatures to return (default 20, max 200)"
                        ])
                    ]),
                    "required": .array([.string("app_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "performance_get_diagnostic_signature",
                description: "Get details of a specific diagnostic signature by ID.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "signature_id": .object([
                            "type": "string",
                            "description": "The diagnostic signature ID"
                        ])
                    ]),
                    "required": .array([.string("signature_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "performance_list_diagnostic_logs",
                description: "List diagnostic logs for a specific diagnostic signature. Returns individual diagnostic events.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "signature_id": .object([
                            "type": "string",
                            "description": "The diagnostic signature ID (required)"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of logs to return (default 20, max 200)"
                        ])
                    ]),
                    "required": .array([.string("signature_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "performance_get_power_metrics":
            return try await handleGetPowerMetrics(arguments)
        case "performance_list_diagnostic_signatures":
            return try await handleListDiagnosticSignatures(arguments)
        case "performance_get_diagnostic_signature":
            return try await handleGetDiagnosticSignature(arguments)
        case "performance_list_diagnostic_logs":
            return try await handleListDiagnosticLogs(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown Performance tool: \(name)")
        }
    }

    // MARK: - Handler: Get Power Metrics

    private func handleGetPowerMetrics(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        var queryItems: [URLQueryItem] = []

        if let metricType = stringValue(args, "metric_type") {
            queryItems.append(URLQueryItem(name: "filter[metricType]", value: metricType))
        }
        if let platform = stringValue(args, "platform") {
            queryItems.append(URLQueryItem(name: "filter[platform]", value: platform))
        }

        let path = "/v1/apps/\(appId)/perfPowerMetrics"

        // perfPowerMetrics may return a special nested format (productData).
        // Try structured decoding first; fall back to raw string if it fails.
        if let response: ASCListResponse<PerfPowerMetric> = try? await client.getList(
            path: path,
            queryItems: queryItems
        ), !response.data.isEmpty {
            var lines = ["Power & Performance Metrics for app \(appId) (\(response.data.count) entries):"]
            lines.append(String(repeating: "-", count: 60))
            for metric in response.data {
                lines.append(formatPerfPowerMetric(metric))
            }
            lines.append(String(repeating: "-", count: 60))
            lines.append("Note: Detailed metrics data (productData) is available in the raw API response.")
            return lines.joined(separator: "\n")
        }

        // Fallback: return raw response if structured parsing yielded nothing useful
        let rawResponse = try await client.getRaw(path: path, queryItems: queryItems)

        if rawResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No power or performance metrics found for app \(appId)."
        }

        var lines = ["Power & Performance Metrics (raw) for app \(appId):"]
        lines.append(String(repeating: "-", count: 60))
        lines.append(rawResponse)
        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: List Diagnostic Signatures

    private func handleListDiagnosticSignatures(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[diagnosticSignatures]", value: "diagnosticType,signature,weight,insight"),
        ]

        if let diagnosticType = stringValue(args, "diagnostic_type") {
            queryItems.append(URLQueryItem(name: "filter[diagnosticType]", value: diagnosticType))
        }
        let limit = intValue(args, "limit") ?? 20
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<DiagnosticSignature> = try await client.getList(
            path: "/v1/apps/\(appId)/diagnosticSignatures",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No diagnostic signatures found for app \(appId)."
        }

        var lines = ["Diagnostic Signatures for app \(appId) (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for signature in response.data {
            lines.append(formatDiagnosticSignature(signature))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total signatures.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Diagnostic Signature

    private func handleGetDiagnosticSignature(_ args: [String: Value]) async throws -> String {
        let signatureId = try requireString(args, "signature_id")

        let queryItems = [
            URLQueryItem(name: "fields[diagnosticSignatures]", value: "diagnosticType,signature,weight,insight")
        ]

        let response: ASCResponse<DiagnosticSignature> = try await client.get(
            path: "/v1/diagnosticSignatures/\(signatureId)",
            queryItems: queryItems
        )

        return formatDiagnosticSignatureDetailed(response.data)
    }

    // MARK: - Handler: List Diagnostic Logs

    private func handleListDiagnosticLogs(_ args: [String: Value]) async throws -> String {
        let signatureId = try requireString(args, "signature_id")

        var queryItems: [URLQueryItem] = []

        let limit = intValue(args, "limit") ?? 20
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<DiagnosticLog> = try await client.getList(
            path: "/v1/diagnosticSignatures/\(signatureId)/logs",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No diagnostic logs found for signature \(signatureId)."
        }

        var lines = ["Diagnostic Logs for signature \(signatureId) (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for log in response.data {
            lines.append(formatDiagnosticLog(log))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total logs.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Formatters

    private func formatWeight(_ weight: Double?) -> String {
        guard let weight else { return "N/A" }
        return String(format: "%.1f%%", weight * 100)
    }

    private func formatPerfPowerMetric(_ metric: PerfPowerMetric) -> String {
        let attrs = metric.attributes
        let metricType = attrs?.metricType ?? "UNKNOWN"
        let platform = attrs?.platform ?? "?"
        let deviceType = attrs?.deviceType ?? "?"
        return "  [\(metric.id)] \(metricType) | Platform: \(platform) | Device: \(deviceType)"
    }

    private func formatDiagnosticSignature(_ signature: DiagnosticSignature) -> String {
        let attrs = signature.attributes
        let diagType = attrs?.diagnosticType ?? "UNKNOWN"
        let weight = formatWeight(attrs?.weight)
        let signatureText = attrs?.signature ?? "N/A"
        var line = "  [\(signature.id)] \(diagType) | Weight: \(weight)"
        line += "\n    Signature: \(signatureText)"
        if let insight = attrs?.insight, !insight.isEmpty {
            line += "\n    Insight: \(insight)"
        }
        return line
    }

    private func formatDiagnosticSignatureDetailed(_ signature: DiagnosticSignature) -> String {
        let attrs = signature.attributes
        var lines = [
            "Diagnostic Signature Details",
            String(repeating: "-", count: 40),
            "  ID:              \(signature.id)",
            "  Diagnostic Type: \(attrs?.diagnosticType ?? "N/A")",
            "  Weight:          \(formatWeight(attrs?.weight))",
            "  Signature:       \(attrs?.signature ?? "N/A")",
        ]
        if let insight = attrs?.insight, !insight.isEmpty {
            lines.append("  Insight:         \(insight)")
        }
        return lines.joined(separator: "\n")
    }

    private func formatDiagnosticLog(_ log: DiagnosticLog) -> String {
        // Diagnostic logs have minimal top-level attributes;
        // the actual data is typically accessed via relationship links.
        var line = "  [\(log.id)]"
        if let relationships = log.relationships {
            if let logsRelated = relationships["diagnosticSignature"]?.links?.related {
                line += " | Related signature: \(logsRelated)"
            }
        }
        return line
    }
}
