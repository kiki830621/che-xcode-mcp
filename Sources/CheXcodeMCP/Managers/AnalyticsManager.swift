import Foundation
import MCP

// MARK: - ASC Attribute Models

struct AnalyticsReportRequestAttributes: Decodable {
    let accessType: String?
    let stoppedDueToInactivity: Bool?
}

struct AnalyticsReportInstanceAttributes: Decodable {
    let granularity: String?
    let processingDate: String?
}

struct AnalyticsReportSegmentAttributes: Decodable {
    let checksum: String?
    let sizeInBytes: Int?
    let url: String?
}

// MARK: - Type aliases

private typealias AnalyticsReportRequest = ASCResource<AnalyticsReportRequestAttributes>
private typealias AnalyticsReportInstance = ASCResource<AnalyticsReportInstanceAttributes>
private typealias AnalyticsReportSegment = ASCResource<AnalyticsReportSegmentAttributes>

// MARK: - AnalyticsManager

actor AnalyticsManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "analytics_request_report",
                description: "Request an analytics report for an app. Creates a new report request with the specified access type.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "App Store Connect app ID to request analytics for"
                        ]),
                        "access_type": .object([
                            "type": "string",
                            "description": "Access type: ONE_TIME_SNAPSHOT or ONGOING"
                        ])
                    ]),
                    "required": .array([.string("app_id"), .string("access_type")])
                ]),
                annotations: .init(destructiveHint: false, idempotentHint: false)
            ),
            Tool(
                name: "analytics_list_reports",
                description: "List analytics report requests for an app.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "App Store Connect app ID"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of report requests to return (default 20, max 200)"
                        ])
                    ]),
                    "required": .array([.string("app_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "analytics_get_report",
                description: "Get the status of a specific analytics report request.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "report_request_id": .object([
                            "type": "string",
                            "description": "The analytics report request ID"
                        ])
                    ]),
                    "required": .array([.string("report_request_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "analytics_list_instances",
                description: "List report instances (the actual generated reports) for a report request. Optionally filter by granularity or processing date.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "report_request_id": .object([
                            "type": "string",
                            "description": "The analytics report request ID"
                        ]),
                        "granularity": .object([
                            "type": "string",
                            "description": "Filter by granularity: DAILY, WEEKLY, or MONTHLY"
                        ]),
                        "processing_date": .object([
                            "type": "string",
                            "description": "Filter by processing date (YYYY-MM-DD)"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of instances to return (default 20, max 200)"
                        ])
                    ]),
                    "required": .array([.string("report_request_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "analytics_list_segments",
                description: "List segments for a report instance. Each segment contains a downloadable URL.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "instance_id": .object([
                            "type": "string",
                            "description": "The analytics report instance ID"
                        ]),
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of segments to return (default 50, max 200)"
                        ])
                    ]),
                    "required": .array([.string("instance_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "analytics_request_report":
            return try await handleRequestReport(arguments)
        case "analytics_list_reports":
            return try await handleListReports(arguments)
        case "analytics_get_report":
            return try await handleGetReport(arguments)
        case "analytics_list_instances":
            return try await handleListInstances(arguments)
        case "analytics_list_segments":
            return try await handleListSegments(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown analytics tool: \(name)")
        }
    }

    // MARK: - Handler: Request Report

    private func handleRequestReport(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")
        let accessType = try requireString(args, "access_type")

        let body: [String: Any] = [
            "data": [
                "type": "analyticsReportRequests",
                "attributes": [
                    "accessType": accessType
                ],
                "relationships": [
                    "app": [
                        "data": [
                            "type": "apps",
                            "id": appId
                        ]
                    ]
                ]
            ]
        ]

        let response: ASCResponse<AnalyticsReportRequest> = try await client.post(
            path: "/v1/analyticsReportRequests",
            body: body
        )

        let request = response.data
        let type = request.attributes?.accessType ?? accessType
        let stopped = request.attributes?.stoppedDueToInactivity == true ? " (stopped due to inactivity)" : ""

        return "Analytics report requested successfully.\nRequest ID: \(request.id)\nAccess Type: \(type)\(stopped)"
    }

    // MARK: - Handler: List Reports

    private func handleListReports(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[analyticsReportRequests]", value: "accessType,stoppedDueToInactivity"),
        ]

        let limit = intValue(args, "limit") ?? 20
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<AnalyticsReportRequest> = try await client.getList(
            path: "/v1/apps/\(appId)/analyticsReportRequests",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No analytics report requests found for app \(appId)."
        }

        var lines = ["Analytics Report Requests for app \(appId) (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for request in response.data {
            lines.append(formatReportRequest(request))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total report requests.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get Report

    private func handleGetReport(_ args: [String: Value]) async throws -> String {
        let requestId = try requireString(args, "report_request_id")

        let queryItems = [
            URLQueryItem(name: "fields[analyticsReportRequests]", value: "accessType,stoppedDueToInactivity")
        ]

        let response: ASCResponse<AnalyticsReportRequest> = try await client.get(
            path: "/v1/analyticsReportRequests/\(requestId)",
            queryItems: queryItems
        )

        return formatReportRequestDetailed(response.data)
    }

    // MARK: - Handler: List Instances

    private func handleListInstances(_ args: [String: Value]) async throws -> String {
        let requestId = try requireString(args, "report_request_id")

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[analyticsReportInstances]", value: "granularity,processingDate"),
        ]

        if let granularity = stringValue(args, "granularity") {
            queryItems.append(URLQueryItem(name: "filter[granularity]", value: granularity))
        }
        if let processingDate = stringValue(args, "processing_date") {
            queryItems.append(URLQueryItem(name: "filter[processingDate]", value: processingDate))
        }
        let limit = intValue(args, "limit") ?? 20
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<AnalyticsReportInstance> = try await client.getList(
            path: "/v1/analyticsReportRequests/\(requestId)/analyticsReportInstances",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No report instances found for report request \(requestId)."
        }

        var lines = ["Analytics Report Instances for request \(requestId) (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for instance in response.data {
            lines.append(formatReportInstance(instance))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total instances.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: List Segments

    private func handleListSegments(_ args: [String: Value]) async throws -> String {
        let instanceId = try requireString(args, "instance_id")

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[analyticsReportSegments]", value: "checksum,sizeInBytes,url"),
        ]

        let limit = intValue(args, "limit") ?? 50
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<AnalyticsReportSegment> = try await client.getList(
            path: "/v1/analyticsReportInstances/\(instanceId)/segments",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No segments found for report instance \(instanceId)."
        }

        var lines = ["Analytics Report Segments for instance \(instanceId) (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for segment in response.data {
            lines.append(formatReportSegment(segment))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total segments.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Formatters

    private func formatReportRequest(_ request: AnalyticsReportRequest) -> String {
        let attrs = request.attributes
        let accessType = attrs?.accessType ?? "UNKNOWN"
        let stopped = attrs?.stoppedDueToInactivity == true ? " [STOPPED]" : ""
        return "  [\(request.id)] \(accessType)\(stopped)"
    }

    private func formatReportRequestDetailed(_ request: AnalyticsReportRequest) -> String {
        let attrs = request.attributes
        let lines = [
            "Analytics Report Request Details",
            String(repeating: "-", count: 40),
            "  ID:                       \(request.id)",
            "  Access Type:              \(attrs?.accessType ?? "N/A")",
            "  Stopped Due to Inactivity: \(attrs?.stoppedDueToInactivity == true ? "Yes" : "No")",
        ]
        return lines.joined(separator: "\n")
    }

    private func formatReportInstance(_ instance: AnalyticsReportInstance) -> String {
        let attrs = instance.attributes
        let granularity = attrs?.granularity ?? "UNKNOWN"
        let processingDate = attrs?.processingDate ?? "N/A"
        return "  [\(instance.id)] \(granularity) | Processing Date: \(processingDate)"
    }

    private func formatReportSegment(_ segment: AnalyticsReportSegment) -> String {
        let attrs = segment.attributes
        let checksum = attrs?.checksum ?? "N/A"
        let size = attrs?.sizeInBytes.map { formatBytes($0) } ?? "N/A"
        var line = "  [\(segment.id)] Size: \(size) | Checksum: \(checksum)"
        if let url = attrs?.url {
            line += "\n    Download: \(url)"
        }
        return line
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1_048_576 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else if bytes < 1_073_741_824 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576.0)
        } else {
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824.0)
        }
    }
}
