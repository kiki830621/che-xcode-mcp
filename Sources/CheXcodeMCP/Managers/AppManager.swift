import Foundation
import MCP

// MARK: - ASC Attribute Models

struct AppAttributes: Decodable {
    let name: String?
    let bundleId: String?
    let sku: String?
    let primaryLocale: String?
    let contentRightsDeclaration: String?
}

struct AppInfoAttributes: Decodable {
    let appStoreState: String?
    let appStoreAgeRating: String?
    let brazilAgeRating: String?
    let kidsAgeBand: String?
}

// MARK: - Type aliases

private typealias App = ASCResource<AppAttributes>
private typealias AppInfo = ASCResource<AppInfoAttributes>

// MARK: - AppManager

actor AppManager: ToolProvider {
    private let client: ASCClient

    init(client: ASCClient) {
        self.client = client
    }

    // MARK: - ToolProvider

    var tools: [Tool] {
        [
            Tool(
                name: "app_list_apps",
                description: "List all apps in your App Store Connect account. Returns app IDs, names, bundle IDs, and SKUs. App IDs from results are used as app_id in most other tools (testflight_, metadata_, review_, analytics_, etc.). Start here if you don't know the app_id.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "limit": .object([
                            "type": "integer",
                            "description": "Maximum number of apps to return (default 20, max 200)"
                        ])
                    ])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "app_get_app",
                description: "Get detailed information about a specific app by its App Store Connect ID.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "The App Store Connect app ID"
                        ])
                    ]),
                    "required": .array([.string("app_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "app_update_app",
                description: "Update app attributes such as primaryLocale. Note: bundleId is read-only and cannot be changed.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "The App Store Connect app ID"
                        ]),
                        "primaryLocale": .object([
                            "type": "string",
                            "description": "The primary locale for the app (e.g. en-US, zh-Hant)"
                        ])
                    ]),
                    "required": .array([.string("app_id")])
                ]),
                annotations: .init(destructiveHint: false, idempotentHint: true)
            ),
            Tool(
                name: "app_list_app_infos",
                description: "List app info records (age rating, category, store state) for a specific app.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_id": .object([
                            "type": "string",
                            "description": "The App Store Connect app ID"
                        ])
                    ]),
                    "required": .array([.string("app_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "app_get_app_info",
                description: "Get detailed information about a specific app info record by its ID.",
                inputSchema: .object([
                    "type": "object",
                    "properties": .object([
                        "app_info_id": .object([
                            "type": "string",
                            "description": "The app info ID"
                        ])
                    ]),
                    "required": .array([.string("app_info_id")])
                ]),
                annotations: .init(readOnlyHint: true)
            ),
        ]
    }

    func handle(_ name: String, arguments: [String: Value]) async throws -> String {
        switch name {
        case "app_list_apps":
            return try await handleListApps(arguments)
        case "app_get_app":
            return try await handleGetApp(arguments)
        case "app_update_app":
            return try await handleUpdateApp(arguments)
        case "app_list_app_infos":
            return try await handleListAppInfos(arguments)
        case "app_get_app_info":
            return try await handleGetAppInfo(arguments)
        default:
            throw ASCClientError.invalidResponse("Unknown App tool: \(name)")
        }
    }

    // MARK: - Handler: List Apps

    private func handleListApps(_ args: [String: Value]) async throws -> String {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields[apps]", value: "name,bundleId,sku,primaryLocale,contentRightsDeclaration"),
            URLQueryItem(name: "sort", value: "name"),
        ]

        let limit = intValue(args, "limit") ?? 20
        queryItems.append(URLQueryItem(name: "limit", value: String(min(limit, 200))))

        let response: ASCListResponse<App> = try await client.getList(
            path: "/v1/apps",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No apps found."
        }

        var lines = ["Apps (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for app in response.data {
            lines.append(formatApp(app))
        }

        if let paging = response.meta?.paging, let total = paging.total {
            lines.append("\nShowing \(response.data.count) of \(total) total apps.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get App

    private func handleGetApp(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        let queryItems = [
            URLQueryItem(name: "fields[apps]", value: "name,bundleId,sku,primaryLocale,contentRightsDeclaration")
        ]

        let response: ASCResponse<App> = try await client.get(
            path: "/v1/apps/\(appId)",
            queryItems: queryItems
        )

        return formatAppDetailed(response.data)
    }

    // MARK: - Handler: Update App

    private func handleUpdateApp(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        var attributes: [String: Any] = [:]
        if let primaryLocale = stringValue(args, "primaryLocale") {
            attributes["primaryLocale"] = primaryLocale
        }

        if attributes.isEmpty {
            return "No updatable attributes provided. Updatable fields: primaryLocale.\nNote: bundleId is read-only and cannot be changed via the API."
        }

        let body: [String: Any] = [
            "data": [
                "type": "apps",
                "id": appId,
                "attributes": attributes
            ]
        ]

        let response: ASCResponse<App> = try await client.patch(
            path: "/v1/apps/\(appId)",
            body: body
        )

        let app = response.data
        var lines = ["App updated successfully."]
        lines.append(String(repeating: "-", count: 60))
        lines.append(formatAppDetailed(app))
        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: List App Infos

    private func handleListAppInfos(_ args: [String: Value]) async throws -> String {
        let appId = try requireString(args, "app_id")

        let queryItems = [
            URLQueryItem(name: "fields[appInfos]", value: "appStoreState,appStoreAgeRating,brazilAgeRating,kidsAgeBand")
        ]

        let response: ASCListResponse<AppInfo> = try await client.getList(
            path: "/v1/apps/\(appId)/appInfos",
            queryItems: queryItems
        )

        if response.data.isEmpty {
            return "No app info records found for app \(appId)."
        }

        var lines = ["App Info Records for app \(appId) (\(response.data.count)):"]
        lines.append(String(repeating: "-", count: 60))
        for info in response.data {
            lines.append(formatAppInfo(info))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Handler: Get App Info

    private func handleGetAppInfo(_ args: [String: Value]) async throws -> String {
        let appInfoId = try requireString(args, "app_info_id")

        let queryItems = [
            URLQueryItem(name: "fields[appInfos]", value: "appStoreState,appStoreAgeRating,brazilAgeRating,kidsAgeBand")
        ]

        let response: ASCResponse<AppInfo> = try await client.get(
            path: "/v1/appInfos/\(appInfoId)",
            queryItems: queryItems
        )

        return formatAppInfoDetailed(response.data)
    }

    // MARK: - Formatters

    private func formatApp(_ app: App) -> String {
        let attrs = app.attributes
        let name = attrs?.name ?? "Unnamed"
        let bundleId = attrs?.bundleId ?? "?"
        let sku = attrs?.sku ?? "?"
        return "  [\(app.id)] \(name) — \(bundleId) | SKU: \(sku)"
    }

    private func formatAppDetailed(_ app: App) -> String {
        let attrs = app.attributes
        let lines = [
            "App Details",
            String(repeating: "-", count: 40),
            "  ID:                        \(app.id)",
            "  Name:                      \(attrs?.name ?? "N/A")",
            "  Bundle ID:                 \(attrs?.bundleId ?? "N/A")",
            "  SKU:                       \(attrs?.sku ?? "N/A")",
            "  Primary Locale:            \(attrs?.primaryLocale ?? "N/A")",
            "  Content Rights Declaration: \(attrs?.contentRightsDeclaration ?? "N/A")",
        ]
        return lines.joined(separator: "\n")
    }

    private func formatAppInfo(_ info: AppInfo) -> String {
        let attrs = info.attributes
        let state = attrs?.appStoreState ?? "UNKNOWN"
        let ageRating = attrs?.appStoreAgeRating ?? "?"
        return "  [\(info.id)] State: \(state) | Age Rating: \(ageRating)"
    }

    private func formatAppInfoDetailed(_ info: AppInfo) -> String {
        let lines = [
            "App Info Details",
            String(repeating: "-", count: 40),
            "  ID:                \(info.id)",
            "  App Store State:   \(info.attributes?.appStoreState ?? "N/A")",
            "  Age Rating:        \(info.attributes?.appStoreAgeRating ?? "N/A")",
            "  Brazil Age Rating: \(info.attributes?.brazilAgeRating ?? "N/A")",
            "  Kids Age Band:     \(info.attributes?.kidsAgeBand ?? "N/A")",
        ]
        return lines.joined(separator: "\n")
    }
}
